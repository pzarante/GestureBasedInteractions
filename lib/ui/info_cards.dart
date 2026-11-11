import 'package:flutter/material.dart';

import 'nui.dart';

/// Tabla "gesto → función"; resalta la función del último evento.
class GestureMap extends StatelessWidget {
  const GestureMap({super.key, this.active});
  final ActionEvent? active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = this.active;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gesto → función', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final fn in NuiFunction.values)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active?.function == fn
                      ? active!.modality.color.withValues(alpha: 0.25)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                  border: Border.all(
                    color: active?.function == fn
                        ? active!.modality.color
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(fn.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          fn.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final m in Modality.values)
                      if (fn.gestureFor(m).isNotEmpty)
                        _gestureLine(m, fn.gestureFor(m)),
                  ],
                ),
              ),
            Text(
              'Touchless: señalar con el índice mueve el cursor sin dibujar.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gestureLine(Modality m, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(m.icon, size: 15, color: m.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Últimos 8 eventos detectados, de cualquier canal.
class EventLog extends StatelessWidget {
  const EventLog(this.log, {super.key});
  final List<ActionEvent> log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registro de eventos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            if (log.isEmpty)
              Text(
                'Aún no se ha detectado ningún gesto.',
                style: theme.textTheme.bodySmall,
              ),
            for (final e in log.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(e.modality.icon, size: 16, color: e.modality.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.modality.label}: ${e.function.gestureFor(e.modality)}'
                        ' → ${e.function.label} (${e.detail})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      '${e.time.hour.toString().padLeft(2, '0')}:'
                      '${e.time.minute.toString().padLeft(2, '0')}:'
                      '${e.time.second.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Aviso breve sobre la pizarra: "gesto → función" del último evento.
class FlashBanner extends StatelessWidget {
  const FlashBanner(this.event, {super.key});
  final ActionEvent? event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: e == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(e),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: e.modality.color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(e.modality.icon, color: e.modality.color, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${e.function.gestureFor(e.modality)}  →  '
                      '${e.function.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
