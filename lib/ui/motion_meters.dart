import 'package:flutter/material.dart';

import 'nui.dart';

/// Lo que se muestra en vivo de los sensores (se actualiza ~60 veces/s).
class MotionView {
  const MotionView({this.magnitude = 0, this.gamma, this.faceDown = false});
  final double magnitude;
  final double? gamma;
  final bool faceDown;
}

/// Barra de |a| con una línea roja en el umbral de agitación.
class _MagnitudeBar extends StatelessWidget {
  const _MagnitudeBar(this.m, this.threshold, {required this.height});
  final MotionView m;
  final double threshold;
  final double height;

  static const maxMag = 30.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: radius,
                ),
              ),
              Container(
                width: w * (m.magnitude / maxMag).clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: m.magnitude > threshold
                      ? Colors.redAccent
                      : Modality.inertial.color,
                  borderRadius: radius,
                ),
              ),
              Positioned(
                left: w * threshold / maxMag,
                top: 0,
                bottom: 0,
                child: Container(width: height / 6, color: Colors.redAccent),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13);

/// Versión compacta de los medidores del acelerómetro (una sola fila).
class MotionStrip extends StatelessWidget {
  const MotionStrip(this.m, {super.key, required this.threshold});
  final MotionView m;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text('|a| ${m.magnitude.toStringAsFixed(1)}', style: _mono),
        ),
        Expanded(child: _MagnitudeBar(m, threshold, height: 12)),
        SizedBox(
          width: 70,
          child: Text(
            m.faceDown
                ? 'boca ab.'
                : m.gamma == null
                ? '—'
                : '${m.gamma!.toStringAsFixed(0)}°',
            textAlign: TextAlign.right,
            style: _mono,
          ),
        ),
      ],
    );
  }
}

/// Medidores completos del acelerómetro (panel de pantalla ancha).
class MotionMeters extends StatelessWidget {
  const MotionMeters(this.m, {super.key, required this.threshold});
  final MotionView m;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '|a| = √(x²+y²+z²) = ${m.magnitude.toStringAsFixed(1)} m/s²',
          style: _mono,
        ),
        const SizedBox(height: 6),
        _MagnitudeBar(m, threshold, height: 18),
        const SizedBox(height: 4),
        Text(
          'Umbral de agitación: ${threshold.toStringAsFixed(0)} m/s²',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Text(
          m.faceDown
              ? 'Boca abajo'
              : 'Inclinación: ${m.gamma == null ? '—' : '${m.gamma!.toStringAsFixed(0)}°'}',
          style: _mono,
        ),
      ],
    );
  }
}
