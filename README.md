# Gesture-Based Interactions
### Por: Paula Núñez y Natalia Carpintero

- **Video de la exposición:** https://canva.link/62s2oo2jzow3z23
- **Link de la Demo:** https://pzarante.github.io/GestureBasedInteractions/
- **Diapositivas:** https://github.com/pzarante/GestureBasedInteractions/blob/main/DiapositivasEXPOMOVIL.pdf

Una pizarra hecha en **Flutter** que se controla solo con gestos mediante tres canales distintos. Es la demo de la presentación *Gesture-Based Interaction* de Programación Móvil.

## ¿Qué hace?

Los tres canales llaman a las **mismas funciones** —dibujar, deshacer, cambiar color, borrar todo y hacer zoom—, así que la pizarra responde igual sin importar de dónde venga el gesto. Por eso es un sistema **multimodal**.

## Gestos por canal

| Función | Táctil | Inercial | Touchless |
| --- | --- | --- | --- |
| Dibujar | Arrastrar un dedo | No aplica | Pinza (pulgar + índice) y mover |
| Zoom | Pellizcar | No aplica | Pulgar + medio, acercar o alejar |
| Deshacer | Tocar con dos dedos | Agitar el celular | Índice + medio arriba |
| Cambiar color | Doble toque | Inclinar a un lado | Palma abierta moviéndola a un lado |
| Borrar todo | Mantener presionado | Celular boca abajo | Cerrar el puño |

## Cómo funciona cada canal

Todos siguen el mismo camino: **entrada → gesto → llamada → dibujo**.

- **Táctil:** `Listener` y `GestureDetector` de Flutter reciben los toques y reconocen los gestos. El toque con dos dedos se reconoce mediante los eventos táctiles de bajo nivel.
- **Inercial:** el celular envía lecturas de aceleración y orientación aproximadamente 60 veces por segundo. Agitar se detecta mediante la magnitud de la aceleración `√(x²+y²+z²)` sobre un umbral de `12 m/s²`, mientras que inclinar y poner el celular boca abajo se detectan mediante los ángulos `gamma` y `beta`.
- **Touchless:** [MediaPipe Hand Landmarker](https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker) encuentra 21 puntos de la mano usando la cámara, directamente en el dispositivo. Cada pose se reconoce midiendo distancias entre puntos, normalizadas según el tamaño de la mano, y debe mantenerse varios frames seguidos para evitar falsos positivos.

## Estructura

```text
lib/
  main.dart                              # Pizarra y llamadas a las acciones
  gestures/
    inertial_gesture_detector.dart       # Agitar, inclinar y boca abajo
    touchless_gesture_detector.dart      # Poses de la mano
web/
  motion_sensor.js                       # Sensores de movimiento del navegador
  hand_tracker.js                        # MediaPipe y cámara
```

## Cómo probarla

1. Para una prueba básica en el computador, instala las dependencias y ejecuta la aplicación en Chrome:

   ```bash
   flutter pub get
   flutter run -d chrome
   ```

2. Para probar el canal touchless, abre la demo en Chrome y permite el acceso a la **cámara**.
3. Para probar el canal inercial desde un celular, ejecuta `./iniciar_demo.sh`. El script compila la aplicación, configura HTTPS local y muestra un código QR. Abre la dirección indicada en el celular y acepta el aviso del certificado.
4. El canal táctil funciona directamente con mouse, pantalla táctil o trackpad.

HTTPS es necesario para que el navegador permita el acceso a la cámara y a los sensores desde el celular.

## Tecnologías

Flutter · Dart · MediaPipe Hand Landmarker · API de sensores de movimiento y orientación del navegador
