#!/usr/bin/env bash
# Prueba local de la app, sin subirla a internet.
# Toda la app (táctil, cámara y sensores) corre en el navegador del
# dispositivo; esta computadora solo sirve los archivos.
#   - Computadora: http://localhost:8080
#   - Celular:     escanea el QR de la terminal (https://<IP>:8443/)
#
# Uso:  ./iniciar_demo.sh            (compila y arranca)
#       ./iniciar_demo.sh --rapido   (no recompila si ya existe build/web)
set -e
cd "$(dirname "$0")"

PORT=8443
IP=$(ip -4 route get 1.1.1.1 | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
URL="https://$IP:$PORT/"

# 1. Compilar la app web.
if [ "$1" != "--rapido" ] || [ ! -f build/web/index.html ]; then
  echo "Compilando la app (tarda ~1 min)…"
  rm -rf build/web
  flutter build web --release --no-web-resources-cdn
fi

# 2. Certificado HTTPS para la IP actual (cámara y sensores lo exigen).
if [ ! -f certs/cert.pem ] || [ "$(cat certs/ip.txt 2>/dev/null)" != "$IP" ]; then
  mkdir -p certs
  GEN="openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout certs/key.pem -out certs/cert.pem \
    -subj /CN=$IP -addext subjectAltName=IP:$IP"
  if command -v openssl >/dev/null; then eval "$GEN" 2>/dev/null
  else nix-shell -p openssl --run "$GEN" 2>/dev/null; fi
  echo "$IP" > certs/ip.txt
fi

# 3. QR en la terminal para abrir la app en el celular.
QR="qrencode -t ansiutf8 -m 2 $URL"
echo
if command -v qrencode >/dev/null; then eval "$QR"
else nix-shell -p qrencode --run "$QR" 2>/dev/null || true; fi

cat <<MSG

  ┌───────────────────────────────────────────────────────────────┐
     Celular (mismo Wi-Fi):  $URL
     Acepta el aviso del certificado
     ("Configuración avanzada" → "Acceder a $IP").
     En la app toca "Cámara" y "Sensores".
  └───────────────────────────────────────────────────────────────┘

  Si el celular no carga, abre el puerto en el firewall (NixOS):
     sudo iptables -I nixos-fw -p tcp --dport $PORT -j nixos-fw-accept

MSG

# 4. Servidor (Ctrl+C para detener).
exec dart run tool/servidor.dart --ip "$IP" --cert certs/cert.pem --key certs/key.pem
