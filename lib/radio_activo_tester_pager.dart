import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum DetectorMode {
  manual,
  proximity,
  orientation,
}

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
      await _player.play(
        AssetSource('sounds/geiger.mp3'),
        volume: _volume,
      );
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
      const SnackBar(content: Text('Posición de prueba guardada')),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _proximitySub?.cancel();
    _accelSub?.cancel();
    super.dispose();
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
          return 'Guarde una posición para activar la prueba';
        }
        return _isInSavedOrientation()
            ? 'Posición CRÍTICA: ¡Radioactivo! ☢️'
            : 'Fuera de posición: sin riesgo aparente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Detector de Radiación',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

          
              ToggleButtons(
                isSelected: [
                  _mode == DetectorMode.manual,
                  _mode == DetectorMode.proximity,
                  _mode == DetectorMode.orientation,
                ],
                onPressed: (index) {
                  _changeMode(DetectorMode.values[index]);
                },
                borderRadius: BorderRadius.circular(12),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Manual'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Proximidad'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Posición'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

             
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LinearProgressIndicator(
                  value: _volume,
                  minHeight: 14,
                ),
              ),
              const SizedBox(height: 12),
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

              const SizedBox(height: 24),

           
              if (_mode == DetectorMode.manual) ...[
                const Text(
                  'Ajuste de sensibilidad (secreto)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Slider(
                  value: _volume,
                  onChanged: (v) => _setVolume(v),
                  min: 0,
                  max: 1,
                ),
              ] else if (_mode == DetectorMode.proximity) ...[
                const Text(
                  'Modo proximidad: acerque el teléfono a la persona',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isNear ? 'Detectando MUY cerca...' : 'Lejos...',
                  style: const TextStyle(color: Colors.white),
                ),
              ] else if (_mode == DetectorMode.orientation) ...[
                const Text(
                  'Modo posición: coloque el cel como quiera y guarde la posición.\n'
                  'Solo sonará cuando el cel esté igual.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saveCurrentOrientation,
                  child: const Text('Guardar posición de prueba'),
                ),
                const SizedBox(height: 8),
                Text(
                  _savedOrientation == null
                      ? 'Ninguna posición guardada todavía'
                      : 'Posición guardada',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
