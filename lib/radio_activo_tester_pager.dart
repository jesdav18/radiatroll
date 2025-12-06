import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:radiatroll/detector_settings_page.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:vibration/vibration.dart';

enum DetectorMode { manual, proximity, orientation }

enum MotionRadiationState { idle, active, fading }

class RadioactivoTesterPage extends StatefulWidget {
  const RadioactivoTesterPage({super.key});

  @override
  State<RadioactivoTesterPage> createState() => _RadioactivoTesterPageState();
}

class _RadioactivoTesterPageState extends State<RadioactivoTesterPage> {
  final AudioPlayer _player = AudioPlayer();
  final VolumeController _volumeController = VolumeController();

  bool _isPlaying = false;

  double _volume = 1.0;

  double _systemVolume = 1.0;

  DetectorMode _mode = DetectorMode.manual;

  StreamSubscription<int>? _proximitySub;
  bool _isNear = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  AccelerometerEvent? _currentAccel;
  AccelerometerEvent? _prevAccel;
  AccelerometerEvent? _savedOrientation;

  final double _orientationThreshold = 2.0;

  MotionRadiationState _motionState = MotionRadiationState.idle;
  Timer? _fadeTimer;
  DateTime? _lastMotionTime;
  final double _motionThreshold = 4.0;

  bool _lastRadiation = false;

  bool get _radiationActive {
    if (_systemVolume <= 0.01) return false;

    switch (_mode) {
      case DetectorMode.manual:
        return _isPlaying;

      case DetectorMode.proximity:
        return _motionState != MotionRadiationState.idle;

      case DetectorMode.orientation:
        return _savedOrientation != null && _isInSavedOrientation();
    }
  }

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);

    _volumeController.getVolume().then((v) {
      setState(() => _systemVolume = v);
    });

    _volumeController.listener((v) {
      setState(() => _systemVolume = v);
    });

    _initProximity();
    _initAccelerometer();
  }

  void _initProximity() {
    _proximitySub = ProximitySensor.events.listen((int event) {
      setState(() => _isNear = event > 0);
      _applyModeLogic();
    });
  }

  void _initAccelerometer() {
    _accelSub = accelerometerEventStream().listen((event) {
      _prevAccel = _currentAccel;
      _currentAccel = event;

      if (_mode == DetectorMode.proximity && _prevAccel != null) {
        final dx = event.x - _prevAccel!.x;
        final dy = event.y - _prevAccel!.y;
        final dz = event.z - _prevAccel!.z;

        final delta = sqrt(dx * dx + dy * dy + dz * dz);

        if (delta > _motionThreshold) {
          _onMotionPulse();
        }
      }

      _applyModeLogic();
    });
  }

  void _onMotionPulse() {
    final now = DateTime.now();

    if (_lastMotionTime != null &&
        now.difference(_lastMotionTime!).inMilliseconds < 400) {
      return;
    }

    _lastMotionTime = now;
    _fadeTimer?.cancel();

    if (_motionState == MotionRadiationState.idle ||
        _motionState == MotionRadiationState.fading) {
      _motionState = MotionRadiationState.active;
      _setVolume(1.0);
    } else {
      _motionState = MotionRadiationState.fading;

      _fadeTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
        if (_volume <= 0.05) {
          _setVolume(0.0);
          _motionState = MotionRadiationState.idle;
          t.cancel();
        } else {
          _setVolume((_volume - 0.1).clamp(0.0, 1.0));
        }
      });
    }

    setState(() {});
  }

  bool _isInSavedOrientation() {
    if (_savedOrientation == null || _currentAccel == null) return false;

    final dx = (_savedOrientation!.x - _currentAccel!.x).abs();
    final dy = (_savedOrientation!.y - _currentAccel!.y).abs();
    final dz = (_savedOrientation!.z - _currentAccel!.z).abs();

    return dx < _orientationThreshold &&
        dy < _orientationThreshold &&
        dz < _orientationThreshold;
  }

  Future<void> _setPlaying(bool value) async {
    if (value == _isPlaying) return;
    if (value) {
      await _player.play(
        AssetSource('sounds/geiger.mp3'),
        volume: _volume,
      );
      setState(() => _isPlaying = true);
    } else {
      await _player.pause();
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    if (mounted) setState(() {});
  }

  void _changeMode(DetectorMode mode) {
    setState(() => _mode = mode);
    _applyModeLogic();
  }

  void _applyModeLogic() {
    if (!_isPlaying) return;

    switch (_mode) {
      case DetectorMode.manual:
        break;

      case DetectorMode.proximity:
        break;

      case DetectorMode.orientation:
        if (_isInSavedOrientation()) {
          _setVolume(1.0);
        } else {
          _setVolume(0.0);
        }
        break;
    }
  }

  void _saveCurrentOrientation() {
    if (_currentAccel == null) return;
    setState(() => _savedOrientation = _currentAccel);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Posición guardada')));
  }

  void _clearOrientation() {
    setState(() => _savedOrientation = null);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetectorSettingsPage(
          mode: _mode,
          manualVolume: _volume,
          hasSavedOrientation: _savedOrientation != null,
          isNear: _isNear,
          onModeChanged: _changeMode,
          onManualVolumeChanged: _setVolume,
          onSaveOrientation: _saveCurrentOrientation,
          onClearOrientation: _clearOrientation,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _proximitySub?.cancel();
    _accelSub?.cancel();
    _fadeTimer?.cancel();
    _volumeController.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radiation = _radiationActive;
    if (radiation && !_lastRadiation) {
      Vibration.hasVibrator().then((has) {
        if (has == true) {
          Vibration.vibrate(duration: 80);
        }
      });
    }
    _lastRadiation = radiation;

    final meterAsset = radiation
        ? 'assets/images/radiacion_activa.png'
        : 'assets/images/sin_radiacion.png';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('RadiaTroll'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 220,
                  child: Image.asset(meterAsset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 32),
                Transform.scale(
                  scale: 1.6,
                  child: Switch.adaptive(
                    value: _isPlaying,
                    onChanged: (v) => _setPlaying(v),
                    activeThumbColor: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
