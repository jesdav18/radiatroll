import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:radiatroll/radio_activo_tester_pager.dart';

class DetectorSettingsPage extends StatefulWidget {
  final DetectorMode mode;
  final double manualVolume;
  final bool hasSavedOrientation;
  final bool isNear;

  final ValueChanged<DetectorMode> onModeChanged;
  final ValueChanged<double> onManualVolumeChanged;
  final VoidCallback onSaveOrientation;
  final VoidCallback onClearOrientation;

  const DetectorSettingsPage({
    super.key,
    required this.mode,
    required this.manualVolume,
    required this.hasSavedOrientation,
    required this.isNear,
    required this.onModeChanged,
    required this.onManualVolumeChanged,
    required this.onSaveOrientation,
    required this.onClearOrientation,
  });

  @override
  State<DetectorSettingsPage> createState() => _DetectorSettingsPageState();
}

class _DetectorSettingsPageState extends State<DetectorSettingsPage> {
  late DetectorMode _localMode;
  late double _localManualVolume;
  late bool _localHasSavedOrientation;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _localMode = widget.mode;
    _localManualVolume = widget.manualVolume;
    _localHasSavedOrientation = widget.hasSavedOrientation;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  void _updateMode(DetectorMode mode) {
    setState(() => _localMode = mode);
    widget.onModeChanged(mode);
  }

  void _updateManualVolume(double v) {
    setState(() => _localManualVolume = v);
    widget.onManualVolumeChanged(v);
  }

  void _handleSaveOrientation() {
    widget.onSaveOrientation();
    setState(() => _localHasSavedOrientation = true);
  }

  void _handleClearOrientation() {
    widget.onClearOrientation();
    setState(() => _localHasSavedOrientation = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'App de broma. No es un medidor real de radiación.',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Modo de detección',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioGroup<DetectorMode>(
            groupValue: _localMode,
            onChanged: (v) {
              if (v != null) _updateMode(v);
            },
            child: Column(
              children: [
                RadioListTile<DetectorMode>(
                  value: DetectorMode.manual,
                  activeColor: Colors.greenAccent,
                  title: const Text('Manual', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Controlas el nivel con un volumen fijo.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                RadioListTile<DetectorMode>(
                  value: DetectorMode.proximity,
                  activeColor: Colors.greenAccent,
                  title: const Text('Proximidad (Experimental)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Más cerca = más ruido. Más lejos = menos.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                RadioListTile<DetectorMode>(
                  value: DetectorMode.orientation,
                  activeColor: Colors.greenAccent,
                  title: const Text('Posición', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Solo suena cuando el teléfono está en la posición guardada.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_localMode == DetectorMode.manual) ...[
            const Text(
              'Volumen (modo manual)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _localManualVolume,
              onChanged: _updateManualVolume,
              min: 0,
              max: 1,
            ),
            Text(
              'Nivel: ${(_localManualVolume * 100).round()}%',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
          ],
          if (_localMode == DetectorMode.proximity) ...[
            const Text(
              'Estado de proximidad',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isNear ? 'Actualmente: CERCA' : 'Actualmente: LEJOS',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
          ],
          if (_localMode == DetectorMode.orientation) ...[
            const Text(
              'Configuración de posición',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coloca el celular en la posición que quieras usar para la prueba '
              '(por ejemplo, apuntando al pecho de una persona) y presiona:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _handleSaveOrientation,
                  child: Text(
                    _localHasSavedOrientation
                        ? 'Actualizar posición'
                        : 'Guardar posición',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _localHasSavedOrientation ? _handleClearOrientation : null,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _localHasSavedOrientation
                  ? 'Posición guardada (puedes actualizarla cuando quieras)'
                  : 'No hay ninguna posición guardada.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 24),
          if (_version.isNotEmpty)
            Text(
              'RadiaTroll v$_version',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
