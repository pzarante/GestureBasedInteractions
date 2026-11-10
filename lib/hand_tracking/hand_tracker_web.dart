import 'dart:js_interop';

import 'package:flutter/widgets.dart';

import '../gestures/touchless_gesture_detector.dart';

typedef HandFrameCallback = void Function(List<Point3D>? hand, double aspect);

/// API expuesta por web/hand_tracker.js en `window.handTracker`.
extension type _HandTrackerJS._(JSObject _) implements JSObject {
  external JSPromise<JSString?> start();
  external void stop();
  external void setListener(JSFunction listener);
  external void attachPreview(JSObject container);
}

@JS('handTracker')
external _HandTrackerJS? get _tracker;

class HandTracker {
  static bool get isSupported => true;

  /// Enciende la cámara y empieza a enviar los 21 landmarks por frame.
  /// Devuelve un mensaje de error, o null si arrancó bien.
  static Future<String?> start(HandFrameCallback onFrame) async {
    final tracker = _tracker;
    if (tracker == null) {
      return 'No se cargó hand_tracker.js (revisa web/index.html).';
    }
    tracker.setListener(
      ((JSFloat32Array? data, JSNumber aspect) {
        final a = aspect.toDartDouble;
        if (data == null) {
          onFrame(null, a);
          return;
        }
        final f = data.toDart;
        onFrame([
          for (var i = 0; i < 21; i++)
            Point3D(f[i * 3], f[i * 3 + 1], f[i * 3 + 2]),
        ], a);
      }).toJS,
    );
    final error = await tracker.start().toDart;
    return error?.toDart;
  }

  static void stop() => _tracker?.stop();

  /// Vista HTML donde se dibuja el video espejado con el esqueleto de la mano.
  static Widget preview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (Object element) =>
        _tracker?.attachPreview(element as JSObject),
  );
}
