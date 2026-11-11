import 'dart:async';

import 'package:flutter/material.dart';

import 'board/board_painter.dart';
import 'board/board_state.dart';
import 'gestures/inertial_gesture_detector.dart';
import 'gestures/touchless_gesture_detector.dart';
import 'hand_tracking/hand_tracker.dart';
import 'motion/motion_sensor.dart';
import 'ui/info_cards.dart';
import 'ui/motion_meters.dart';
import 'ui/nui.dart';

void main() => runApp(const PizarraApp());

class PizarraApp extends StatelessWidget {
  const PizarraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizarra de gestos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PizarraScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla principal
// ---------------------------------------------------------------------------

class PizarraScreen extends StatefulWidget {
  const PizarraScreen({super.key});

  @override
  State<PizarraScreen> createState() => _PizarraScreenState();
}

enum _TouchMode { none, draw, zoom }

class _PizarraScreenState extends State<PizarraScreen> {
  // Estado de la pizarra (compartido por los tres canales).
  final _board = BoardState();
  Stroke? _touchStroke;
  Stroke? _airStroke;
  double _scale = 1;
  Offset _offset = Offset.zero;
  int _version = 0;
  Size _boardSize = Size.zero;

  // Retroalimentación visual.
  final List<ActionEvent> _log = [];
  ActionEvent? _flash;
  Timer? _flashTimer;

  // Canal táctil: sesión de toque completa (desde el primer dedo hasta que
  // se levanta el último), seguida con el Listener de bajo nivel.
  _TouchMode _mode = _TouchMode.none;
  double _zoomBase = 1;
  Offset _zoomCanvasFocal = Offset.zero;
  final Map<int, Offset> _pointerStart = {};
  int _maxPointers = 0;
  bool _pointerMoved = false;
  Duration _sessionStart = Duration.zero;
  double _sessionStartScale = 1;
  bool _sessionHadMulti = false;

  // Canal touchless.
  final _handDetector = TouchlessGestureDetector();
  final _clock = Stopwatch()..start();
  bool _cameraOn = false;
  bool _cameraLoading = false;
  String? _cameraError;
  HandPose _pose = HandPose.none;
  double _pinchRatio = 0;
  Offset? _airCursor; // en coordenadas de la pizarra (pantalla)

  // Canal inercial (acelerómetro del mismo celular).
  final _motionDetector = InertialGestureDetector();
  final _motion = ValueNotifier(const MotionView());
  bool _sensorsOn = false;
  bool _sensorsLoading = false;
  String? _sensorsError;

  Color get _color => _board.color;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _motion.dispose();
    if (_cameraOn) HandTracker.stop();
    if (_sensorsOn) MotionSensor.stop();
    super.dispose();
  }

  // ===== FUNCIONES: las llaman igual los tres canales =====================

  void _commitStroke(Stroke s, Modality m) {
    if (!_board.commit(s)) return;
    _version++;
    _register(m, NuiFunction.draw, '${s.points.length} puntos');
  }

  void _changeColor(int delta, Modality m) {
    _board.changeColor(delta);
    _register(m, NuiFunction.color, _board.colorName);
  }

  void _undo(Modality m) {
    final done = _board.undo();
    if (done) _version++;
    _register(
      m,
      NuiFunction.undo,
      done ? 'Último cambio deshecho' : 'Nada que deshacer',
    );
  }

  void _clear(Modality m) {
    final done = _board.clear();
    if (done) _version++;
    _register(
      m,
      NuiFunction.clear,
      done ? 'Pizarra borrada' : 'La pizarra ya está vacía',
    );
  }

  void _register(Modality m, NuiFunction fn, String detail) {
    final e = ActionEvent(m, fn, detail);
    _flash = e;
    _log.insert(0, e);
    if (_log.length > 30) _log.removeLast();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  // ===== Coordenadas =======================================================

  Offset _toCanvas(Offset screen) => (screen - _offset) / _scale;

  Offset _clampOffset(Offset o, double s) => Offset(
    o.dx.clamp(_boardSize.width * (1 - s), 0.0),
    o.dy.clamp(_boardSize.height * (1 - s), 0.0),
  );

  // ===== CANAL 1: TÁCTIL ===================================================

  // Listener de bajo nivel: ve todos los PointerEvent crudos, sin pasar por
  // la Gesture Arena. Flutter no trae "toque con dos dedos", así que aquí se
  // detecta a mano, y se cierra la sesión cuando se levanta el último dedo.

  void _onPointerDown(PointerDownEvent e) {
    if (_pointerStart.isEmpty) {
      _maxPointers = 0;
      _pointerMoved = false;
      _sessionHadMulti = false;
      _sessionStart = _clock.elapsed;
      _sessionStartScale = _scale;
    }
    _pointerStart[e.pointer] = e.localPosition;
    if (_pointerStart.length > _maxPointers) {
      _maxPointers = _pointerStart.length;
    }
    if (_pointerStart.length >= 2) _sessionHadMulti = true;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _pointerStart[e.pointer];
    if (start != null && (e.localPosition - start).distance > 20) {
      _pointerMoved = true;
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointerStart.remove(e.pointer);
    if (_pointerStart.isNotEmpty) return;
    // Se levantó el último dedo. El Listener recibe el evento ANTES que los
    // reconocedores del GestureDetector (que se enteran al final, por el
    // router del GestureBinding), así que se espera a que terminen.
    scheduleMicrotask(_endTouchSession);
  }

  void _endTouchSession() {
    if (!mounted || _pointerStart.isNotEmpty) return;
    final elapsed = _clock.elapsed - _sessionStart;
    final zoomChanged = (_scale - _sessionStartScale).abs() > 0.05;
    setState(() {
      if (_maxPointers == 2 &&
          !_pointerMoved &&
          !zoomChanged &&
          elapsed < const Duration(milliseconds: 350)) {
        _undo(Modality.touch);
      } else if (_sessionHadMulti && zoomChanged) {
        _register(
          Modality.touch,
          NuiFunction.zoom,
          'Zoom ×${_scale.toStringAsFixed(1)}',
        );
      }
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _startZoom(d.localFocalPoint);
      } else if (!_sessionHadMulti) {
        // Un dedo: empieza un trazo.
        _mode = _TouchMode.draw;
        _touchStroke = Stroke(_color)..points.add(_toCanvas(d.localFocalPoint));
        _version++;
      } else {
        // Quedó un dedo después de un pellizco: no dibujar.
        _mode = _TouchMode.none;
      }
    });
  }

  void _startZoom(Offset focal) {
    _mode = _TouchMode.zoom;
    _zoomBase = _scale;
    _zoomCanvasFocal = _toCanvas(focal);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      switch (_mode) {
        case _TouchMode.draw:
          final p = _toCanvas(d.localFocalPoint);
          final pts = _touchStroke!.points;
          if ((p - pts.last).distance > 1.5 / _scale) pts.add(p);
          _version++;
        case _TouchMode.zoom:
          // Pellizco: escala continua sobre el punto focal (FSM: Changed).
          final s = (_zoomBase * d.scale).clamp(1.0, 4.0);
          _scale = s;
          _offset = _clampOffset(d.localFocalPoint - _zoomCanvasFocal * s, s);
        case _TouchMode.none:
          break;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() {
      if (_mode == _TouchMode.draw && _touchStroke != null) {
        final s = _touchStroke!;
        _touchStroke = null;
        // Si llegó un segundo dedo, el trazo corto era el inicio de un
        // pellizco: se descarta.
        final interrupted = d.pointerCount >= 2;
        if (!interrupted || s.points.length >= 12) {
          _commitStroke(s, Modality.touch);
        }
        _version++;
      }
      _mode = _TouchMode.none;
    });
  }

  // ===== CANAL 3: TOUCHLESS (cámara) =======================================

  Future<void> _toggleCamera() async {
    if (_cameraOn) {
      HandTracker.stop();
      setState(() {
        _cameraOn = false;
        _airCursor = null;
        _pose = HandPose.none;
        _finishAirStroke();
      });
      _handDetector.reset();
      return;
    }
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });
    final error = await HandTracker.start(_onHandFrame);
    if (!mounted) return;
    setState(() {
      _cameraLoading = false;
      _cameraOn = error == null;
      _cameraError = error;
    });
  }

  /// La mano rara vez llega a las orillas del encuadre: se amplía la zona
  /// central de la cámara para alcanzar toda la pizarra.
  Offset _cameraToBoard(Offset p) => Offset(
    ((p.dx - 0.15) / 0.7).clamp(0.0, 1.0) * _boardSize.width,
    ((p.dy - 0.15) / 0.7).clamp(0.0, 1.0) * _boardSize.height,
  );

  void _finishAirStroke() {
    final s = _airStroke;
    _airStroke = null;
    if (s != null) {
      _commitStroke(s, Modality.touchless);
      _version++;
    }
  }

  /// Se llama en cada frame de la cámara con los 21 landmarks (o null).
  void _onHandFrame(List<Point3D>? hand, double aspect) {
    if (!mounted || !_cameraOn) return;
    final r = _handDetector.process(
      hand,
      timestamp: _clock.elapsed,
      aspect: aspect,
    );

    setState(() {
      _pose = r.pose;
      _pinchRatio = r.pinchRatio;

      // Cursor = punta del índice (landmark 8), suavizado contra el temblor.
      final showCursor =
          r.indexTip != null &&
          (r.pose == HandPose.pointing || r.pose == HandPose.pinch);
      if (showCursor) {
        final target = _cameraToBoard(r.indexTip!);
        _airCursor = _airCursor == null
            ? target
            : Offset.lerp(_airCursor, target, 0.45);
      } else {
        _airCursor = null;
      }

      // Air pinch sostenido = lápiz abajo.
      if (r.pose == HandPose.pinch && _airCursor != null) {
        final p = _toCanvas(_airCursor!);
        if (_airStroke == null) {
          _airStroke = Stroke(_color)..points.add(p);
        } else if ((p - _airStroke!.points.last).distance > 2 / _scale) {
          _airStroke!.points.add(p);
        }
        _version++;
      } else if (_airStroke != null) {
        _finishAirStroke();
      }

      for (final e in r.events) {
        switch (e) {
          case TouchlessEvent.swipeLeft:
            _changeColor(1, Modality.touchless);
          case TouchlessEvent.swipeRight:
            _changeColor(-1, Modality.touchless);
          case TouchlessEvent.victory:
            _undo(Modality.touchless);
          case TouchlessEvent.fist:
            _clear(Modality.touchless);
          case TouchlessEvent.pinch:
            break; // el pinch se usa de forma continua para dibujar
        }
      }
    });
  }

  // ===== CANAL 2: INERCIAL (acelerómetro del celular) ======================

  Future<void> _toggleSensors() async {
    if (_sensorsOn) {
      MotionSensor.stop();
      _motionDetector.reset();
      _motion.value = const MotionView();
      setState(() => _sensorsOn = false);
      return;
    }
    setState(() {
      _sensorsLoading = true;
      _sensorsError = null;
    });
    final error = await MotionSensor.start(_onMotionSample);
    if (!mounted) return;
    setState(() {
      _sensorsLoading = false;
      _sensorsOn = error == null;
      _sensorsError = error;
    });
  }

  /// Se llama con cada lectura de la IMU (~60 veces por segundo).
  void _onMotionSample(MotionSample sample) {
    if (!mounted || !_sensorsOn) return;
    final r = _motionDetector.process(sample, _clock.elapsed);
    _motion.value = MotionView(
      magnitude: r.magnitude,
      gamma: r.gamma,
      faceDown: r.faceDown,
    );
    if (r.events.isEmpty) return;
    setState(() {
      for (final e in r.events) {
        switch (e) {
          case InertialEvent.shake:
            _undo(Modality.inertial);
          case InertialEvent.tiltRight:
            _changeColor(1, Modality.inertial);
          case InertialEvent.tiltLeft:
            _changeColor(-1, Modality.inertial);
          case InertialEvent.faceDown:
            _clear(Modality.inertial);
        }
      }
    });
  }

  // ================================== UI ===================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 800 && c.maxWidth > c.maxHeight;
            if (wide) {
              final panelWidth = (c.maxWidth * 0.3).clamp(300.0, 420.0);
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildBoard(),
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      children: _buildPanel(),
                    ),
                  ),
                ],
              );
            }
            // Celular: la pizarra ocupa casi toda la pantalla (no va dentro
            // de una lista, así arrastrar el dedo dibuja en vez de
            // desplazar). La cámara se ve en miniatura sobre la pizarra y
            // los controles van en una barra abajo.
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: _buildBoard(compact: true),
                  ),
                ),
                _buildPhoneBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== Barra inferior del celular ========================================

  Widget _buildPhoneBar() {
    final theme = Theme.of(context);
    final error = _cameraError ?? _sensorsError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          if (_sensorsOn)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ValueListenableBuilder<MotionView>(
                valueListenable: _motion,
                builder: (context, m, _) =>
                    MotionStrip(m, threshold: _motionDetector.shakeThreshold),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _channelButton(
                  key: const ValueKey('cameraButton'),
                  modality: Modality.touchless,
                  on: _cameraOn,
                  loading: _cameraLoading,
                  label: _cameraOn ? _pose.label : 'Cámara',
                  onPressed: _toggleCamera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _channelButton(
                  key: const ValueKey('sensorsButton'),
                  modality: Modality.inertial,
                  on: _sensorsOn,
                  loading: _sensorsLoading,
                  label: _sensorsOn ? 'Sensores activos' : 'Sensores',
                  onPressed: _toggleSensors,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Gestos y registro',
                onPressed: _showInfoSheet,
                icon: const Icon(Icons.menu_book),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _channelButton({
    required Key key,
    required Modality modality,
    required bool on,
    required bool loading,
    required String label,
    required VoidCallback onPressed,
  }) {
    final style = FilledButton.styleFrom(
      backgroundColor: on ? modality.color : null,
      foregroundColor: on ? Colors.black : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    );
    return FilledButton.tonalIcon(
      key: key,
      style: style,
      onPressed: loading ? null : onPressed,
      icon: Icon(modality.icon, size: 20),
      label: Text(
        loading ? 'Cargando…' : label,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            GestureMap(active: _flash),
            const SizedBox(height: 12),
            EventLog(_log),
          ],
        ),
      ),
    );
  }

  /// Miniatura de la cámara (con el esqueleto de la mano) sobre la pizarra.
  Widget _buildCameraPip() {
    return IgnorePointer(
      child: Container(
        width: 108,
        height: 144,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Modality.touchless.color, width: 2),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: HandTracker.preview(),
      ),
    );
  }

  Widget _buildBoard({bool compact = false}) {
    return LayoutBuilder(
      builder: (context, c) {
        _boardSize = c.biggest;
        final drawing = [..._board.strokes, ?_touchStroke, ?_airStroke];
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: const Color(0xFF1B1F2E),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: GestureDetector(
                key: const ValueKey('board'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onDoubleTap: () =>
                    setState(() => _changeColor(1, Modality.touch)),
                onLongPress: () => setState(() => _clear(Modality.touch)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: BoardPainter(
                        strokes: drawing,
                        scale: _scale,
                        offset: _offset,
                        version: _version,
                      ),
                    ),
                    if (drawing.isEmpty)
                      IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              compact
                                  ? 'Dibuja con el dedo,\n'
                                        'o junta pulgar e índice frente a la '
                                        'cámara'
                                  : 'Dibuja con el dedo o el mouse,\n'
                                        'o junta pulgar e índice frente a la '
                                        'cámara',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (compact && _cameraOn)
                      Positioned(right: 8, top: 8, child: _buildCameraPip()),
                    if (_airCursor case final p?) _buildAirCursor(p),
                    Positioned(left: 10, top: 10, child: _buildStatusChip()),
                    Positioned(
                      top: compact ? null : 52,
                      bottom: compact ? 12 : null,
                      left: 8,
                      right: 8,
                      child: Center(child: FlashBanner(_flash)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAirCursor(Offset p) {
    final drawing = _airStroke != null;
    const size = 26.0;
    return Positioned(
      left: p.dx - size / 2,
      top: p.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: drawing ? _color : Colors.transparent,
            border: Border.all(color: _color, width: 3),
            boxShadow: [
              BoxShadow(color: _color.withValues(alpha: 0.6), blurRadius: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _board.colorName,
            key: const ValueKey('colorName'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_scale > 1.01) ...[
            const SizedBox(width: 12),
            Text(
              '×${_scale.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPanel() {
    return [
      _buildCameraCard(),
      const SizedBox(height: 12),
      _buildPhoneCard(),
      const SizedBox(height: 12),
      GestureMap(active: _flash),
      const SizedBox(height: 12),
      EventLog(_log),
    ];
  }

  Widget _cardTitle(
    IconData icon,
    String text,
    Color color, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildCameraCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle(
              Icons.videocam,
              'Cámara · touchless',
              Modality.touchless.color,
              trailing: FilledButton.tonal(
                onPressed: _cameraLoading ? null : _toggleCamera,
                child: Text(
                  _cameraLoading
                      ? 'Cargando…'
                      : _cameraOn
                      ? 'Apagar'
                      : 'Activar',
                ),
              ),
            ),
            if (_cameraError != null) ...[
              const SizedBox(height: 8),
              Text(
                _cameraError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_cameraOn) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: HandTracker.preview(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.back_hand, size: 16),
                    label: Text(_pose.label),
                  ),
                  const Spacer(),
                  if (_pose != HandPose.none)
                    Text(
                      'pulgar↔índice: ${_pinchRatio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _pinchRatio < _handDetector.pinchThreshold
                            ? Colors.greenAccent
                            : Colors.white60,
                      ),
                    ),
                ],
              ),
            ] else if (!_cameraLoading && _cameraError == null) ...[
              const SizedBox(height: 6),
              Text(
                'Activa la cámara y pon la mano frente a ella, con la palma '
                'mirando a la pantalla.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle(
              Icons.screen_rotation,
              'Sensores · inercial',
              Modality.inertial.color,
              trailing: FilledButton.tonal(
                onPressed: _sensorsLoading ? null : _toggleSensors,
                child: Text(
                  _sensorsLoading
                      ? 'Cargando…'
                      : _sensorsOn
                      ? 'Apagar'
                      : 'Activar',
                ),
              ),
            ),
            if (_sensorsError != null) ...[
              const SizedBox(height: 8),
              Text(
                _sensorsError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_sensorsOn) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<MotionView>(
                valueListenable: _motion,
                builder: (context, m, _) =>
                    MotionMeters(m, threshold: _motionDetector.shakeThreshold),
              ),
            ] else if (!_sensorsLoading && _sensorsError == null) ...[
              const SizedBox(height: 6),
              Text(
                'Usa el acelerómetro del celular donde está abierta la app: '
                'agitar, inclinar o ponerlo boca abajo.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
