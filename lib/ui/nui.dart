import 'package:flutter/material.dart';

/// Los tres canales físicos y qué gesto dispara cada función.
enum Modality {
  touch('Táctil', Icons.touch_app, Color(0xFF64B5F6)),
  touchless('Touchless', Icons.back_hand, Color(0xFF81C784)),
  inertial('Inercial', Icons.screen_rotation, Color(0xFFFFB74D));

  const Modality(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum NuiFunction {
  draw(
    'Dibujar',
    Icons.brush,
    touch: 'Arrastrar un dedo',
    touchless: 'Juntar pulgar e índice y mover la mano',
  ),
  color(
    'Cambiar color',
    Icons.palette,
    touch: 'Doble toque',
    touchless: 'Mover la palma abierta a un lado',
    inertial: 'Inclinar el celular a un lado',
  ),
  undo(
    'Deshacer',
    Icons.undo,
    touch: 'Toque con dos dedos',
    touchless: 'Levantar dos dedos (índice y medio)',
    inertial: 'Agitar el celular',
  ),
  clear(
    'Borrar todo',
    Icons.delete_sweep,
    touch: 'Mantener presionado',
    touchless: 'Cerrar el puño',
    inertial: 'Poner el celular boca abajo',
  ),
  zoom('Zoom del lienzo', Icons.zoom_in, touch: 'Pellizcar con dos dedos');

  const NuiFunction(
    this.label,
    this.icon, {
    this.touch,
    this.touchless,
    this.inertial,
  });
  final String label;
  final IconData icon;
  final String? touch;
  final String? touchless;
  final String? inertial;

  String gestureFor(Modality m) =>
      switch (m) {
        Modality.touch => touch,
        Modality.touchless => touchless,
        Modality.inertial => inertial,
      } ??
      '';
}

class ActionEvent {
  ActionEvent(this.modality, this.function, this.detail)
    : time = DateTime.now();
  final Modality modality;
  final NuiFunction function;
  final String detail;
  final DateTime time;
}
