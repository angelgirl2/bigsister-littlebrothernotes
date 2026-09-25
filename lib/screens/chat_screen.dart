import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../cloud/chat_models.dart';
import '../cloud/cloud_service.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
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
    messageSub = cloud.incomingMessages.listen(_onIncomingMessage);
    typingSub = cloud.typingChanges.listen((v) {
      if (mounted) setState(() => otherTyping = v);
    });
    statusSub = cloud.messageStatusChanges.listen((data) {
      final id = data['id']?.toString();
      if (id == null || !mounted) return;
      final index = messages.indexWhere((m) => m.id == id);
      if (index == -1) return;
      final old = messages[index];
      final type = data['type']?.toString();
      setState(() {
        if (type == 'reaction') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: data['reaction']?.toString(), deliveredAt: old.deliveredAt, readAt: old.readAt);
        } else if (type == 'read') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: old.reaction, deliveredAt: old.deliveredAt, readAt: old.readAt ?? DateTime.now());
        } else if (type == 'delivered') {
          messages[index] = ChatMessage(id: old.id, senderId: old.senderId, type: old.type, body: old.body, createdAt: old.createdAt, attachmentId: old.attachmentId, attachmentName: old.attachmentName, replyTo: old.replyTo, reaction: old.reaction, deliveredAt: old.deliveredAt ?? DateTime.now(), readAt: old.readAt);
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
      final loaded = await cloud.fetchMessages(limit: 80);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(loaded);
        loading = false;
      });
      await _markUnread(loaded);
      _scrollToBottom(animated: false);
    } catch (_) {
      if (mounted) setState(() => loading = false);
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
    final id = _newLocalUuid();
    final replyId = replyingTo?.id;
    final optimistic = ChatMessage(
      id: id,
      senderId: myDeviceId ?? 'self',
      type: 'text',
      body: text,
      createdAt: DateTime.now(),
      replyTo: replyId,
    );
    setState(() {
      messages.add(optimistic);
      composer.clear();
      replyingTo = null;
    });
    cloud.setTyping(false);
    _scrollToBottom();
    try {
      final msg = await cloud.sendText(text, replyTo: replyId, id: id);
      _replaceMessage(msg);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        messages.removeWhere((m) => m.id == id);
        composer.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسال انجام نشد؛ اتصال دفتر مشترک را بررسی کن.')));
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

  Future<void> toggleRecord() async {
    if (recording) {
      final path = await recorder.stop();
      if (mounted) setState(() => recording = false);
      if (path != null) await _sendFile(path, 'audio');
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

  Future<void> _sendFile(String path, String kind) async {
    if (!cloud.configured) return;
    final id = _newLocalUuid();
    final replyId = replyingTo?.id;
    final optimistic = ChatMessage(
      id: id,
      senderId: myDeviceId ?? 'self',
      type: kind,
      body: '',
      createdAt: DateTime.now(),
      replyTo: replyId,
    );
    setState(() {
      messages.add(optimistic);
      replyingTo = null;
    });
    _scrollToBottom();
    try {
      final msg = await cloud.sendAttachment(path: path, kind: kind, replyTo: replyId, id: id);
      _replaceMessage(msg);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() => messages.removeWhere((m) => m.id == id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل ارسال نشد. حجم فایل و اتصال دفتر مشترک را بررسی کن.')));
      }
    } finally {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
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
    messageSub?.cancel();
    typingSub?.cancel();
    presenceSub?.cancel();
    statusSub?.cancel();
    deletedSub?.cancel();
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
          title: selecting
              ? Text(
                  '${selectedIds.length} پیام انتخاب شده',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                )
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
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final message = messages[i];
                        final showDay = i == 0 || !_sameDay(message.createdAt, messages[i - 1].createdAt);
                        return Column(
                          children: [
                            if (showDay) _daySeparator(message.createdAt, c.primary),
                            _bubble(message, c),
                          ],
                        );
                      },
                    ),
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
        onDoubleTap: selecting
            ? null
            : () => cloud.react(
                  message.id,
                  message.reaction == '❤️' ? '' : '❤️',
                ),
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
              if (message.type == 'video' && message.attachmentId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _RemoteVideoBubble(
                    key: ValueKey('video-${message.id}'),
                    url: cloud.mediaUrl(message.attachmentId!),
                    headers: token == null ? const {} : {'Authorization': 'Bearer $token'},
                  ),
                ),
              if ((message.type == 'image' || message.type == 'video' || message.type == 'audio' || message.type == 'file') && !message.hasAttachment)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(message.type == 'video' ? 'در حال ارسال ویدیو…' : message.type == 'image' ? 'در حال ارسال عکس…' : message.type == 'audio' ? 'در حال ارسال صدا…' : 'در حال ارسال فایل…'),
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
                  if (message.reaction != null && message.reaction!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(message.reaction!, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('پاسخ به پیام'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('انتخاب پیام'),
              onTap: () => Navigator.pop(sheetContext, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('واکنش ❤️'),
              onTap: () => Navigator.pop(sheetContext, 'react'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'reply') {
      setState(() => replyingTo = message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).unfocus();
      });
    } else if (choice == 'select') {
      _toggleSelection(message);
    } else if (choice == 'react') {
      await cloud.react(message.id, message.reaction == '❤️' ? '' : '❤️');
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
    } else if (choice == 'file') {
      await sendAnyFile();
    }
  }
}


class _RemoteVideoBubble extends StatefulWidget {
  const _RemoteVideoBubble({super.key, required this.url, required this.headers});
  final String url;
  final Map<String, String> headers;

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
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.broken_image_rounded, size: 40),
      );
    }
    if (!ready) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const CircularProgressIndicator(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: GestureDetector(
        onTap: () {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
          setState(() {});
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            if (!controller.value.isPlaying)
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
          ],
        ),
      ),
    );
  }
}
