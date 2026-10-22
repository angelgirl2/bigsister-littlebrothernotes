import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../cloud/chat_models.dart';
import '../cloud/cloud_service.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import '../utils/persian_date.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.theme});
  final AppThemeChoice theme;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final CloudService cloud = CloudService.instance;
  final TextEditingController composer = TextEditingController();
  final ScrollController scroll = ScrollController();
  final ImagePicker picker = ImagePicker();
  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();
  final List<ChatMessage> messages = [];
  StreamSubscription<ChatMessage>? messageSub;
  StreamSubscription<bool>? typingSub;
  StreamSubscription<Map<String, dynamic>>? presenceSub;
  StreamSubscription<Map<String, dynamic>>? statusSub;
  StreamSubscription<String>? deletedSub;
  StreamSubscription<bool>? connectionSub;
  StreamSubscription<CallSession>? callStateSub;
  final TextEditingController searchController = TextEditingController();
  Timer? searchTimer;
  Timer? outboxRetryTimer;
  bool searchMode = false;
  bool _flushingOutbox = false;
  List<ChatMessage> searchResults = <ChatMessage>[];
  List<Map<String, dynamic>> _outbox = <Map<String, dynamic>>[];

  String get _outboxPrefsKey => 'big_sister_chat_outbox_v2_${myDeviceId ?? 'local'}';
  bool callDialogOpen = false;
  Timer? typingTimer;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  ChatMessage? replyingTo;
  bool playing = false;
  bool otherOnline = false;
  bool otherTyping = false;
  String? myDeviceId;
  String? token;
  String? playingId;
  Duration audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;
  final Set<String> selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(CallService.instance.initialize());
    callStateSub = CallService.instance.states.listen((state) {
      if (state.status == 'ringing' && mounted && !callDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && !callDialogOpen) _showCallDialog(); });
      }
    });
    messageSub = cloud.incomingMessages.listen(_onIncomingMessage);
    connectionSub = cloud.connectionChanges.listen((connected) {
      if (connected) unawaited(_flushOutbox());
    });
    outboxRetryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (cloud.online) {
        unawaited(_flushOutbox());
        unawaited(_checkMissedCalls());
      }
    });
    typingSub = cloud.typingChanges.listen((v) {
      if (mounted) setState(() => otherTyping = v);
    });
    statusSub = cloud.messageStatusChanges.listen((data) {
      final id = data['id']?.toString();
      if (id == null || !mounted) return;
      final index = messages.indexWhere((m) => m.id == id);
      if (index == -1) return;
      final old = messages[index];
      final type = data['eventType']?.toString() ?? data['type']?.toString();
      setState(() {
        if (type == 'edit' || type == 'pin') {
          messages[index] = ChatMessage.fromJson(data);
        } else if (type == 'reaction') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: data['reaction']?.toString(), reactions: _parseReactionMap(data['reactions'], fallback: old.reactions), deliveredAt: old.deliveredAt, readAt: old.readAt, isPinned: old.isPinned, editedAt: old.editedAt, localStatus: old.localStatus);
        } else if (type == 'read') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: old.reaction, reactions: old.reactions, deliveredAt: old.deliveredAt, readAt: old.readAt ?? DateTime.now(), isPinned: old.isPinned, editedAt: old.editedAt, localStatus: old.localStatus);
        } else if (type == 'delivered') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: old.reaction, reactions: old.reactions, deliveredAt: old.deliveredAt ?? DateTime.now(), readAt: old.readAt, isPinned: old.isPinned, editedAt: old.editedAt, localStatus: old.localStatus);
        }
      });
    });
    deletedSub = cloud.deletedMessages.listen((id) {
      if (!mounted) return;
      setState(() {
        messages.removeWhere((m) => m.id == id);
        selectedIds.remove(id);
      });
    });
    presenceSub = cloud.presenceChanges.listen((data) {
      final id = data['deviceId']?.toString();
      if (id != null && id != myDeviceId && mounted) {
        setState(() => otherOnline = data['online'] == true);
      }
    });
    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => audioDuration = d);
    });
    player.onPositionChanged.listen((d) {
      if (mounted) setState(() => audioPosition = d);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  Future<void> _load() async {
    try {
      myDeviceId = await cloud.deviceId;
      token = await cloud.authHeaderToken();
      final loaded = await cloud.fetchMessages(limit: 100);
      await _loadOutbox();
      final ids = loaded.map((m) => m.id).toSet();
      for (final item in _outbox) {
        final id = item['id']?.toString() ?? '';
        if (id.isNotEmpty && !ids.contains(id)) loaded.add(_queuedMessage(item, 'pending'));
      }
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(loaded);
        loading = false;
      });
      await _markUnread(loaded);
      await _checkMissedCalls();
      _scrollToBottom(animated: false);
      if (cloud.online) unawaited(_flushOutbox());
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_outboxPrefsKey);
    if (raw == null || raw.isEmpty) {
      _outbox = <Map<String, dynamic>>[];
      return;
    }
    try {
      final parsed = jsonDecode(raw);
      _outbox = parsed is List
          ? parsed.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
    } catch (_) {
      _outbox = <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_outboxPrefsKey, jsonEncode(_outbox));
  }

  ChatMessage _queuedMessage(Map<String, dynamic> item, String status) {
    final created = DateTime.tryParse(item['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final kind = item['kind']?.toString() ?? 'text';
    return ChatMessage(
      id: item['id']?.toString() ?? '',
      senderId: myDeviceId ?? 'self',
      type: kind,
      body: item['body']?.toString() ?? '',
      createdAt: created,
      attachmentName: item['attachmentName']?.toString(),
      replyTo: item['replyTo']?.toString(),
      localStatus: status,
    );
  }

  Future<void> _queueTextFailure({required String id, required String body, String? replyTo, required DateTime createdAt}) async {
    _outbox.removeWhere((item) => item['id']?.toString() == id);
    _outbox.add({'id': id, 'kind': 'text', 'body': body, 'replyTo': replyTo, 'createdAt': createdAt.toIso8601String(), 'attempts': 0});
    await _saveOutbox();
    _replaceMessage(_queuedMessage(_outbox.last, 'pending'));
  }

  Future<void> _queueFileFailure({required String id, required String path, required String kind, String? replyTo, String caption = '', required DateTime createdAt}) async {
    final source = File(path);
    if (!await source.exists()) throw StateError('فایل اصلی برای ارسال مجدد پیدا نشد.');
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/BigSisterOutbox');
    await folder.create(recursive: true);
    final original = source.uri.pathSegments.last.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stored = File('${folder.path}/${id}_$original');
    if (source.path != stored.path) await source.copy(stored.path);
    _outbox.removeWhere((item) => item['id']?.toString() == id);
    final item = {'id': id, 'kind': kind, 'body': caption, 'replyTo': replyTo, 'createdAt': createdAt.toIso8601String(), 'path': stored.path, 'attachmentName': original, 'attempts': 0};
    _outbox.add(item);
    await _saveOutbox();
    _replaceMessage(_queuedMessage(item, 'pending'));
  }

  Future<void> _flushOutbox() async {
    if (_flushingOutbox || !cloud.configured || !cloud.online || _outbox.isEmpty) return;
    _flushingOutbox = true;
    try {
      while (_outbox.isNotEmpty && cloud.online && mounted) {
        final item = Map<String, dynamic>.from(_outbox.first);
        final id = item['id']?.toString() ?? '';
        final kind = item['kind']?.toString() ?? 'text';
        try {
          late final ChatMessage sent;
          if (kind == 'text') {
            sent = await cloud.sendText(item['body']?.toString() ?? '', replyTo: item['replyTo']?.toString(), id: id);
          } else {
            final path = item['path']?.toString() ?? '';
            if (path.isEmpty || !await File(path).exists()) throw StateError('فایل صف ارسال پیدا نشد.');
            sent = await cloud.sendAttachment(path: path, kind: kind, caption: item['body']?.toString() ?? '', replyTo: item['replyTo']?.toString(), id: id);
          }
          _outbox.removeWhere((q) => q['id']?.toString() == id);
          await _saveOutbox();
          final path = item['path']?.toString();
          if (path != null && path.isNotEmpty) { try { await File(path).delete(); } catch (_) {} }
          _replaceMessage(sent);
        } catch (_) {
          item['attempts'] = (int.tryParse(item['attempts']?.toString() ?? '') ?? 0) + 1;
          item['lastAttemptAt'] = DateTime.now().toIso8601String();
          _outbox[0] = item;
          await _saveOutbox();
          _replaceMessage(_queuedMessage(item, 'failed'));
          break;
        }
      }
    } finally {
      _flushingOutbox = false;
    }
  }

  Future<void> _retryQueuedMessage(String id) async {
    final index = _outbox.indexWhere((item) => item['id']?.toString() == id);
    if (index < 0) { final message = _messageById(id); if (message != null) await _resendMessage(message); return; }
    final item = _outbox.removeAt(index);
    _outbox.insert(0, item..['attempts'] = 0);
    await _saveOutbox();
    await _flushOutbox();
  }

  Future<void> _checkMissedCalls() async {
    try {
      final history = await cloud.fetchCallHistory(limit: 60);
      for (final call in history) {
        if (call['status']?.toString() == 'missed' && call['callee_device_id']?.toString() == myDeviceId) {
          await NotificationService.instance.showMissedCall(
            callId: call['call_id']?.toString() ?? '',
            video: call['call_type']?.toString() == 'video',
          );
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    searchTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => searchResults = <ChatMessage>[]);
      return;
    }
    searchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await cloud.searchMessages(query);
        if (mounted && searchController.text.trim() == query) setState(() => searchResults = results);
      } catch (_) {
        if (mounted && searchController.text.trim() == query) {
          setState(() => searchResults = messages.where((m) => m.body.toLowerCase().contains(query.toLowerCase()) || (m.attachmentName ?? '').toLowerCase().contains(query.toLowerCase())).toList());
        }
      }
    });
  }

  Future<void> _showCallHistory() async {
    try {
      final calls = await cloud.fetchCallHistory();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تاریخچه تماس‌ها'),
            content: SizedBox(
              width: 420,
              height: 380,
              child: calls.isEmpty
                  ? const Center(child: Text('هنوز تماسی ثبت نشده است.'))
                  : ListView.separated(
                      itemCount: calls.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final call = calls[index];
                        final at = DateTime.tryParse(call['created_at']?.toString() ?? '')?.toLocal();
                        final outgoing = call['caller_device_id']?.toString() == myDeviceId;
                        final video = call['call_type']?.toString() == 'video';
                        final status = call['status']?.toString() ?? '';
                        final subtitle = switch (status) {
                          'missed' => 'پاسخ داده نشد',
                          'declined' => 'رد شده',
                          'cancelled' => 'لغو شده',
                          'failed' => 'ناموفق',
                          'busy' => 'مشغول',
                          'ended' => 'پایان‌یافته · ${PersianDate.digits((call['duration_seconds'] ?? 0).toString())} ثانیه',
                          'answered' => 'پاسخ داده شد',
                          'ringing' => 'در انتظار پاسخ',
                          _ => status,
                        };
                        return ListTile(
                          leading: Icon(status == 'missed' && !outgoing ? Icons.call_missed_rounded : (video ? Icons.video_call_rounded : (outgoing ? Icons.call_made_rounded : Icons.call_received_rounded)), color: status == 'missed' ? Colors.redAccent : null),
                          title: Text('${outgoing ? 'تماس خروجی' : 'تماس از ${cloud.otherDisplayName}'} · ${video ? 'تصویری' : 'صوتی'}'),
                          subtitle: Text('${at == null ? '' : '${PersianDate.date(at)} · ${PersianDate.time(at)}'}\n$subtitle'),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن'))],
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاریخچه تماس دریافت نشد؛ اتصال سرور را بررسی کن.')));
    }
  }

  Future<void> _markUnread(List<ChatMessage> list) async {
    for (final m in list) {
      if (m.senderId != myDeviceId && !m.isRead) {
        await cloud.markRead(m.id);
      }
    }
  }

  void _onIncomingMessage(ChatMessage message) {
    if (!mounted) return;
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      setState(() => messages[index] = message);
    } else {
      setState(() => messages.add(message));
    }
    if (message.senderId != myDeviceId) {
      cloud.markRead(message.id);
    }
    _scrollToBottom();
  }

  void _replaceMessage(ChatMessage message) {
    if (!mounted) return;
    final index = messages.indexWhere((m) => m.id == message.id);
    setState(() {
      if (index >= 0) {
        messages[index] = message;
      } else {
        messages.add(message);
      }
    });
  }

  String _newLocalUuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final pad = '${now}00000000000000000000000000000000';
    return '${pad.substring(0, 8)}-${pad.substring(8, 12)}-4${pad.substring(13, 16)}-a${pad.substring(17, 20)}-${pad.substring(20, 32)}';
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final target = scroll.position.maxScrollExtent + 140;
      if (animated) {
        scroll.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
      } else {
        scroll.jumpTo(target);
      }
    });
  }

  void _onTextChanged(String value) {
    cloud.setTyping(value.trim().isNotEmpty);
    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 900), () => cloud.setTyping(false));
  }

  bool get selecting => selectedIds.isNotEmpty;

  void _toggleSelection(ChatMessage message) {
    setState(() {
      if (selectedIds.contains(message.id)) {
        selectedIds.remove(message.id);
      } else {
        selectedIds.add(message.id);
      }
    });
  }

  void _clearSelection() {
    if (selectedIds.isEmpty) return;
    setState(() => selectedIds.clear());
  }

  Future<void> _deleteSelected() async {
    if (selectedIds.isEmpty || sending) return;

    final ids = selectedIds.toList(growable: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف پیام‌ها'),
        content: Text('تعداد ${ids.length} پیام انتخاب شده حذف شود؟ این حذف برای هر دو نفر اعمال می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => sending = true);
    final deleted = <String>[];
    final failed = <String>[];

    for (final id in ids) {
      try {
        await cloud.deleteMessage(id);
        deleted.add(id);
      } catch (_) {
        failed.add(id);
      }
    }

    if (!mounted) return;
    setState(() {
      messages.removeWhere((m) => deleted.contains(m.id));
      selectedIds.removeAll(deleted);
      sending = false;
    });

    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${failed.length} پیام حذف نشد.')),
      );
    }
  }

  Future<void> sendText() async {
    final text = composer.text.trim();
    if (text.isEmpty || !cloud.configured) return;
    final replyId = replyingTo?.id;
    composer.clear();
    setState(() => replyingTo = null);
    cloud.setTyping(false);
    await _sendTextBody(text, replyId: replyId);
  }

  Future<void> _sendTextBody(String text, {String? replyId}) async {
    if (text.trim().isEmpty || !cloud.configured) return;
    final id = _newLocalUuid();
    final createdAt = DateTime.now();
    final optimistic = ChatMessage(
      id: id,
      senderId: myDeviceId ?? 'self',
      type: 'text',
      body: text,
      createdAt: createdAt,
      replyTo: replyId,
      localStatus: 'pending',
    );
    setState(() => messages.add(optimistic));
    _scrollToBottom();
    try {
      final msg = await cloud.sendText(text, replyTo: replyId, id: id);
      _replaceMessage(msg);
      _scrollToBottom();
    } catch (_) {
      await _queueTextFailure(id: id, body: text, replyTo: replyId, createdAt: createdAt);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('این پیام در صف ذخیره شد و پس از اتصال دوباره ارسال می‌شود.')));
    }
  }

  Future<void> sendAnyFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return;
    await _sendFile(path, 'file');
  }

  Future<void> sendImage() async {
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x == null) return;
    await _sendFile(x.path, 'image');
  }

  Future<void> sendVideo() async {
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    await _sendFile(x.path, 'video');
  }

  Future<void> recordVideoNote() async {
    if (!cloud.configured || sending) return;
    try {
      final x = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
        preferredCameraDevice: CameraDevice.front,
      );
      if (x == null) return;
      await _sendFile(x.path, 'video_note', deleteLocalAfterSend: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ضبط ویدیوپیام ممکن نشد. مجوز دوربین و فضای خالی گوشی را بررسی کن.')),
      );
    }
  }

  Future<void> toggleRecord() async {
    if (recording) {
      final path = await recorder.stop();
      if (mounted) setState(() => recording = false);
      if (path != null) await _sendFile(path, 'audio', deleteLocalAfterSend: true);
      return;
    }
    if (!await recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مجوز میکروفون لازم است.')));
      return;
    }
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}/chat_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(), path: path);
    if (mounted) setState(() => recording = true);
  }

  Future<void> _sendFile(String path, String kind, {bool deleteLocalAfterSend = false, String caption = ''}) async {
    if (!cloud.configured) return;
    final id = _newLocalUuid();
    final replyId = replyingTo?.id;
    final optimistic = ChatMessage(
      id: id,
      senderId: myDeviceId ?? 'self',
      type: kind,
      body: caption,
      createdAt: DateTime.now(),
      replyTo: replyId,
      localStatus: 'pending',
    );
    final createdAt = optimistic.createdAt;
    setState(() {
      messages.add(optimistic);
      replyingTo = null;
    });
    _scrollToBottom();
    try {
      final msg = await cloud.sendAttachment(path: path, kind: kind, caption: caption, replyTo: replyId, id: id);
      _replaceMessage(msg);
      _scrollToBottom();
    } catch (_) {
      try {
        await _queueFileFailure(id: id, path: path, kind: kind, replyTo: replyId, caption: caption, createdAt: createdAt);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل در صف ذخیره شد و پس از اتصال دوباره ارسال می‌شود.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسال ناموفق بود و ذخیرهٔ فایل برای تلاش مجدد هم ممکن نشد.')));
      }
    } finally {
      // Recorded temp files may be removed once a persistent outbox copy exists.
      if (deleteLocalAfterSend) {
        final queued = _outbox.any((item) => item['id']?.toString() == id);
        if (!queued) {
          try { final f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}
        } else {
          try { final f = File(path); if (f.existsSync() && !f.path.contains('/BigSisterOutbox/')) await f.delete(); } catch (_) {}
        }
      }
    }
  }

  Future<void> _resendMessage(ChatMessage message) async {
    if (_outbox.any((item) => item['id']?.toString() == message.id)) {
      await _retryQueuedMessage(message.id);
      return;
    }
    if (message.hasAttachment) {
      try {
        final bytes = await cloud.downloadMediaBytes(message.attachmentId!);
        final dir = await getTemporaryDirectory();
        final raw = (message.attachmentName?.trim().isNotEmpty == true ? message.attachmentName!.trim() : 'resend_${message.id}.bin').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${dir.path}/resend_${DateTime.now().microsecondsSinceEpoch}_$raw');
        await file.writeAsBytes(bytes, flush: true);
        await _sendFile(file.path, message.type, deleteLocalAfterSend: true, caption: message.body);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دانلود فایل برای ارسال مجدد ناموفق بود.')));
      }
      return;
    }
    if (message.body.trim().isNotEmpty) await _sendTextBody(message.body, replyId: message.replyTo);
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.body);
    final changed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ویرایش پیام'),
          content: TextField(controller: controller, autofocus: true, minLines: 1, maxLines: 6, maxLength: 20000),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (changed == null || changed.isEmpty) return;
    try {
      _replaceMessage(await cloud.editMessage(message.id, changed));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ویرایش ممکن نشد؛ فقط پیام‌های خودت تا ۱۵ دقیقه قابل ویرایش‌اند.')));
    }
  }

  Future<void> _toggleHeartReaction(ChatMessage message) async {
    try {
      final response = await cloud.react(message.id, _myReaction(message) == '❤️' ? '' : '❤️');
      final old = _messageById(message.id) ?? message;
      _replaceMessage(ChatMessage(
        id: old.id, senderId: old.senderId, type: old.type, body: old.body,
        createdAt: old.createdAt, attachmentId: old.attachmentId,
        attachmentName: old.attachmentName, replyTo: old.replyTo,
        reaction: response['reaction']?.toString(),
        reactions: _parseReactionMap(response['reactions'], fallback: old.reactions),
        deliveredAt: old.deliveredAt, readAt: old.readAt, isPinned: old.isPinned,
        editedAt: old.editedAt, localStatus: old.localStatus,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت واکنش ممکن نشد.')));
    }
  }

  Future<void> _chooseReaction(ChatMessage message) async {
    const emojis = <String>['❤️', '😂', '😍', '👍', '👎', '😢', '😮', '🙏', '🔥', '🎉', '🥰', '💯', '😡', '🤗', '👏', '✅'];
    final reaction = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: emojis.map((emoji) => InkWell(
              onTap: () => Navigator.pop(sheetContext, emoji),
              borderRadius: BorderRadius.circular(18),
              child: Padding(padding: const EdgeInsets.all(7), child: Text(emoji, style: const TextStyle(fontSize: 30))),
            )).toList(),
          ),
        ),
      ),
    );
    if (reaction == null) return;
    try {
      final response = await cloud.react(message.id, _myReaction(message) == reaction ? '' : reaction);
      final old = _messageById(message.id) ?? message;
      _replaceMessage(ChatMessage(
        id: old.id, senderId: old.senderId, type: old.type, body: old.body,
        createdAt: old.createdAt, attachmentId: old.attachmentId,
        attachmentName: old.attachmentName, replyTo: old.replyTo,
        reaction: response['reaction']?.toString(),
        reactions: _parseReactionMap(response['reactions'], fallback: old.reactions),
        deliveredAt: old.deliveredAt, readAt: old.readAt, isPinned: old.isPinned,
        editedAt: old.editedAt, localStatus: old.localStatus,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت واکنش ممکن نشد.')));
    }
  }

  Future<void> _togglePinned(ChatMessage message) async {
    try {
      _replaceMessage(await cloud.pinMessage(message.id, !message.isPinned));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.isPinned ? 'سنجاق پیام برداشته شد.' : 'پیام برای هر دو نفر سنجاق شد.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سنجاق‌کردن پیام ناموفق بود.')));
    }
  }

  Future<void> playRemoteAudio(ChatMessage message) async {
    if (!message.hasAttachment || token == null) return;
    if (playingId == message.id && playing) {
      await player.pause();
      if (mounted) setState(() => playing = false);
      return;
    }
    try {
      final bytes = await cloud.downloadMediaBytes(message.attachmentId!);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chat_${message.id}.m4a');
      await file.writeAsBytes(bytes, flush: true);
      await player.play(DeviceFileSource(file.path));
      if (mounted) setState(() {
        playing = true;
        playingId = message.id;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پخش صدای پیام ممکن نیست.')));
    }
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    searchTimer?.cancel();
    outboxRetryTimer?.cancel();
    connectionSub?.cancel();
    searchController.dispose();
    messageSub?.cancel();
    typingSub?.cancel();
    presenceSub?.cancel();
    statusSub?.cancel();
    deletedSub?.cancel();
    callStateSub?.cancel();
    if (CallService.instance.current.status == 'ringing' || CallService.instance.current.status == 'connecting' || CallService.instance.current.status == 'active') { unawaited(CallService.instance.endCall()); }
    composer.dispose();
    scroll.dispose();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    if (!cloud.configured) {
      return ColoredBox(
        color: AppPalette.page,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_rounded, color: c.primary, size: 64),
                const SizedBox(height: 16),
                const Text('چت دوطرفه هنوز متصل نشده است', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('از تنظیمات، یک‌بار وارد دفتر مشترک شو؛ بعد از آن چت خودکار همگام می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.page,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: selecting
              ? IconButton(
                  tooltip: 'لغو انتخاب',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          title: searchMode
              ? TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'جست‌وجوی پیام و فایل…', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white60)),
                )
              : selecting
                  ? Text('${selectedIds.length} پیام انتخاب شده', style: const TextStyle(fontWeight: FontWeight.w900))
                  : Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary.withValues(alpha: .12)),
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cloud.otherDisplayName, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(
                          otherTyping ? 'در حال نوشتن…' : (otherOnline ? 'آنلاین' : 'آفلاین'),
                          style: TextStyle(fontSize: 11, color: otherTyping || otherOnline ? c.primary : Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
          actions: [
            if (!selecting && !searchMode)
              IconButton(tooltip: 'جست‌وجوی پیام و فایل', onPressed: () => setState(() => searchMode = true), icon: const Icon(Icons.search_rounded)),
            if (searchMode)
              IconButton(tooltip: 'بستن جست‌وجو', onPressed: () { searchTimer?.cancel(); searchController.clear(); setState(() { searchMode = false; searchResults.clear(); }); }, icon: const Icon(Icons.close_rounded)),
            if (!selecting && !searchMode)
              IconButton(tooltip: 'تاریخچه تماس‌ها', onPressed: _showCallHistory, icon: const Icon(Icons.history_rounded)),
            if (!selecting && !searchMode)
              IconButton(tooltip: 'تماس صوتی', onPressed: () => _startCall(video: false), icon: const Icon(Icons.call_rounded)),
            if (!selecting && !searchMode)
              IconButton(tooltip: 'تماس تصویری', onPressed: () => _startCall(video: true), icon: const Icon(Icons.videocam_rounded)),
            if (selecting)
              IconButton(
                tooltip: 'حذف پیام‌های انتخاب‌شده',
                onPressed: sending ? null : _deleteSelected,
                icon: const Icon(Icons.delete_forever_rounded),
              ),
          ],
        ),
        body: Column(
          children: [
            if (!searchMode && messages.any((m) => m.isPinned))
              Builder(builder: (context) {
                final pinned = messages.lastWhere((m) => m.isPinned);
                final title = pinned.body.trim().isNotEmpty ? pinned.body.trim() : (pinned.attachmentName ?? 'پیام مهم سنجاق‌شده');
                return InkWell(
                  onTap: () { setState(() { searchMode = true; searchController.text = title; }); _onSearchChanged(title); },
                  child: Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 4, 12, 2), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: c.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withValues(alpha: .25))), child: Row(children: [Icon(Icons.push_pin_rounded, color: c.primary, size: 18), const SizedBox(width: 8), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_left_rounded)])),
                );
              }),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                      final visibleMessages = searchMode && searchController.text.trim().isNotEmpty ? searchResults : messages;
                      if (searchMode && searchController.text.trim().isNotEmpty && visibleMessages.isEmpty) return const Center(child: Text('پیامی یا فایلی پیدا نشد.'));
                      return ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                        itemCount: visibleMessages.length,
                        itemBuilder: (_, i) {
                          final message = visibleMessages[i];
                          final showDay = !searchMode && (i == 0 || !_sameDay(message.createdAt, visibleMessages[i - 1].createdAt));
                          return Column(children: [if (showDay) _daySeparator(message.createdAt, c.primary), _bubble(message, c)]);
                        },
                      );
                    }),
            ),
            _composer(c),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final aa = a.toLocal();
    final bb = b.toLocal();
    return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
  }

  Widget _daySeparator(DateTime date, Color accent) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? 'امروز'
        : _sameDay(date, now.subtract(const Duration(days: 1)))
            ? 'دیروز'
            : PersianDate.date(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: accent.withValues(alpha: .12)),
        ),
        child: Text(label, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _bubble(ChatMessage message, ThemeColors c) {
    final mine = message.senderId == myDeviceId;
    final bg = mine ? c.primary.withValues(alpha: .18) : const Color(0xFF0A111C);
    final border = mine ? c.primary.withValues(alpha: .22) : Colors.white.withValues(alpha: .05);
    final selected = selectedIds.contains(message.id);
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message),
        onTap: selecting ? () => _toggleSelection(message) : null,
        onDoubleTap: selecting ? null : () => _toggleHeartReaction(message),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: c.primary.withValues(alpha: .7), width: 2),
                )
              : null,
          padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
          child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(mine ? 22 : 7),
              bottomRight: Radius.circular(mine ? 7 : 22),
            ),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.type == 'image' && message.attachmentId != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    cloud.mediaUrl(message.attachmentId!),
                    headers: token == null ? null : {'Authorization': 'Bearer $token'},
                    height: 220,
                    width: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              if ((message.type == 'video' || message.type == 'video_note') && message.attachmentId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _RemoteVideoBubble(
                    key: ValueKey('video-${message.id}'),
                    url: cloud.mediaUrl(message.attachmentId!),
                    headers: token == null ? const {} : {'Authorization': 'Bearer $token'},
                    circular: message.type == 'video_note',
                  ),
                ),
              if ((message.type == 'image' || message.type == 'video' || message.type == 'video_note' || message.type == 'audio' || message.type == 'file') && !message.hasAttachment)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(message.type == 'video_note' ? 'در حال ارسال ویدیوپیام…' : message.type == 'video' ? 'در حال ارسال ویدیو…' : message.type == 'image' ? 'در حال ارسال عکس…' : message.type == 'audio' ? 'در حال ارسال صدا…' : 'در حال ارسال فایل…'),
                  ],
                ),
              if (message.type == 'file' && message.attachmentId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file_rounded, color: c.primary, size: 30),
                    const SizedBox(width: 8),
                    Flexible(child: Text(message.attachmentName ?? 'فایل پیوست شده')),
                    IconButton(
                      tooltip: 'ذخیره فایل',
                      onPressed: () => saveRemoteFile(message),
                      icon: Icon(Icons.download_rounded, color: c.primary),
                    ),
                  ],
                ),
              if (message.type == 'audio')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => playRemoteAudio(message),
                      icon: Icon(
                        playingId == message.id && playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: c.primary,
                        size: 38,
                      ),
                    ),
                    const Text('پیام صوتی'),
                  ],
                ),
              if (message.replyTo != null)
                _replyPreviewForMessage(message.replyTo!, c),
              if (message.body.isNotEmpty) ...[
                if (message.type != 'text') const SizedBox(height: 5),
                Text(
                  message.body,
                  style: const TextStyle(fontSize: 16.5, height: 1.55),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isPinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin_rounded, size: 12, color: Colors.amberAccent)),
                  Text(
                    _time(message.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.isRead
                          ? Icons.done_all_rounded
                          : message.isDelivered
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                      size: 14,
                      color: message.isRead ? c.primary : Colors.white54,
                    ),
                  ],
                  if (message.editedAt != null) ...[
                    const SizedBox(width: 5),
                    const Text('ویرایش‌شده', style: TextStyle(fontSize: 9, color: Colors.white54)),
                  ],
                  if (message.localStatus != null) ...[
                    const SizedBox(width: 5),
                    Text(message.localStatus == 'failed' ? 'ارسال ناموفق' : 'در صف ارسال', style: const TextStyle(fontSize: 9, color: Colors.orangeAccent)),
                    IconButton(tooltip: 'تلاش مجدد ارسال', visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24), onPressed: () => _retryQueuedMessage(message.id), icon: const Icon(Icons.sync_rounded, size: 15, color: Colors.orangeAccent)),
                  ],
                ],
              ),
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 4, runSpacing: 4, children: _reactionSummary(message)),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Map<String, String> _parseReactionMap(Object? raw, {Map<String, String> fallback = const <String, String>{}}) {
    if (raw is! Map) return fallback;
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final emoji = entry.value?.toString() ?? '';
      if (emoji.isNotEmpty) result[entry.key.toString()] = emoji;
    }
    return result;
  }

  String? _myReaction(ChatMessage message) {
    final id = myDeviceId;
    if (id != null && message.reactions.containsKey(id)) return message.reactions[id];
    return null;
  }

  List<Widget> _reactionSummary(ChatMessage message) {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries.map((entry) {
      final selected = _myReaction(message) == entry.key;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: .18) : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: .55) : Colors.white.withValues(alpha: .08)),
        ),
        child: Text('${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}', style: const TextStyle(fontSize: 12)),
      );
    }).toList();
  }

  ChatMessage? _messageById(String id) {
    for (final message in messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  Widget _replyPreviewForMessage(String id, ThemeColors c) {
    final target = _messageById(id);
    final text = target == null
        ? 'پیام حذف شده'
        : target.body.trim().isEmpty
            ? (target.type == 'audio' ? 'پیام صوتی' : target.type == 'video' ? 'ویدیو' : target.type == 'image' ? 'عکس' : 'فایل')
            : target.body.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: .07),
        border: Border(right: BorderSide(color: c.primary, width: 3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.length > 100 ? '${text.substring(0, 100)}…' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _replyComposerBar(ThemeColors c) {
    final target = replyingTo;
    if (target == null) return const SizedBox.shrink();
    final text = target.body.trim().isEmpty
        ? (target.type == 'audio' ? 'پیام صوتی' : target.type == 'video' ? 'ویدیو' : target.type == 'image' ? 'عکس' : 'فایل')
        : target.body.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.primary.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: c.primary, size: 20),
          const SizedBox(width: 7),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: 'لغو پاسخ',
            onPressed: () => setState(() => replyingTo = null),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final mine = message.senderId == myDeviceId;
    final editable = mine && DateTime.now().difference(message.createdAt).inMinutes < 15 && message.body.trim().isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('پاسخ به پیام'), onTap: () => Navigator.pop(sheetContext, 'reply')),
          ListTile(leading: const Icon(Icons.emoji_emotions_outlined), title: const Text('واکنش ایموجی'), onTap: () => Navigator.pop(sheetContext, 'react')),
          ListTile(leading: Icon(message.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded), title: Text(message.isPinned ? 'برداشتن سنجاق' : 'سنجاق برای هر دو نفر'), onTap: () => Navigator.pop(sheetContext, 'pin')),
          if (editable) ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('ویرایش پیام'), onTap: () => Navigator.pop(sheetContext, 'edit')),
          ListTile(leading: const Icon(Icons.forward_rounded), title: const Text('ارسال مجدد پیام یا فایل'), onTap: () => Navigator.pop(sheetContext, 'resend')),
          ListTile(leading: const Icon(Icons.checklist_rounded), title: const Text('انتخاب پیام'), onTap: () => Navigator.pop(sheetContext, 'select')),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'reply') {
      setState(() => replyingTo = message);
      WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).unfocus());
    } else if (choice == 'select') {
      _toggleSelection(message);
    } else if (choice == 'react') {
      await _chooseReaction(message);
    } else if (choice == 'pin') {
      await _togglePinned(message);
    } else if (choice == 'edit') {
      await _editMessage(message);
    } else if (choice == 'resend') {
      await _resendMessage(message);
    }
  }

  Future<void> saveRemoteFile(ChatMessage message) async {
    if (message.attachmentId == null) return;
    try {
      final bytes = await cloud.downloadMediaBytes(message.attachmentId!);
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/BigSisterReceivedFiles');
      if (!await folder.exists()) await folder.create(recursive: true);
      final rawName = message.attachmentName?.trim();
      final fallback = 'received_${DateTime.now().millisecondsSinceEpoch}.bin';
      final cleanName = (rawName == null || rawName.isEmpty)
          ? fallback
          : rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(
        '${folder.path}/${DateTime.now().millisecondsSinceEpoch}_$cleanName',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فایل در ${file.path} ذخیره شد.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دریافت فایل انجام نشد.')),
        );
      }
    }
  }

  Future<void> _startCall({required bool video}) async {
    try {
      await CallService.instance.startOutgoing(video: video);
      if (mounted) _showCallDialog();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('شروع تماس ممکن نشد: $e')));
    }
  }

  Future<void> _showCallDialog() async {
    if (callDialogOpen || !mounted) return;
    callDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ChatCallDialog(),
    );
    callDialogOpen = false;
  }

  String _time(DateTime time) => PersianDate.time(time);

  Widget _composer(ThemeColors c) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null) _replyComposerBar(c),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'پیوست',
                  onPressed: _showAttachmentSheet,
                  icon: Icon(Icons.attach_file_rounded, color: c.secondary, size: 27),
                ),
                Expanded(
                  child: TextField(
                    controller: composer,
                    onChanged: _onTextChanged,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'برای نفر مقابلت بنویس…',
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: recording ? 'پایان ضبط' : 'پیام صوتی',
                  onPressed: toggleRecord,
                  icon: Icon(
                    recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    color: recording ? Colors.redAccent : c.primary,
                    size: 30,
                  ),
                ),
                IconButton(
                  tooltip: 'ویدیوپیام دایره‌ای',
                  onPressed: recordVideoNote,
                  icon: const Icon(Icons.video_camera_front_rounded, color: Colors.pinkAccent, size: 27),
                ),
                IconButton(
                  tooltip: 'فرستادن پیام',
                  onPressed: sendText,
                  icon: Icon(
                    Icons.send_rounded,
                    color: c.primary,
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
    if (sending) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('انتخاب عکس از گالری'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.video_camera_front_rounded, color: Colors.pinkAccent),
              title: const Text('ضبط ویدیوپیام دایره‌ای'),
              subtitle: const Text('با دوربین گوشی، حداکثر ۶۰ ثانیه'),
              onTap: () => Navigator.pop(sheetContext, 'video_note'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded),
              title: const Text('انتخاب ویدیو از گالری'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('انتخاب فایل'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'gallery') {
      await sendImage();
    } else if (choice == 'video') {
      await sendVideo();
    } else if (choice == 'video_note') {
      await recordVideoNote();
    } else if (choice == 'file') {
      await sendAnyFile();
    }
  }
}


class _RemoteVideoBubble extends StatefulWidget {
  const _RemoteVideoBubble({super.key, required this.url, required this.headers, this.circular = false});
  final String url;
  final Map<String, String> headers;
  final bool circular;

  @override
  State<_RemoteVideoBubble> createState() => _RemoteVideoBubbleState();
}

class _RemoteVideoBubbleState extends State<_RemoteVideoBubble> {
  late final VideoPlayerController controller;
  bool ready = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    );
    controller.initialize().then((_) {
      if (widget.circular) unawaited(controller.setLooping(true));
      if (mounted) setState(() => ready = true);
    }).catchError((_) {
      if (mounted) setState(() => failed = true);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Container(
        width: widget.circular ? 216 : 300,
        height: widget.circular ? 216 : 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .2),
          shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circular ? null : BorderRadius.circular(15),
        ),
        child: const Icon(Icons.broken_image_rounded, size: 40),
      );
    }
    if (!ready) {
      return Container(
        width: widget.circular ? 216 : 300,
        height: widget.circular ? 216 : 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .2),
          shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circular ? null : BorderRadius.circular(15),
        ),
        child: const CircularProgressIndicator(),
      );
    }
    final video = widget.circular
        ? ClipOval(
            child: SizedBox(
              width: 216,
              height: 216,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          );
    return GestureDetector(
      onTap: () async {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          if (controller.value.position >= controller.value.duration) {
            await controller.seekTo(Duration.zero);
          }
          await controller.play();
        }
        if (mounted) setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          video,
          if (!controller.value.isPlaying)
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
              padding: const EdgeInsets.all(12),
              child: Icon(widget.circular ? Icons.play_arrow_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
            ),
          if (widget.circular)
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Text('ویدیوپیام', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}


class _ChatCallDialog extends StatefulWidget {
  const _ChatCallDialog();

  @override
  State<_ChatCallDialog> createState() => _ChatCallDialogState();
}

class _ChatCallDialogState extends State<_ChatCallDialog> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _duration(Duration d) => PersianDate.digits('${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final service = CallService.instance;
    return StreamBuilder<CallSession>(
      stream: service.states,
      initialData: service.current,
      builder: (context, snapshot) {
        final state = snapshot.data ?? service.current;
        final incoming = state.status == 'ringing' && !state.outgoing;
        final video = state.video;
        final ongoing = state.status == 'active' || state.status == 'connecting';
        final title = incoming
            ? (video ? 'تماس تصویری ورودی' : 'تماس صوتی ورودی')
            : state.status == 'active'
                ? 'تماس برقرار است'
                : state.status == 'ended'
                    ? 'تماس پایان یافت'
                    : (video ? 'در حال برقراری تماس تصویری…' : 'در حال برقراری تماس صوتی…');
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (video && !incoming && service.remoteRenderer.srcObject != null)
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 250, child: RTCVideoView(service.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)))
                  else
                    const CircleAvatar(radius: 42, child: Icon(Icons.person_rounded, size: 46)),
                  const SizedBox(height: 14),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  if (state.status == 'active') Padding(padding: const EdgeInsets.only(top: 6), child: Text(_duration(service.activeDuration), style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (state.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(state.error!, textAlign: TextAlign.center)),
                  if (video && service.localRenderer.srcObject != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(height: 78, child: RTCVideoView(service.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                  ],
                  const SizedBox(height: 18),
                  if (ongoing && !incoming)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        IconButton.filledTonal(tooltip: state.muted ? 'روشن‌کردن میکروفون' : 'بی‌صداکردن میکروفون', onPressed: () => service.toggleMicrophone(), icon: Icon(state.muted ? Icons.mic_off_rounded : Icons.mic_rounded)),
                        if (video) IconButton.filledTonal(tooltip: state.cameraEnabled ? 'خاموش‌کردن دوربین' : 'روشن‌کردن دوربین', onPressed: () => service.toggleCamera(), icon: Icon(state.cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded)),
                        if (video) IconButton.filledTonal(tooltip: 'تعویض دوربین', onPressed: () => service.switchCamera(), icon: const Icon(Icons.cameraswitch_rounded)),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await service.toggleSpeaker();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تغییر خروجی صدا ممکن نشد؛ مجوز و وضعیت تماس را بررسی کن.')),
                                );
                              }
                            }
                          },
                          icon: Icon(state.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded),
                          label: Text(state.speakerOn ? 'اسپیکر روشن' : 'اسپیکر خاموش'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      if (incoming)
                        FilledButton.icon(onPressed: () async { try { await service.acceptIncoming(); } catch (_) { await service.endCall(decline: true); } }, icon: const Icon(Icons.call_rounded), label: const Text('پاسخ')),
                      if (state.status != 'ended')
                        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () async { await service.endCall(decline: incoming); if (context.mounted) Navigator.of(context).pop(); }, icon: const Icon(Icons.call_end_rounded), label: Text(incoming ? 'رد تماس' : 'پایان تماس'))
                      else
                        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بستن')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
