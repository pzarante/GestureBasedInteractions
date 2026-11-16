# Gesture Based Interactions

- [Demo web](https://pzarante.github.io/GestureBasedInteractions/)
- [Aprender Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Codelab de Flutter](https://docs.flutter.dev/get-started/codelab)
- [Documentación de Flutter](https://docs.flutter.dev/)

Aplicación experimental desarrollada con Flutter para explorar interacciones gestuales usando la pantalla táctil, la cámara y los sensores de movimiento del dispositivo.

## Características

- Interacción táctil con gestos e inercia.
- Seguimiento de manos mediante la cámara.
- Lectura de sensores de movimiento.
- Visualización interactiva de los datos y estados detectados.
- Ejecución en navegador y dispositivos compatibles con Flutter.

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) instalado.
- Un navegador compatible para ejecutar la versión web.
- Para probar cámara y sensores desde un celular, el celular y la computadora deben estar en la misma red Wi-Fi.

## Instalación y ejecución

```bash
flutter pub get
flutter run -d chrome
```

Para probar la aplicación desde un celular, el script prepara una compilación web, configura HTTPS local y muestra un código QR:

```bash
./iniciar_demo.sh
```

Después, abre la dirección indicada en el celular y acepta el aviso del certificado. HTTPS es necesario para que el navegador permita el acceso a la cámara y a los sensores.

Si ya existe una compilación web, puedes iniciar el modo rápido con:

```bash
./iniciar_demo.sh --rapido
```

## Compilar para GitHub Pages

```bash
./construir_github_pages.sh
```

El resultado se genera en `docs/`, que puede publicarse como la fuente de GitHub Pages del repositorio.

## Estructura principal

- `lib/board`: lienzo y estado de la interacción.
- `lib/gestures`: detectores de gestos táctiles y sin contacto.
- `lib/hand_tracking`: seguimiento de manos.
- `lib/motion`: lectura de sensores de movimiento.
- `lib/ui`: componentes y visualizaciones de la interfaz.
- `tool/servidor.dart`: servidor HTTPS local para las pruebas desde móvil.

## Licencia

Este proyecto se encuentra en desarrollo y está destinado a fines educativos y de experimentación.