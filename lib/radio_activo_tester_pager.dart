import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:radiatroll/detector_settings_page.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum DetectorMode { manual, proximity, orientation }

class RadioactivoTesterPage extends StatefulWidget {
  const RadioactivoTesterPage({super.key});

  @override
  State<RadioactivoTesterPage> createState() => _RadioactivoTesterPageState();
}

class _RadioactivoTesterPageState extends State<RadioactivoTesterPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _volume = 0.0;

  DetectorMode _mode = DetectorMode.manual;

  StreamSubscription<int>? _proximitySub;
  bool _isNear = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  AccelerometerEvent? _currentAccel;
  AccelerometerEvent? _savedOrientation;

  final double _orientationThreshold = 2.0;

  bool get _radiationActive {
    switch (_mode) {
      case DetectorMode.manual:
        return _volume > 0.4;

      case DetectorMode.proximity:
        return _isNear;

      case DetectorMode.orientation:
        return _isInSavedOrientation();
    }
  }

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);

    _initProximity();
    _initAccelerometer();
  }

  void _initProximity() {
    _proximitySub = ProximitySensor.events.listen((int event) {
      setState(() {
        _isNear = (event > 0);
      });
      _applyModeLogic();
    });
  }

  void _initAccelerometer() {
    _accelSub = accelerometerEventStream().listen((event) {
      _currentAccel = event;
      _applyModeLogic();
    });
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

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(AssetSource('sounds/geiger.mp3'), volume: _volume);
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    setState(() {});
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
        if (_isNear) {
          _setVolume(1.0);
        } else {
          _setVolume(0.1);
        }
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
    setState(() {
      _savedOrientation = _currentAccel;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Posición de prueba guardada (puedes actualizarla cuando quieras)',
        ),
      ),
    );
  }

  void _clearOrientation() {
    setState(() {
      _savedOrientation = null;
    });
  }

  String _statusText() {
    if (!_isPlaying) return 'Presione "Hacer prueba" para iniciar';

    switch (_mode) {
      case DetectorMode.manual:
        if (_volume == 0) return 'Nivel seguro';
        if (_volume < 0.4) return 'Exposición leve';
        if (_volume < 0.8) return 'PELIGRO';
        return '¡CRÍTICO! ANDA RADIOACTIVO';

      case DetectorMode.proximity:
        return _isNear ? 'MUY CERCA: Contaminado ☢️' : 'Lejos: Nivel bajo';

      case DetectorMode.orientation:
        if (_savedOrientation == null) {
          return 'Sin posición guardada: vaya a configuración para guardar una.';
        }
        return _isInSavedOrientation()
            ? 'Posición CRÍTICA: ¡Radioactivo! ☢️'
            : 'Fuera de posición: sin riesgo aparente';
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetectorSettingsPage(
          mode: _mode,
          manualVolume: _volume,
          hasSavedOrientation: _savedOrientation != null,
          isNear: _isNear,
          onModeChanged: (m) {
            _changeMode(m);
          },
          onManualVolumeChanged: (v) async {
            await _setVolume(v);
          },
          onSaveOrientation: () {
            _saveCurrentOrientation();
          },
          onClearOrientation: () {
            _clearOrientation();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _proximitySub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meterAsset = _radiationActive
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
                const SizedBox(height: 24),
                Text(
                  _statusText(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _togglePlay,
                  child: Text(_isPlaying ? 'Detener prueba' : 'Hacer prueba'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
