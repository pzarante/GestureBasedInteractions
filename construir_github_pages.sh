#!/usr/bin/env bash
# Compila la app para GitHub Pages y deja el resultado en docs/.
#
# Uso:  ./construir_github_pages.sh [nombre-del-repositorio]
#       (por defecto: GestureBasedInteractions)
#
# Después: sube el repositorio a GitHub y en
#   Settings → Pages → "Deploy from a branch" → rama main, carpeta /docs
# La app queda en https://<usuario>.github.io/<nombre-del-repositorio>/
set -e
cd "$(dirname "$0")"

REPO="${1:-GestureBasedInteractions}"

echo "Compilando para https://<usuario>.github.io/$REPO/ …"
# --no-web-resources-cdn: el motor de Flutter (CanvasKit) se sirve desde el
# mismo sitio, sin depender de otro servidor.
rm -rf build/web
flutter build web --release --no-web-resources-cdn --base-href "/$REPO/"

rm -rf docs
cp -r build/web docs
touch docs/.nojekyll # GitHub Pages: servir los archivos tal cual

echo
echo "Listo: docs/ ($(du -sh docs | cut -f1))."
echo "Sube el repositorio y activa Pages en la carpeta /docs de la rama main."
