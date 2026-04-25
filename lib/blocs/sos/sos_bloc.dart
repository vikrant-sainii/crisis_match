import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import '../../repositories/help_request_repository.dart';
import '../../repositories/low_network_repository.dart';
import '../../services/sos_foreground_service.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final HelpRequestRepository _repository;
  final LowNetworkRepository _lowNetworkRepo;
  final String victimId;

  late stt.SpeechToText _speech;
  Timer? _silenceTimer;
  Timer? _failsafeTimer;
  Timer? _offlineAutoSendTimer;
  String _capturedMessage = '';

  static const _channel = MethodChannel('com.crismatch.sos/trigger');

  SosBloc({
    required HelpRequestRepository repository,
    required LowNetworkRepository lowNetworkRepo,
    required this.victimId,
  })  : _repository = repository,
        _lowNetworkRepo = lowNetworkRepo,
        super(SosDisabled()) {
    _speech = stt.SpeechToText();

    on<EnableSos>(_onEnableSos);
    on<DisableSos>(_onDisableSos);
    on<StartSosCapture>(_onStartSosCapture);
    on<SelectWomanSafetyAction>(_onSelectWomanSafetyAction);
    on<SelectVoiceAssistAction>(_onSelectVoiceAssistAction);
    on<DistressCaptured>(_onDistressCaptured);
    on<SubmitOfflineSos>(_onSubmitOfflineSos);
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
        add(StartSosCapture());
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

  Future<void> _onStartSosCapture(
      StartSosCapture event, Emitter<SosState> emit) async {
    developer.log('SosBloc: _onStartSosCapture — Checking connectivity...');

    emit(SosActivated());
    SystemSound.play(SystemSoundType.click);

    // 1. Connectivity Check
    final isOnline = await _lowNetworkRepo.hasInternet();
    
    // 2. Fetch Location INSTANTLY using cache
    Position? pos;
    try {
      // Pull from cache - takes 0 seconds
      pos = await Geolocator.getLastKnownPosition();
      
      // If cache is empty, do a very fast low-accuracy check
      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 1),
        );
      }

    } catch (e) {
      developer.log('SosBloc: GPS retrieval error: $e');
    }

    if (!isOnline) {
      developer.log('SosBloc: LOW NETWORK detected. Switching to Offline SOS flow.');
      
      // Always show offline UI so victim can at least send SMS
      emit(SosOfflineInputPending(
        lat: pos?.latitude ?? 0.0, 
        lon: pos?.longitude ?? 0.0
      ));
      
      _offlineAutoSendTimer?.cancel();
      _offlineAutoSendTimer = Timer(const Duration(seconds: 10), () {
        if (state is SosOfflineInputPending) {
           add(const SubmitOfflineSos("Emergency SOS (Auto-Sent)", "high"));
        }
      });
      return;
    }

    // 3. Choice Screen (Online)
    // ALWAYS show the choice screen so the victim can proceed instantly.
    // Even if pos is null, we show the UI with 0.0 fallback.
    emit(SosAwaitingAction(
      lat: pos?.latitude ?? 0.0, 
      lon: pos?.longitude ?? 0.0
    ));
  }

  Future<void> _onSelectWomanSafetyAction(
      SelectWomanSafetyAction event, Emitter<SosState> emit) async {
    emit(const SosCaptured("women safety sos"));
    
    try {
      // Trigger the dedicated Women Safety SOS webhook
      await _repository.triggerWomenSafetySos(
        victimId: victimId,
        lat: event.lat,
        lng: event.lon,
      );
      
      // Hand off to captured state to trigger HelpRequest tracking
      emit(const SosCaptured("women safety sos"));
    } catch (e) {
      developer.log('SosBloc: Woman Safety Alert failed: $e');
      emit(SosError('Woman Safety Alert failed: $e'));
    }
  }

  Future<void> _onSelectVoiceAssistAction(
      SelectVoiceAssistAction event, Emitter<SosState> emit) async {
    if (state is! SosAwaitingAction) return;
    final currentState = state as SosAwaitingAction;
    final lat = currentState.lat;
    final lon = currentState.lon;

    developer.log('SosBloc: Voice Assist Selected. Starting Phase 2...');
    
    // Call n8n TTS: "You can speak now. Describe your emergency."
    try {
      final ttsPath = await _repository.triggerTTS(
          "You can speak now. Describe your emergency.");
      
      if (ttsPath != null) {
        final player = AudioPlayer();
        await player.play(DeviceFileSource(ttsPath));
        await player.onPlayerComplete.first
            .timeout(const Duration(seconds: 5), onTimeout: () {});
        await player.dispose();
      }
    } catch (e) {
      developer.log('SosBloc: TTS playback error: $e');
    }

    // Start STT recording
    await _startPhase2(emit);
  }

  Future<void> _onSubmitOfflineSos(
      SubmitOfflineSos event, Emitter<SosState> emit) async {
    _offlineAutoSendTimer?.cancel();
    
    double lat = event.lat ?? 0.0;
    double lon = event.lon ?? 0.0;

    // If event didn't provide lat/lon, try to get from state
    if (lat == 0.0 && lon == 0.0 && state is SosOfflineInputPending) {
      lat = (state as SosOfflineInputPending).lat;
      lon = (state as SosOfflineInputPending).lon;
    }

    emit(const SosOfflineSuccess("Sending..."));

    try {
      final body = _lowNetworkRepo.formatSosMessage(
        victimId: victimId,
        lat: lat,
        lng: lon,
        message: event.message,
        priority: event.priority,
      );
      
      await _lowNetworkRepo.sendEmergencySms(body);
      emit(SosOfflineSuccess(LowNetworkRepository.emergencyNumber));
      
      // Reset after success
      await Future.delayed(const Duration(seconds: 3));
      emit(SosDisabled());
    } catch (e) {
      developer.log('SosBloc: Offline SOS failed: $e');
      emit(SosError('Failed to send offline SOS: $e'));
    }
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
    _failsafeTimer = Timer(const Duration(seconds: 10), () {
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
    developer.log('SosBloc: Distress message captured: "${event.message}"');
    
    // Terminal state for this Bloc — signal UI to hand off to HelpRequestBloc
    emit(SosCaptured(event.message));
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
