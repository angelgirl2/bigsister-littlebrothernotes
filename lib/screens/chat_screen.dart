import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../cloud/chat_models.dart';
import '../cloud/cloud_service.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

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
  Timer? typingTimer;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool playing = false;
  bool otherOnline = false;
  bool otherTyping = false;
  String? myDeviceId;
  String? token;
  String? playingId;
  Duration audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;

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
    if (messages.any((m) => m.id == message.id)) return;
    if (!mounted) return;
    setState(() => messages.add(message));
    if (message.senderId != myDeviceId) {
      cloud.markRead(message.id);
    }
    _scrollToBottom();
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

  Future<void> sendText() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending || !cloud.configured) return;
    setState(() => sending = true);
    composer.clear();
    if (mounted) setState(() {});
    cloud.setTyping(false);
    try {
      final msg = await cloud.sendText(text);
      if (mounted && !messages.any((m) => m.id == msg.id)) {
        setState(() => messages.add(msg));
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        composer.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسال انجام نشد؛ اتصال دفتر مشترک را بررسی کن.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendAnyFile() async {
    if (sending) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return;
    await _sendFile(path, 'file');
  }

  Future<void> sendImage() async {
    if (sending) return;
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x == null) return;
    await _sendFile(x.path, 'image');
  }

  Future<void> toggleRecord() async {
    if (sending) return;
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
    setState(() => sending = true);
    try {
      final msg = await cloud.sendAttachment(path: path, kind: kind);
      if (mounted && !messages.any((m) => m.id == msg.id)) {
        setState(() => messages.add(msg));
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل ارسال نشد. حجم فایل و اتصال دفتر مشترک را بررسی کن.')));
    } finally {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      if (mounted) setState(() => sending = false);
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
          title: Row(
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
                  Text(cloud.role == 'me' ? 'داداش کوچیکه' : 'آبجی بزرگم', style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(otherTyping ? 'در حال نوشتن…' : (otherOnline ? 'آنلاین' : 'آفلاین'), style: TextStyle(fontSize: 11, color: otherTyping || otherOnline ? c.primary : Colors.white54)),
                ],
              ),
            ],
          ),
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

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _daySeparator(DateTime date, Color accent) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? 'امروز'
        : _sameDay(date, now.subtract(const Duration(days: 1)))
            ? 'دیروز'
            : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onDoubleTap: () => cloud.react(
          message.id,
          message.reaction == '❤️' ? '' : '❤️',
        ),
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
    );
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

  String _time(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _composer(ThemeColors c) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(onPressed: sending ? null : sendImage, icon: Icon(Icons.image_rounded, color: c.primary)),
            IconButton(onPressed: sending ? null : sendAnyFile, icon: Icon(Icons.attach_file_rounded, color: c.secondary)),
            Expanded(
              child: TextField(
                controller: composer,
                onChanged: _onTextChanged,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(hintText: 'برای نفر مقابلت بنویس…', filled: true),
              ),
            ),
            const SizedBox(width: 4),
            if (composer.text.trim().isEmpty)
              IconButton(
                onPressed: sending ? null : toggleRecord,
                icon: Icon(recording ? Icons.stop_circle_rounded : Icons.mic_rounded, color: recording ? Colors.redAccent : c.primary, size: 30),
              )
            else
              IconButton(
                onPressed: sending ? null : sendText,
                icon: Icon(Icons.send_rounded, color: c.primary, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}
