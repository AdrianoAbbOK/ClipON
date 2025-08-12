#!/bin/bash

# Script to verify required ClipON conda environments are present
# and can run a simple command.

# Check that conda is available
if ! command -v conda >/dev/null; then
  echo "Conda no se encontró en el sistema."
  exit 1
fi

# Associate each environment with a representative command
# that should succeed if the environment is properly installed.
declare -A ENV_CHECKS=(
  [clipon-prep]="cutadapt --version"
  [clipon-qiime]="qiime --help"
  [clipon-ngs]="minimap2 --version"
)

for env in "${!ENV_CHECKS[@]}"; do
  echo "Comprobando entorno '$env'..."
  if conda env list | awk '{print $1}' | grep -Fxq "$env"; then
    cmd=${ENV_CHECKS[$env]}
    if conda run -n "$env" $cmd >/dev/null 2>&1; then
      echo "  - OK: $cmd"
    else
      echo "  - Falló al ejecutar '$cmd'"
    fi
  else
    echo "  - Entorno no encontrado"
  fi
  echo

done
