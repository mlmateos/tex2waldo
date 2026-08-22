#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# iguana-build-corpus.sh - Puente entre Iguana y tex2waldo
# Invocado por Iguana con sus variables de usuario (?me, ?m, etc.)
# ============================================================================

# Argumentos recibidos desde Iguana:
#   $1 = directorio del archivo maestro (?m)
#   $2 = nombre del archivo maestro con extensión (?me-#.tex)
#   $3 = nombre base sin extensión (?basename)
#   $4 = flag opcional: "strip" para activar --strip-frontmatter

if [ $# -lt 3 ]; then
    echo "Uso: $0 <dir> <main.tex> <basename> [strip]" >&2
    exit 1
fi

DIR="$1"
MAIN_TEX="$2"
BASENAME="$3"
STRIP_FLAG="${4:-}"

# Ruta al pipeline tex2waldo (ajustable por variable de entorno)
TEX2WALDO="${TEX2WALDO_PATH:-$HOME/projects/tex2waldo/tex2waldo.sh}"

if [ ! -x "$TEX2WALDO" ]; then
    echo "ERROR: tex2waldo no encontrado o no ejecutable en: $TEX2WALDO" >&2
    echo "       Define TEX2WALDO_PATH si está en otra ubicación." >&2
    exit 1
fi

# Archivo de salida: <dir>/<basename>_corpus.md
OUTPUT_MD="$DIR/${BASENAME}_corpus.md"

# Construir el comando
CMD=("$TEX2WALDO")
if [ "$STRIP_FLAG" = "strip" ]; then
    CMD+=(--strip-frontmatter)
fi
CMD+=("$DIR" "$MAIN_TEX" "$OUTPUT_MD")

echo "=== Iguana Build Corpus ===" >&2
echo "  Pipeline : $TEX2WALDO" >&2
echo "  Directorio: $DIR" >&2
echo "  Main     : $MAIN_TEX" >&2
echo "  Salida   : $OUTPUT_MD" >&2
echo "  Strip    : ${STRIP_FLAG:-no}" >&2
echo "===========================" >&2

# Ejecutar el pipeline. Su stderr (mensajes de strip, warnings de Pandoc,
# y futuros errores de lint) fluirá al panel de mensajes de Iguana.
exec "${CMD[@]}"
