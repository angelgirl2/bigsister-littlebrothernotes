import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class StorageService {
  StorageService._(this.prefs, this.dataFile, this.mediaDir);
  final SharedPreferences prefs;
  final File dataFile;
  final Directory mediaDir;
  List<NoteItem> _notes = [];
  Future<void> Function()? _onChanged;
  bool _suppressChangeNotification = false;

  static const notesKey = 'big_sister_notes_v4';
  static const themeKey = 'big_sister_theme_v4';
  static const pinKey = 'big_sister_pin_v4';
  static const bioKey = 'big_sister_bio_v4';
  static const quoteIndexKey = 'big_sister_quote_index_v4';
  static const quoteAtKey = 'big_sister_quote_at_v4';
  static const cloudDeletedIdsKey = 'big_sister_cloud_deleted_ids_v1';
  static const cloudMediaRefsKey = 'big_sister_cloud_media_refs_v1';
  static const schema = 4;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory('${dir.path}/big_sister_media');
    if (!await media.exists()) await media.create(recursive: true);
    final service = StorageService._(prefs, File('${dir.path}/big_sister_notes_v4.json'), media);
    await service._load();
    return service;
  }

  Future<void> _load() async {
    _notes = [];
    try {
      if (await dataFile.exists()) {
        final decoded = jsonDecode(await dataFile.readAsString());
        if (decoded is Map) {
          final list = decoded['notes'];
          if (list is List) {
            _notes = list.map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      }
    } catch (_) {}
    if (_notes.isEmpty) {
      final raw = prefs.getString(notesKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            _notes = decoded.map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        } catch (_) {}
      }
    }
    await _persist();
  }

  void setCloudChangedCallback(Future<void> Function()? callback) {
    _onChanged = callback;
  }

  Future<void> _notifyChanged() async {
    if (_suppressChangeNotification || _onChanged == null) return;
    try {
      unawaited(_onChanged!.call());
    } catch (_) {}
  }

  Future<void> _persist() async {
    final payload = jsonEncode({'schema': schema, 'notes': _notes.map((e) => e.toJson()).toList(), 'savedAt': DateTime.now().toIso8601String()});
    final temp = File('${dataFile.path}.tmp');
    await temp.writeAsString(payload, flush: true);
    if (await dataFile.exists()) await dataFile.delete();
    await temp.rename(dataFile.path);
    await prefs.setString(notesKey, jsonEncode(_notes.map((e) => e.toJson()).toList()));
    await _notifyChanged();
  }

  List<NoteItem> loadNotes() => List<NoteItem>.from(_notes);
  List<NoteItem> activeNotes() => _notes.where((e) => !e.inTrash).toList();
  List<NoteItem> trashNotes() => _notes.where((e) => e.inTrash).toList();

  Future<void> saveNotes(List<NoteItem> notes) async { _notes = List<NoteItem>.from(notes); await _persist(); }
  Future<void> upsert(NoteItem note) async {
    final deleted = prefs.getStringList(cloudDeletedIdsKey) ?? <String>[];
    if (deleted.remove(note.id)) await prefs.setStringList(cloudDeletedIdsKey, deleted);
    final i = _notes.indexWhere((e) => e.id == note.id);
    if (i == -1) {
      _notes.insert(0, note);
    } else {
      _notes[i] = note;
    }
    await _persist();
  }
  Future<void> moveToTrash(String id) async { final n = _find(id); if (n == null) return; n.deletedAt = DateTime.now(); n.updatedAt = DateTime.now(); await _persist(); }
  Future<void> moveAllToTrash() async { final now = DateTime.now(); for (final n in _notes.where((e) => !e.inTrash)) { n.deletedAt = now; n.updatedAt = now; } await _persist(); }
  Future<void> restore(String id) async { final n = _find(id); if (n == null) return; n.deletedAt = null; n.updatedAt = DateTime.now(); await _persist(); }
  Future<void> deleteForever(String id) async {
    final n = _find(id);
    if (n == null) return;
    for (final p in n.imagePaths) {
      final f = File(p);
      if (await f.exists()) await f.delete();
    }
    if (n.audioPath != null) {
      final f = File(n.audioPath!);
      if (await f.exists()) await f.delete();
    }
    _notes.removeWhere((e) => e.id == id);
    final deleted = prefs.getStringList(cloudDeletedIdsKey) ?? <String>[];
    if (!deleted.contains(id)) deleted.add(id);
    await prefs.setStringList(cloudDeletedIdsKey, deleted);
    await _persist();
  }
  NoteItem? _find(String id) { for (final n in _notes) { if (n.id == id) return n; } return null; }

  AppThemeChoice loadTheme() => AppThemeChoice.values.firstWhere((e) => e.name == prefs.getString(themeKey), orElse: () => AppThemeChoice.turquoise);
  Future<void> saveTheme(AppThemeChoice value) => prefs.setString(themeKey, value.name);

  int dailyQuoteIndex(int count) {
    if (count <= 0) return 0;
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, now.day);
    final lastMs = prefs.getInt(quoteAtKey);
    final lastIndex = prefs.getInt(quoteIndexKey);
    if (lastMs != null && lastIndex != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (current.difference(last).inHours < 24) return lastIndex % count;
    }
    final next = (lastIndex ?? -1) + 1;
    prefs.setInt(quoteIndexKey, next % count);
    prefs.setInt(quoteAtKey, current.millisecondsSinceEpoch);
    return next % count;
  }
  String get fixedName => 'خواهر بزرگم';
  String? loadPin() => prefs.getString(pinKey);
  Future<void> savePin(String pin) => prefs.setString(pinKey, pin);
  Future<void> clearPin() => prefs.remove(pinKey);
  bool loadBiometric() => prefs.getBool(bioKey) ?? false;
  Future<void> saveBiometric(bool value) => prefs.setBool(bioKey, value);

  Future<String> copyToMedia(File source, String subfolder) async {
    final targetDir = Directory('${mediaDir.path}/$subfolder');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);
    final ext = source.path.contains('.') ? source.path.substring(source.path.lastIndexOf('.')) : '';
    final target = File('${targetDir.path}/${DateTime.now().microsecondsSinceEpoch}$ext');
    await source.copy(target.path);
    return target.path;
  }

  Future<String> copyBytesToMedia(List<int> bytes, String subfolder, String extension) async {
    final targetDir = Directory('${mediaDir.path}/$subfolder');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);
    final target = File('${targetDir.path}/${DateTime.now().microsecondsSinceEpoch}$extension');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<Map<String, dynamic>> exportJson() async {
    final media = <String, String>{};
    for (final note in _notes) {
      for (final path in [...note.imagePaths, if (note.audioPath != null) note.audioPath!]) {
        final file = File(path);
        if (!await file.exists()) continue;
        try {
          media[path] = base64Encode(await file.readAsBytes());
        } catch (_) {}
      }
    }
    return {
      'schema': schema,
      'notes': _notes.map((e) => e.toJson()).toList(),
      'theme': loadTheme().name,
      'lockEnabled': loadPin() != null,
      'pin': loadPin(),
      'biometric': loadBiometric(),
      'media': media,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }



  Map<String, String> _cloudMediaRefs() {
    final raw = prefs.getString(cloudMediaRefsKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return <String, String>{};
  }

  Future<void> rememberCloudMediaRef(String localPath, String remoteRef) async {
    final refs = _cloudMediaRefs();
    refs[localPath] = remoteRef;
    await prefs.setString(cloudMediaRefsKey, jsonEncode(refs));
  }

  String _remoteMediaId(String ref) {
    final body = ref.substring('cloud-media://'.length);
    final slash = body.indexOf('/');
    return (slash < 0 ? body : body.substring(0, slash)).trim();
  }

  String _remoteMediaName(String ref) {
    final body = ref.substring('cloud-media://'.length);
    final slash = body.indexOf('/');
    if (slash < 0 || slash == body.length - 1) return '';
    try {
      return Uri.decodeComponent(body.substring(slash + 1));
    } catch (_) {
      return body.substring(slash + 1);
    }
  }

  String _safeRemoteFileName(String value, String id) {
    final clean = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (clean.isEmpty) return 'cloud_$id.bin';
    final dot = clean.lastIndexOf('.');
    final ext = dot > 0 && dot < clean.length - 1 ? clean.substring(dot) : '.bin';
    return 'cloud_$id$ext';
  }

  Future<Map<String, dynamic>> exportCloudJson() async {
    final refs = _cloudMediaRefs();
    final cloudNotes = <Map<String, dynamic>>[];

    String encodePath(String path) => refs[path] ?? path;

    for (final note in _notes) {
      final data = note.toJson();
      final images = note.imagePaths.map(encodePath).toList();
      data['imagePaths'] = images;
      data['imagePath'] = images.isEmpty ? null : images.first;
      if (note.audioPath != null) data['audioPath'] = encodePath(note.audioPath!);
      cloudNotes.add(data);
    }

    return {
      'schema': schema,
      'notes': cloudNotes,
      'deletedIds': prefs.getStringList(cloudDeletedIdsKey) ?? const <String>[],
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyCloudJson(
    Map<String, dynamic> json, {
    Future<List<int>?> Function(String remoteRef)? resolveMedia,
  }) async {
    final rawNotes = (json['notes'] as List?) ?? const [];
    final remote = rawNotes
        .map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final remoteDeleted = ((json['deletedIds'] as List?) ?? const [])
        .whereType<String>()
        .toSet();
    final refs = _cloudMediaRefs();
    final resolvedPaths = <String, String>{};

    Future<String> resolvePath(String source, String folder) async {
      if (!source.startsWith('cloud-media://')) return source;
      if (resolvedPaths.containsKey(source)) return resolvedPaths[source]!;

      final knownLocal = refs.entries.firstWhere(
        (entry) => entry.value == source && File(entry.key).existsSync(),
        orElse: () => const MapEntry('', ''),
      );
      if (knownLocal.key.isNotEmpty) {
        resolvedPaths[source] = knownLocal.key;
        return knownLocal.key;
      }
      if (resolveMedia == null) return source;

      final bytes = await resolveMedia(source);
      if (bytes == null || bytes.isEmpty) return source;
      final id = _remoteMediaId(source);
      final name = _remoteMediaName(source);
      final fileName = _safeRemoteFileName(name, id);
      final dir = Directory('${mediaDir.path}/$folder');
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = File('${dir.path}/$fileName');
      if (!await target.exists()) {
        await target.writeAsBytes(bytes, flush: true);
      }
      refs[target.path] = source;
      resolvedPaths[source] = target.path;
      return target.path;
    }

    _suppressChangeNotification = true;
    try {
      final localById = {for (final n in _notes) n.id: n};
      for (final deletedId in remoteDeleted) {
        final local = localById.remove(deletedId);
        if (local != null) {
          for (final p in local.imagePaths) {
            final f = File(p);
            if (await f.exists()) await f.delete();
          }
          if (local.audioPath != null) {
            final f = File(local.audioPath!);
            if (await f.exists()) await f.delete();
          }
        }
      }

      for (final n in remote) {
        if (remoteDeleted.contains(n.id)) continue;
        n.imagePaths = [
          for (final p in n.imagePaths) await resolvePath(p, 'images'),
        ];
        if (n.audioPath != null) {
          n.audioPath = await resolvePath(n.audioPath!, 'audio');
        }
        final existing = localById[n.id];
        if (existing == null || n.updatedAt.isAfter(existing.updatedAt)) {
          localById[n.id] = n;
        }
      }

      _notes = localById.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final mergedDeleted = <String>{
        ...(prefs.getStringList(cloudDeletedIdsKey) ?? const <String>[]),
        ...remoteDeleted,
      }..removeWhere((id) => _notes.any((n) => n.id == id));
      await prefs.setStringList(cloudDeletedIdsKey, mergedDeleted.toList());
      await prefs.setString(cloudMediaRefsKey, jsonEncode(refs));
      await _persist();
    } finally {
      _suppressChangeNotification = false;
    }
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    final rawNotes = (json['notes'] as List?) ?? const [];
    final list = rawNotes.map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final rawMedia = Map<String, dynamic>.from((json['media'] as Map?) ?? const {});
    final pathMap = <String, String>{};

    for (final entry in rawMedia.entries) {
      final sourcePath = entry.key;
      final encoded = entry.value?.toString();
      if (encoded == null || encoded.isEmpty) continue;
      try {
        final bytes = base64Decode(encoded);
        final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '';
        final folder = sourcePath.toLowerCase().contains('audio') ? 'audio' : 'images';
        pathMap[sourcePath] = await copyBytesToMedia(bytes, folder, ext);
      } catch (_) {}
    }

    for (final note in list) {
      note.imagePaths = note.imagePaths.map((p) => pathMap[p] ?? p).toList();
      if (note.audioPath != null) note.audioPath = pathMap[note.audioPath!] ?? note.audioPath;
    }

    _notes = list;
    final deleted = prefs.getStringList(cloudDeletedIdsKey) ?? <String>[];
    deleted.removeWhere((id) => list.any((n) => n.id == id));
    await prefs.setStringList(cloudDeletedIdsKey, deleted);
    await _persist();
    final theme = json['theme'] as String?;
    if (theme != null) await saveTheme(AppThemeChoice.values.firstWhere((e) => e.name == theme, orElse: () => AppThemeChoice.turquoise));
    final pin = json['pin'] as String?;
    if (pin != null && pin.isNotEmpty) await savePin(pin); else await clearPin();
    await saveBiometric(json['biometric'] as bool? ?? false);
  }

  Future<void> purgeOldTrash({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final old = _notes.where((e) => e.deletedAt != null && e.deletedAt!.isBefore(cutoff)).map((e) => e.id).toList();
    for (final id in old) { await deleteForever(id); }
  }
}
