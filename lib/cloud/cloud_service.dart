import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../services/storage_service.dart';
import 'chat_models.dart';

class CloudService {
  CloudService._();
  static final CloudService instance = CloudService._();

  static const _railwayUrl = 'https://bigsister-littlebrothernotes.up.railway.app';
  static const _buildUrl = String.fromEnvironment('BIG_SISTER_API_URL', defaultValue: _railwayUrl);
  static const _tokenKey = 'big_sister_cloud_token_v1';
  static const _roomIdKey = 'big_sister_cloud_room_v1';
  static const _deviceIdKey = 'big_sister_cloud_device_v1';
  static const _roleKey = 'big_sister_cloud_role_v1';
  static const _labelKey = 'big_sister_cloud_label_v1';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final StreamController<void> _contentChanged = StreamController<void>.broadcast();
  final StreamController<ChatMessage> _messages = StreamController<ChatMessage>.broadcast();
  final StreamController<CloudLetter> _letters = StreamController<CloudLetter>.broadcast();
  final StreamController<bool> _typing = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _presence = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageStatus = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _deletedMessages = StreamController<String>.broadcast();
  final StreamController<bool> _connectionChanged = StreamController<bool>.broadcast();
  IO.Socket? _socket;
  Dio? _dio;
  bool _initialized = false;
  bool _syncing = false;
  bool _syncQueued = false;
  bool _online = false;
  String? _cachedDeviceId;
  final Set<String> _knownChatMessageIds = <String>{};
  bool _hasConnectedOnce = false;

  Stream<void> get contentChanges => _contentChanged.stream;
  Stream<ChatMessage> get incomingMessages => _messages.stream;
  Stream<CloudLetter> get incomingLetters => _letters.stream;
  Stream<bool> get typingChanges => _typing.stream;
  Stream<Map<String, dynamic>> get presenceChanges => _presence.stream;
  Stream<Map<String, dynamic>> get messageStatusChanges => _messageStatus.stream;
  Stream<String> get deletedMessages => _deletedMessages.stream;
  Stream<bool> get connectionChanges => _connectionChanged.stream;
  bool get online => _online;

  String? _baseUrl;
  String? get baseUrl => _baseUrl;
  String? get role => _role;
  String? get label => _label;

  /// نام این دستگاه بر اساس حسابی که با آن وارد شده است.
  String get myDisplayName {
    final value = _label?.trim();
    if (value != null && value.isNotEmpty) return value;
    return _role == 'sister' ? 'آبجی بزرگ' : 'داداش کوچیکه';
  }

  /// نام نفر مقابل برای نمایش در رابط کاربری.
  String get otherDisplayName => _role == 'sister' ? 'داداش کوچیکه' : 'آبجی بزرگ';
  String? _role;
  String? _label;

  Dio _makeDio(String url) => Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 180),
        headers: {'Accept': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ));

  String _normalizeUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = _normalizeUrl(_buildUrl);
    _role = prefs.getString(_roleKey);
    _label = prefs.getString(_labelKey);
    _cachedDeviceId = await _secure.read(key: _deviceIdKey);
    _dio = _makeDio(normalizedBaseUrl);
    _initialized = true;
    if (configured) {
      await _connectSocket();
    }
  }

  bool get configured => _baseUrl != null && _baseUrl!.trim().isNotEmpty && _role != null;

  Future<String?> get token async => _secure.read(key: _tokenKey);
  Future<String?> get roomId async => _secure.read(key: _roomIdKey);
  Future<String?> get deviceId async => _secure.read(key: _deviceIdKey);

  String get normalizedBaseUrl {
    var url = (_baseUrl ?? '').trim();
    while (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<Map<String, dynamic>> login({required String password}) async {
    await init();
    if (_dio == null || normalizedBaseUrl.isEmpty) throw StateError('server_url_missing');
    // Do not block login on a separate health request. Railway can briefly
    // report a 503 while the app is already able to serve authenticated routes,
    // and a DNS/health failure would otherwise hide the real login response.
    final response = await _dio!.post('/api/auth/login', data: {
      'password': password,
    });
    _ensureOk(response);
    await _saveSession(response.data as Map<String, dynamic>);
    await _connectSocket();
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.write(key: _tokenKey, value: data['token']?.toString());
    await _secure.write(key: _roomIdKey, value: data['roomId']?.toString());
    _cachedDeviceId = data['deviceId']?.toString();
    await _secure.write(key: _deviceIdKey, value: _cachedDeviceId);
    _role = data['role']?.toString();
    _label = data['label']?.toString();
    if (_role != null) await prefs.setString(_roleKey, _role!);
    if (_label != null) await prefs.setString(_labelKey, _label!);
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _online = false;
    _connectionChanged.add(false);
    _role = null;
    _label = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_labelKey);
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _roomIdKey);
    _cachedDeviceId = null;
    _knownChatMessageIds.clear();
    _hasConnectedOnce = false;
    await _secure.delete(key: _deviceIdKey);
  }

  Future<void> _connectSocket() async {
    if (!configured) return;
    final t = await token;
    if (t == null || t.isEmpty) return;
    _socket?.dispose();
    _socket = IO.io(
      normalizedBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': t})
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(-1)
          .setReconnectionDelay(400)
          .setReconnectionDelayMax(3000)
          .build(),
    );
    _socket!
      ..onConnect((_) {
        _online = true;
        _connectionChanged.add(true);
        if (_hasConnectedOnce) {
          unawaited(_catchUpMessages());
        }
        _hasConnectedOnce = true;
      })
      ..onDisconnect((_) {
        _online = false;
        _connectionChanged.add(false);
      })
      ..onConnectError((_) {
        _online = false;
        _connectionChanged.add(false);
      })
      ..on('content:changed', (_) => _contentChanged.add(null))
      ..on('pair:completed', (_) => _contentChanged.add(null))
      ..on('chat:message', (data) {
        try {
          if (data is Map) {
            final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
            final isNew = _knownChatMessageIds.add(message.id);
            _messages.add(message);
            if (isNew && (_cachedDeviceId == null || message.senderId != _cachedDeviceId)) {
              unawaited(NotificationService.instance.showIncomingChat(message));
            }
          }
        } catch (_) {}
      })
      ..on('letter:new', (data) {
        try {
          if (data is Map) _letters.add(CloudLetter.fromJson(Map<String, dynamic>.from(data)));
        } catch (_) {}
      })
      ..on('chat:read', (data) {
        if (data is Map) _messageStatus.add({'type': 'read', ...Map<String, dynamic>.from(data)});
      })
      ..on('chat:delivered', (data) {
        if (data is Map) _messageStatus.add({'type': 'delivered', ...Map<String, dynamic>.from(data)});
      })
      ..on('chat:reaction', (data) {
        if (data is Map) _messageStatus.add({'type': 'reaction', ...Map<String, dynamic>.from(data)});
      })
      ..on('chat:deleted', (data) {
        final id = data is Map ? data['id']?.toString() : data?.toString();
        if (id != null && id.isNotEmpty) _deletedMessages.add(id);
      })
      ..on('typing', (data) {
        if (data is Map) _typing.add(data['typing'] == true);
      })
      ..on('presence', (data) {
        if (data is Map) _presence.add(Map<String, dynamic>.from(data));
      })
      ..on('presence:state', (data) {
        if (data is Map) {
          final devices = (data['deviceIds'] as List? ?? const []).whereType<String>();
          for (final id in devices) {
            _presence.add({'deviceId': id, 'online': true, 'at': DateTime.now().toUtc().toIso8601String()});
          }
        }
      });
    _socket!.connect();
  }

  Future<String> _uploadNoteMedia(File file, String kind) async {
    final t = await token;
    if (t == null || t.isEmpty) throw StateError('Not connected');
    final originalName = file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final form = FormData.fromMap({
      'kind': kind,
      'sha256': digest,
      'file': MultipartFile.fromBytes(bytes, filename: originalName),
    });
    final response = await _dio!.post(
      '/api/sync/media',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
    final id = response.data['id']?.toString();
    if (id == null || id.isEmpty) throw StateError('media_upload_failed');
    final name = response.data['originalName']?.toString() ?? originalName;
    return 'cloud-media://$id/${Uri.encodeComponent(name)}';
  }

  Future<Map<String, dynamic>> _prepareCloudSnapshot(StorageService storage) async {
    final snapshot = await storage.exportCloudJson();
    final rawNotes = (snapshot['notes'] as List?) ?? const [];
    final cache = <String, String>{};
    final notes = <Map<String, dynamic>>[];

    Future<String> preparePath(String path, String kind) async {
      if (path.startsWith('cloud-media://')) return path;
      final cached = cache[path];
      if (cached != null) return cached;
      final file = File(path);
      if (!await file.exists()) return path;
      final remoteRef = await _uploadNoteMedia(file, kind);
      cache[path] = remoteRef;
      await storage.rememberCloudMediaRef(path, remoteRef);
      return remoteRef;
    }

    for (final raw in rawNotes) {
      final data = Map<String, dynamic>.from(raw as Map);
      final images = ((data['imagePaths'] as List?) ?? const []).whereType<String>().toList();
      final mappedImages = <String>[];
      for (final path in images) {
        mappedImages.add(await preparePath(path, 'image'));
      }
      data['imagePaths'] = mappedImages;
      data['imagePath'] = mappedImages.isEmpty ? null : mappedImages.first;
      final audio = data['audioPath']?.toString();
      if (audio != null && audio.isNotEmpty) {
        data['audioPath'] = await preparePath(audio, 'audio');
      }
      notes.add(data);
    }

    return {
      ...snapshot,
      'notes': notes,
    };
  }

  Future<List<int>?> _downloadNoteMedia(String remoteRef) async {
    final t = await token;
    if (t == null || t.isEmpty || !remoteRef.startsWith('cloud-media://')) return null;
    final body = remoteRef.substring('cloud-media://'.length);
    final id = body.split('/').first;
    if (id.isEmpty) return null;
    try {
      final response = await _dio!.get<List<int>>(
        '/api/media/$id',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $t'},
        ),
      );
      _ensureOk(response);
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> syncNow(StorageService storage) async {
    if (!configured) return {};
    if (_syncing) {
      _syncQueued = true;
      return {};
    }
    _syncing = true;
    try {
      final snapshot = await _prepareCloudSnapshot(storage);
      final t = await token;
      if (t == null) return {};
      final response = await _dio!.put(
        '/api/sync/snapshot',
        data: {'payload': snapshot},
        options: Options(headers: {'Authorization': 'Bearer $t'}),
      );
      _ensureOk(response);
      if (!_online) {
        _online = true;
        _connectionChanged.add(true);
      }
      final payload = Map<String, dynamic>.from(response.data['payload'] as Map);
      await storage.applyCloudJson(payload, resolveMedia: _downloadNoteMedia);
      return payload;
    } catch (_) {
      return {};
    } finally {
      _syncing = false;
      if (_syncQueued) {
        _syncQueued = false;
        unawaited(syncNow(storage));
      }
    }
  }

  Future<Map<String, dynamic>> pullAndApply(StorageService storage) async {
    if (!configured || _syncing) return {};
    _syncing = true;
    try {
      final t = await token;
      if (t == null) return {};
      final response = await _dio!.get(
        '/api/sync/snapshot',
        options: Options(headers: {'Authorization': 'Bearer $t'}),
      );
      _ensureOk(response);
      if (!_online) {
        _online = true;
        _connectionChanged.add(true);
      }
      final payload = Map<String, dynamic>.from(response.data['payload'] as Map);
      await storage.applyCloudJson(payload, resolveMedia: _downloadNoteMedia);
      return payload;
    } catch (_) {
      return {};
    } finally {
      _syncing = false;
    }
  }

  Future<List<CloudMember>> pairStatus() async {
    if (!configured) return [];
    final t = await token;
    if (t == null) return [];
    final response = await _dio!.get('/api/pair/status', options: Options(headers: {'Authorization': 'Bearer $t'}));
    _ensureOk(response);
    final list = (response.data['members'] as List? ?? const []);
    return list.map((e) => CloudMember.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<ChatMessage> sendText(String body, {String? replyTo, String? id}) async {
    final payload = <String, dynamic>{
      'id': id ?? _uuidV4(),
      'type': 'text',
      'body': body,
      'attachmentId': null,
      'attachmentName': null,
      'replyTo': replyTo,
    };
    final socket = _socket;
    if (socket != null && _online) {
      final result = await _emitWithAck('chat:send', payload);
      if (result != null && result['error'] == null) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(result));
      }
    }
    return _sendMessage(
      type: 'text',
      body: body,
      replyTo: replyTo,
      id: payload['id']?.toString(),
    );
  }

  Future<ChatMessage> sendAttachment({required String path, required String kind, String caption = '', String? replyTo, String? id}) async {
    final t = await token;
    if (t == null) throw StateError('Not connected');
    final originalName = File(path).uri.pathSegments.last;
    final form = FormData.fromMap({
      'kind': kind,
      'file': await MultipartFile.fromFile(path, filename: originalName),
    });
    final uploadResponse = await _dio!.post('/api/media', data: form, options: Options(headers: {'Authorization': 'Bearer $t'}));
    _ensureOk(uploadResponse);
    return _sendMessage(
      type: kind,
      body: caption,
      attachmentId: uploadResponse.data['id']?.toString(),
      attachmentName: uploadResponse.data['originalName']?.toString() ?? originalName,
      replyTo: replyTo,
      id: id,
    );
  }

  Future<ChatMessage> _sendMessage({required String type, required String body, String? attachmentId, String? attachmentName, String? replyTo, String? id}) async {
    final t = await token;
    if (t == null) throw StateError('Not connected');
    final response = await _dio!.post(
      '/api/chat/messages',
      data: {
        'id': id ?? _uuidV4(),
        'type': type,
        'body': body,
        'attachmentId': attachmentId,
        'attachmentName': attachmentName,
        'replyTo': replyTo,
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(response.data['message'] as Map));
  }

  Future<Map<String, dynamic>?> _emitWithAck(String event, Map<String, dynamic> payload) async {
    final socket = _socket;
    if (socket == null || !_online) return null;
    final completer = Completer<Map<String, dynamic>?>();
    var completed = false;
    void finish(Map<String, dynamic>? value) {
      if (completed) return;
      completed = true;
      if (!completer.isCompleted) completer.complete(value);
    }
    try {
      socket.emitWithAck(event, payload, ack: (data) {
        if (data is Map) {
          finish(Map<String, dynamic>.from(data));
        } else {
          finish(null);
        }
      });
      Future<void>.delayed(const Duration(seconds: 8), () => finish(null));
      return await completer.future;
    } catch (_) {
      finish(null);
      return null;
    }
  }

  String _uuidV4() {
    final r = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final stamp = '${r}00000000000000000000000000000000';
    return '${stamp.substring(0, 8)}-${stamp.substring(8, 12)}-4${stamp.substring(13, 16)}-a${stamp.substring(17, 20)}-${stamp.substring(20, 32)}';
  }

  Future<List<ChatMessage>> fetchMessages({DateTime? before, int limit = 50}) async {
    final t = await token;
    if (t == null) return [];
    final response = await _dio!.get(
      '/api/chat/messages',
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
    final list = response.data['messages'] as List? ?? const [];
    final parsed = list.map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    _knownChatMessageIds.addAll(parsed.map((m) => m.id));
    return parsed;
  }

  Future<void> _catchUpMessages() async {
    try {
      final knownBeforeFetch = Set<String>.of(_knownChatMessageIds);
      final latest = await fetchMessages(limit: 100);
      for (final message in latest) {
        if (!knownBeforeFetch.contains(message.id)) {
          // Reconnect catch-up repairs anything missed while offline. The normal
          // socket event owns notifications, so old messages are not re-alerted.
          _messages.add(message);
        }
      }
    } catch (_) {}
  }

  Future<CloudLetter> sendLetter({required String title, required String body}) async {
    final t = await token;
    if (t == null || t.isEmpty) throw StateError('Not connected');
    final response = await _dio!.post(
      '/api/letters',
      data: {'title': title.trim().isEmpty ? 'نامه' : title.trim(), 'body': body.trim()},
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
    return CloudLetter.fromJson(Map<String, dynamic>.from(response.data['letter'] as Map));
  }

  Future<List<CloudLetter>> fetchLetters({int limit = 100}) async {
    final t = await token;
    if (t == null || t.isEmpty) return [];
    final response = await _dio!.get(
      '/api/letters',
      queryParameters: {'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
    final list = response.data['letters'] as List? ?? const [];
    return list.map((e) => CloudLetter.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> markLetterRead(String id) async {
    final t = await token;
    if (t == null || t.isEmpty) return;
    await _dio!.patch('/api/letters/$id/read', options: Options(headers: {'Authorization': 'Bearer $t'}));
  }

  String mediaUrl(String id) => '$normalizedBaseUrl/api/media/$id';

  Future<List<int>> downloadMediaBytes(String id) async {
    final t = await token;
    if (t == null) throw StateError('Not connected');
    final response = await _dio!.get<List<int>>(
      '/api/media/$id',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $t'},
      ),
    );
    _ensureOk(response);
    return response.data ?? const <int>[];
  }

  Future<String?> authHeaderToken() => token;

  Future<void> markRead(String id) async {
    final t = await token;
    if (t == null) return;
    await _dio!.patch('/api/chat/messages/$id/read', options: Options(headers: {'Authorization': 'Bearer $t'}));
    _socket?.emit('message:read', id);
  }

  Future<void> deleteMessage(String id) async {
    final t = await token;
    if (t == null || t.isEmpty) throw StateError('Not connected');
    final response = await _dio!.delete(
      '/api/chat/messages/$id',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
  }

  Future<void> react(String id, String reaction) async {
    final t = await token;
    if (t == null) return;
    final response = await _dio!.patch(
      '/api/chat/messages/$id/reaction',
      data: {'reaction': reaction},
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    _ensureOk(response);
  }

  void setTyping(bool value) => _socket?.emit('typing', value);

  void _ensureOk(Response<dynamic> response) {
    if (response.statusCode == null || response.statusCode! >= 300) {
      final data = response.data;
      final error = data is Map ? data['error']?.toString() : null;
      throw StateError(error ?? 'request_failed');
    }
  }

  Future<void> dispose() async {
    _socket?.dispose();
    await _contentChanged.close();
    await _messages.close();
    await _letters.close();
    await _typing.close();
    await _presence.close();
    await _messageStatus.close();
    await _deletedMessages.close();
    await _connectionChanged.close();
  }
}
