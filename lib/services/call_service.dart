import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../cloud/cloud_service.dart';
import 'notification_service.dart';

class CallSession {
  const CallSession({
    required this.status,
    required this.video,
    required this.outgoing,
    this.callId,
    this.error,
    this.muted = false,
    this.cameraEnabled = true,
    this.speakerOn = true,
  });

  final String status; // idle, ringing, connecting, active, ended
  final bool video;
  final bool outgoing;
  final String? callId;
  final String? error;
  final bool muted;
  final bool cameraEnabled;
  final bool speakerOn;
}

/// Authenticated call signaling goes through the app's Railway room only.
/// No third-party STUN/TURN service is configured. Direct ICE candidates are
/// private to the two room members; networks with restrictive NAT may require
/// a separately operated TURN server, which Railway public UDP ingress cannot host.
class CallService {
  CallService._();
  static final instance = CallService._();

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final StreamController<CallSession> _states = StreamController.broadcast();
  Stream<CallSession> get states => _states.stream;
  StreamSubscription<Map<String, dynamic>>? _signals;
  RTCPeerConnection? _peer;
  MediaStream? _local;
  String? _callId;
  bool _video = false;
  bool _outgoing = false;
  bool _ready = false;
  bool _remoteDescriptionSet = false;
  bool _offerSent = false;
  bool _answered = false;
  bool _muted = false;
  bool _cameraEnabled = true;
  bool _speakerOn = true;
  DateTime? _activeSince;
  Timer? _ringTimeout;
  Timer? _connectTimeout;
  Timer? _disconnectTimeout;
  Map<String, dynamic>? _offer;
  final List<RTCIceCandidate> _queuedCandidates = [];
  final List<RTCIceCandidate> _localCandidatesBeforeOffer = [];
  CallSession _state = const CallSession(status: 'idle', video: false, outgoing: false);
  CallSession get current => _state;
  Duration get activeDuration => _activeSince == null ? Duration.zero : DateTime.now().difference(_activeSince!);

  Future<void> initialize() async {
    if (_ready) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _signals = CloudService.instance.callSignals.listen(_handleSignal);
    _ready = true;
  }

  void _emit(String status, {String? error}) {
    if (status == 'active') {
      _activeSince ??= DateTime.now();
      _connectTimeout?.cancel();
    }
    _state = CallSession(
      status: status,
      video: _video,
      outgoing: _outgoing,
      callId: _callId,
      error: error,
      muted: _muted,
      cameraEnabled: _cameraEnabled,
      speakerOn: _speakerOn,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  Future<void> startOutgoing({required bool video}) async {
    await initialize();
    if (_state.status == 'ringing' || _state.status == 'connecting' || _state.status == 'active') {
      throw StateError('تماس دیگری در جریان است.');
    }
    _video = video;
    _outgoing = true;
    _answered = false;
    _muted = false;
    _cameraEnabled = true;
    _speakerOn = video;
    _activeSince = null;
    _callId = DateTime.now().microsecondsSinceEpoch.toString();
    _offer = null;
    _queuedCandidates.clear();
    _localCandidatesBeforeOffer.clear();
    _offerSent = false;
    try {
      await _createPeer();
      await _openMedia();
      final offer = await _peer!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': video,
      });
      await _peer!.setLocalDescription(offer);
      _emit('connecting');
      await CloudService.instance.sendCallSignal({
        'type': 'offer',
        'callId': _callId,
        'video': video,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
      _offerSent = true;
      final earlyCandidates = List<RTCIceCandidate>.from(_localCandidatesBeforeOffer);
      _localCandidatesBeforeOffer.clear();
      for (final candidate in earlyCandidates) {
        await _sendCandidate(candidate);
      }
      _ringTimeout?.cancel();
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (_outgoing && !_answered && _callId != null && _state.status == 'connecting') {
          try {
            await CloudService.instance.sendCallSignal({
              'type': 'hangup',
              'callId': _callId,
              'missed': true,
            });
          } catch (_) {}
          await _cleanup();
          _emit('ended', error: 'پاسخی دریافت نشد؛ تماس در تاریخچه ثبت شد.');
        }
      });
    } catch (error) {
      await _cleanup();
      _emit('ended', error: 'شروع تماس ممکن نشد؛ مجوز میکروفون/دوربین و اتصال سرور را بررسی کن.');
      rethrow;
    }
  }

  Future<void> acceptIncoming() async {
    final offer = _offer;
    if (offer == null || _callId == null) return;
    _ringTimeout?.cancel();
    _muted = false;
    _cameraEnabled = true;
    _speakerOn = _video;
    unawaited(NotificationService.instance.cancelIncomingCall());
    await _createPeer();
    await _openMedia();
    await _peer!.setRemoteDescription(RTCSessionDescription(offer['sdp']?.toString(), offer['sdpType']?.toString() ?? 'offer'));
    _remoteDescriptionSet = true;
    await _flushCandidates();
    final answer = await _peer!.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': _video});
    await _peer!.setLocalDescription(answer);
    await CloudService.instance.sendCallSignal({'type': 'answer', 'callId': _callId, 'sdp': answer.sdp, 'sdpType': answer.type});
    _answered = true;
    _emit('connecting');
    _startConnectionTimeout();
  }

  void _startConnectionTimeout() {
    _connectTimeout?.cancel();
    final id = _callId;
    if (id == null) return;
    _connectTimeout = Timer(const Duration(seconds: 25), () async {
      if (_callId == id && _state.status == 'connecting') {
        await _failCall();
      }
    });
  }

  Future<void> _createPeer() async {
    try { await _peer?.close(); } catch (_) {}
    _remoteDescriptionSet = false;
    // Deliberately no public STUN/TURN endpoints: only direct peer candidates
    // are exchanged inside the authenticated Railway room.
    _peer = await createPeerConnection({'iceServers': <Map<String, dynamic>>[], 'sdpSemantics': 'unified-plan'});
    _peer!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || _callId == null) return;
      if (!_offerSent && _outgoing) {
        _localCandidatesBeforeOffer.add(candidate);
        return;
      }
      unawaited(_sendCandidate(candidate));
    };
    _peer!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        _emit('active');
      }
    };
    _peer!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _disconnectTimeout?.cancel();
        _emit('active');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Allow short network hand-offs before declaring the call lost.
        _disconnectTimeout?.cancel();
        _disconnectTimeout = Timer(const Duration(seconds: 10), () async {
          final currentState = _peer?.connectionState;
          if (_peer != null && currentState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            await _failCall();
          }
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _disconnectTimeout?.cancel();
        unawaited(_failCall());
      }
    };
  }

  Future<void> _failCall() async {
    final id = _callId;
    if (id != null) {
      try { await CloudService.instance.sendCallSignal({'type': 'hangup', 'callId': id}); } catch (_) {}
    }
    await _cleanup();
    _emit('ended', error: 'اتصال مستقیم برقرار نشد. در برخی شبکه‌ها بدون TURN تماس ممکن نیست.');
  }

  Future<void> _sendCandidate(RTCIceCandidate candidate) async {
    final id = _callId;
    if (id == null) return;
    try {
      await CloudService.instance.sendCallSignal({
        'type': 'candidate',
        'callId': id,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (_) {
      // If the signaling socket drops, ICE will time out and the call UI reports failure.
    }
  }

  Future<void> _openMedia() async {
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _video ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24} : false,
    });
    localRenderer.srcObject = _local;
    for (final track in _local!.getTracks()) {
      await _peer!.addTrack(track, _local!);
    }
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  Future<void> toggleMicrophone() async {
    _muted = !_muted;
    for (final track in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
    _emit(_state.status);
  }

  Future<void> toggleCamera() async {
    if (!_video) return;
    _cameraEnabled = !_cameraEnabled;
    for (final track in _local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = _cameraEnabled;
    }
    _emit(_state.status);
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  /// Switch the active call's audio route between the phone earpiece and
  /// speakerphone. Update UI state only after the platform accepts the change.
  Future<void> setSpeakerphone(bool enabled) async {
    await Helper.setSpeakerphoneOn(enabled);
    _speakerOn = enabled;
    _emit(_state.status);
  }

  Future<void> toggleSpeaker() => setSpeakerphone(!_speakerOn);

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final id = data['callId']?.toString();
    if (type == 'offer') {
      if (_state.status == 'ringing' || _state.status == 'connecting' || _state.status == 'active') {
        await CloudService.instance.sendCallSignal({'type': 'busy', 'callId': id});
        return;
      }
      _callId = id;
      _offerSent = true;
      _video = data['video'] == true;
      _outgoing = false;
      _answered = false;
      _muted = false;
      _cameraEnabled = true;
      _speakerOn = _video;
      _activeSince = null;
      _offer = data;
      _queuedCandidates.clear();
      unawaited(NotificationService.instance.showIncomingCall(video: _video));
      _emit('ringing');
      _ringTimeout?.cancel();
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (!_outgoing && _state.status == 'ringing' && _callId == id) {
          unawaited(NotificationService.instance.cancelIncomingCall());
          await _cleanup();
          _emit('ended', error: 'تماس بی‌پاسخ ماند.');
        }
      });
      return;
    }
    if (id == null || id != _callId) return;
    if (type == 'answer' && _peer != null) {
      _ringTimeout?.cancel();
      await _peer!.setRemoteDescription(RTCSessionDescription(data['sdp']?.toString(), data['sdpType']?.toString() ?? 'answer'));
      _remoteDescriptionSet = true;
      _answered = true;
      await _flushCandidates();
      _emit('connecting');
      _startConnectionTimeout();
    } else if (type == 'candidate') {
      final candidate = RTCIceCandidate(
        data['candidate']?.toString(),
        data['sdpMid']?.toString(),
        data['sdpMLineIndex'] is int ? data['sdpMLineIndex'] as int : int.tryParse(data['sdpMLineIndex']?.toString() ?? ''),
      );
      if (_peer == null || !_remoteDescriptionSet) {
        _queuedCandidates.add(candidate);
      } else {
        await _peer!.addCandidate(candidate);
      }
    } else if (type == 'hangup' || type == 'decline' || type == 'busy') {
      if (type == 'hangup' && data['missed'] == true && !_outgoing) {
        unawaited(NotificationService.instance.showMissedCall(callId: id, video: data['video'] == true || _video));
      }
      _ringTimeout?.cancel();
      unawaited(NotificationService.instance.cancelIncomingCall());
      await _cleanup();
      _emit('ended', error: type == 'busy' ? 'طرف مقابل در حال مکالمه است.' : null);
    }
  }

  Future<void> _flushCandidates() async {
    final pending = List<RTCIceCandidate>.from(_queuedCandidates);
    _queuedCandidates.clear();
    for (final candidate in pending) {
      await _peer?.addCandidate(candidate);
    }
  }

  Future<void> endCall({bool decline = false}) async {
    _ringTimeout?.cancel();
    unawaited(NotificationService.instance.cancelIncomingCall());
    if (_callId != null) {
      try { await CloudService.instance.sendCallSignal({'type': decline ? 'decline' : 'hangup', 'callId': _callId}); } catch (_) {}
    }
    await _cleanup();
    _emit('ended');
  }

  Future<void> _cleanup() async {
    _ringTimeout?.cancel();
    _connectTimeout?.cancel();
    _disconnectTimeout?.cancel();
    try { await _peer?.close(); } catch (_) {}
    _peer = null;
    for (final track in _local?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    try { await _local?.dispose(); } catch (_) {}
    _local = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _callId = null;
    _remoteDescriptionSet = false;
    _queuedCandidates.clear();
    _localCandidatesBeforeOffer.clear();
    _offerSent = false;
    _offer = null;
    _muted = false;
    _cameraEnabled = true;
    _speakerOn = true;
    _activeSince = null;
  }

  Future<void> dispose() async {
    await _signals?.cancel();
    await endCall();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    await _states.close();
    _ready = false;
  }
}
