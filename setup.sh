#!/usr/bin/env bash
set -euo pipefail

# Instala eog para la visualización de imágenes
if ! command -v eog >/dev/null 2>&1; then
  echo "Instalando eog..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y eog
  else
    echo "apt-get no está disponible; instala eog manualmente." >&2
  fi
fi

# Instala/actualiza Miniconda y crea los entornos requeridos
./scripts/install_envs.sh

# Variables de entorno opcionales para la clasificación
# Edita estas rutas si vas a usar el paso de clasificación
export BLAST_DB=${BLAST_DB:-/ruta/a/search_results.qza}
export TAXONOMY_DB=${TAXONOMY_DB:-/ruta/a/taxonomy.qza}

echo "Entornos creados. Recuerda que puedes ejecutar el pipeline con:"
echo "./scripts/run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>"
