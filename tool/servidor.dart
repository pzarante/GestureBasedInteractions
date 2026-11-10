// Servidor local para probar la app sin subirla a internet.
// Solo usa dart:io (no necesita paquetes) y solo sirve archivos: toda la app
// (cámara, sensores y gestos) corre en el navegador del dispositivo.
//
//  * http://localhost:8080        → en esta computadora (localhost permite
//                                   usar la cámara sin certificado).
//  * https://<IP>:8443/           → en el celular, por Wi-Fi (la cámara y
//                                   los sensores del celular exigen HTTPS).
//
// Uso: dart run tool/servidor.dart --ip 192.168.1.10 \
//        --cert certs/cert.pem --key certs/key.pem [--web build/web]
import 'dart:io';

const httpPort = 8080;
const httpsPort = 8443;

late final Directory webRoot;

const mimeTypes = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'json': 'application/json',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'ico': 'image/x-icon',
  'svg': 'image/svg+xml',
  'otf': 'font/otf',
  'ttf': 'font/ttf',
  'woff2': 'font/woff2',
  'task': 'application/octet-stream',
  'bin': 'application/octet-stream',
  'symbols': 'text/plain',
};

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final ip = arg('ip') ?? '127.0.0.1';
  webRoot = Directory(arg('web') ?? 'build/web');
  if (!webRoot.existsSync()) {
    stderr.writeln(
      'No existe ${webRoot.path}. Ejecuta primero: flutter build web',
    );
    exit(1);
  }

  final local = await HttpServer.bind(InternetAddress.loopbackIPv4, httpPort);
  local.listen(handle);

  final cert = arg('cert'), key = arg('key');
  if (cert != null && key != null) {
    final ctx = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    final secure = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      httpsPort,
      ctx,
    );
    secure.listen(handle);
  } else {
    stdout.writeln('(Sin certificado: el celular no podrá abrir la app.)');
  }

  stdout.writeln('En esta computadora: http://localhost:$httpPort');
  stdout.writeln('En el celular:       https://$ip:$httpsPort/');
  stdout.writeln('Ctrl+C para detener.');
}

Future<void> handle(HttpRequest req) async {
  try {
    await _serveFile(req);
  } catch (e) {
    try {
      req.response.statusCode = HttpStatus.internalServerError;
      await req.response.close();
    } catch (_) {}
  }
}

Future<void> _serveFile(HttpRequest req) async {
  var path = Uri.decodeComponent(req.uri.path);
  if (path.endsWith('/')) path += 'index.html';
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.any((s) => s == '..')) {
    req.response.statusCode = HttpStatus.forbidden;
    await req.response.close();
    return;
  }
  final file = File([webRoot.path, ...segments].join(Platform.pathSeparator));
  final res = req.response;
  if (!file.existsSync()) {
    res.statusCode = HttpStatus.notFound;
    await res.close();
    return;
  }
  final ext = file.path.split('.').last.toLowerCase();
  res.headers.set(
    HttpHeaders.contentTypeHeader,
    mimeTypes[ext] ?? 'application/octet-stream',
  );
  res.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
  await res.addStream(file.openRead());
  await res.close();
}
