import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import '../../repositories/help_request_repository.dart';
import '../../services/sos_foreground_service.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final HelpRequestRepository _repository;
  final String victimId;

  late stt.SpeechToText _speech;
  Timer? _silenceTimer;
  Timer? _failsafeTimer;
  String _capturedMessage = '';

  static const _channel = MethodChannel('com.crismatch.sos/trigger');

  SosBloc({
    required HelpRequestRepository repository,
    required this.victimId,
  })  : _repository = repository,
        super(SosDisabled()) {
    _speech = stt.SpeechToText();

    on<EnableSos>(_onEnableSos);
    on<DisableSos>(_onDisableSos);
    on<SosPowerButtonTriggered>(_onPowerButtonTriggered);
    on<DistressCaptured>(_onDistressCaptured);
    on<SosResponseReceived>(_onSosResponseReceived);
    on<SensorDebugDataReceived>(_onSensorDebugDataReceived);
    on<SosLiveTextUpdated>((event, emit) {
      if (state is SosCapturing) {
        emit(SosCapturing(event.text));
      }
    });

    // Always listen to MethodChannel triggers, in case app was launched from a dead state
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sosTrigger') {
        developer.log('SosBloc: MethodChannel received "sosTrigger"!');
        add(SosPowerButtonTriggered());
      } else if (call.method == 'sensorDebug') {
        final data = call.arguments as Map<Object?, Object?>?;
        if (data != null) {
          final gZ = (data['gZ'] as num?)?.toDouble() ?? 0.0;
          final count = (data['count'] as num?)?.toInt() ?? 0;
          add(SensorDebugDataReceived(gZ, count));
        }
      }
    });
  }

  void _onSensorDebugDataReceived(
      SensorDebugDataReceived event, Emitter<SosState> emit) {
    if (state is SosListening) {
      emit(SosListening(gZ: event.gZ, shakeCount: event.count));
    }
  }

  Future<void> _onEnableSos(EnableSos event, Emitter<SosState> emit) async {
    try {
      // 1. Initialize speech engine for phase 2
      await _speech.initialize(
        onStatus: (s) => developer.log('SosBloc: STT status: $s'),
        onError: (e) => developer.log('SosBloc: STT error: ${e.errorMsg}'),
      );

      // 2. Start the Guardian notification via service
      await SosForegroundService.startService(
        wakeWord: 'press power 3x', // No longer used dynamically, just for logs
        victimId: victimId,
        onWakeWordDetected: () {},
      );

      emit(SosListening());
      developer.log('SosBloc: SOS Guardian enabled. Listening for shake triggers.');
    } catch (e) {
      developer.log('SosBloc: Failed to enable SOS: $e');
      emit(SosError('Failed to enable SOS: $e'));
    }
  }

  Future<void> _onDisableSos(DisableSos event, Emitter<SosState> emit) async {
    _silenceTimer?.cancel();
    _failsafeTimer?.cancel();
    try { _speech.stop(); } catch (_) {}
    await SosForegroundService.stopService();
    emit(SosDisabled());
    developer.log('SosBloc: SOS disabled');
  }

  Future<void> _onPowerButtonTriggered(
      SosPowerButtonTriggered event, Emitter<SosState> emit) async {
    developer.log('SosBloc: _onPowerButtonTriggered — Starting Phase 2 flow');

    emit(SosActivated());

    // 1. Play "ding" sound to signal trigger start
    SystemSound.play(SystemSoundType.click);

    // 2. Call n8n TTS: "You can speak now. Describe your emergency."
    try {
      final ttsPath = await _repository.triggerTTS(
          "You can speak now. Describe your emergency.");
      
      if (ttsPath != null) {
        final player = AudioPlayer();
        await player.play(DeviceFileSource(ttsPath));
        // Wait for the audio to finish (with 5s max timeout)
        await player.onPlayerComplete.first
            .timeout(const Duration(seconds: 5), onTimeout: () {});
        await player.dispose();
      }
    } catch (e) {
      developer.log('SosBloc: TTS playback error: $e');
      // Continue anyway
    }

    // 3. Start 8-second STT recording immediately after TTS
    await _startPhase2(emit);
  }

  Future<void> _startPhase2(Emitter<SosState> emit) async {
    developer.log('SosBloc: Starting Phase 2 — STT dynamic recording');

    _capturedMessage = '';
    emit(const SosCapturing(''));

    // Cancel old timers
    _silenceTimer?.cancel();
    _failsafeTimer?.cancel();

    // Ensure STT is mounted
    if (!_speech.isAvailable) {
      await _speech.initialize(
        onStatus: (s) => developer.log('SosBloc: STT status: $s'),
        onError: (e) => developer.log('SosBloc: STT error: ${e.errorMsg}'),
      );
    }

    _speech.listen(
      onResult: (result) {
        _capturedMessage = result.recognizedWords;
        developer.log('SosBloc: Capturing: "$_capturedMessage"');
        
        // Push the update to UI
        add(SosLiveTextUpdated(_capturedMessage));

        // 1.5 second rolling silence detection
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
          _endPhase2();
        });
      },
      listenFor: const Duration(seconds: 30),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );

    // 7-second absolute failsafe (in case they never speak at all or speech hangs)
    _failsafeTimer = Timer(const Duration(seconds: 7), () {
      _endPhase2();
    });
  }

  void _endPhase2() {
    _silenceTimer?.cancel();
    _failsafeTimer?.cancel();
    
    try {
      _speech.stop();
    } catch (_) {}

    SystemSound.play(SystemSoundType.click);

    final msg = _capturedMessage.trim().isNotEmpty
        ? _capturedMessage.trim()
        : 'Emergency SOS — no message captured';

    developer.log('SosBloc: Captured final: "$msg"');
    add(DistressCaptured(msg));
  }

  Future<void> _onDistressCaptured(
      DistressCaptured event, Emitter<SosState> emit) async {
    developer.log('SosBloc: Distress message: "${event.message}"');
    emit(SosSending(event.message));

    try {
      // Auto-grab GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final lat = position.latitude;
      final lng = position.longitude;

      developer.log('SosBloc: GPS: $lat, $lng');

      // Call BOTH existing webhooks in parallel
      final matcherFuture = _repository
          .triggerN8nInitialSearch(
        message: event.message,
        victimId: victimId,
        lat: lat,
        lng: lng,
      )
          .catchError((e) {
        developer.log('SosBloc: Matcher error: $e');
        return <String, dynamic>{'error': e.toString()};
      });

      final voiceFuture = _repository
          .triggerN8nVoiceAssist(
        message: event.message,
        victimId: victimId,
        lat: lat,
        lng: lng,
      )
          .catchError((e) {
        developer.log('SosBloc: Voice Assist error: $e');
        return <String, dynamic>{
          'reply': 'SOS received. Locating help nearby.',
          'audioPath': null,
        };
      });

      final results = await Future.wait([matcherFuture, voiceFuture]);
      final matcherResponse = results[0];
      final voiceResponse = results[1];

      // Build match data if a helper was found
      Map<String, dynamic>? matchData;
      if (matcherResponse.containsKey('matched_id') &&
          matcherResponse.containsKey('request_id')) {
        matchData = matcherResponse;
      }

      emit(SosResponseState(
        voiceReply: voiceResponse['reply'] ?? 'SOS received.',
        audioPath: voiceResponse['audioPath'] as String?,
        matchData: matchData,
      ));

      developer.log('SosBloc: SOS response emitted. Match: ${matchData != null}');
    } catch (e) {
      developer.log('SosBloc: SOS processing error: $e');
      emit(SosError('SOS sent but failed to process: $e'));
    }
  }

  void _onSosResponseReceived(
      SosResponseReceived event, Emitter<SosState> emit) {
    emit(SosResponseState(
      voiceReply: event.voiceReply ?? 'SOS processed.',
      audioPath: event.audioPath,
      matchData: event.matchData,
    ));
  }

  @override
  Future<void> close() {
    _silenceTimer?.cancel();
    _failsafeTimer?.cancel();
    try { _speech.stop(); } catch (_) {}
    _channel.setMethodCallHandler(null);
    SosForegroundService.stopService();
    return super.close();
  }
}
