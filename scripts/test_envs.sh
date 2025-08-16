#!/usr/bin/env bash
set -euo pipefail

# Script to verify required ClipON conda environments are present
# and can run a simple command.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check that conda is available
if ! command -v conda >/dev/null 2>&1; then
  echo "Conda no se encontró en el sistema."
  read -rp "¿Desea ejecutar $SCRIPT_DIR/install_envs.sh para instalarlo? [y/N] " resp
  if [[ $resp =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/install_envs.sh"
  fi
  exit 1
fi

# Associate each environment with a representative command
# that should succeed if the environment is properly installed.
declare -A ENV_CHECKS=(
  [clipon-prep]="cutadapt --version"
  [clipon-qiime]="qiime --help"
  [clipon-ngs]="minimap2 --version"
)

missing_envs=()

for env in "${!ENV_CHECKS[@]}"; do
  echo "Comprobando entorno '$env'..."
  if conda env list | awk '{print $1}' | grep -Fxq "$env"; then
    cmd=${ENV_CHECKS[$env]}
    if conda run -n "$env" $cmd >/dev/null 2>&1; then
      echo "  - OK: $cmd"
    else
      echo "  - Falló al ejecutar '$cmd'"
    fi
    if [[ "$env" == "clipon-prep" ]]; then
      if ! conda run -n clipon-prep \
        Rscript -e "quit(status = !all(c('ggplot2','readr') %in% rownames(installed.packages())))" >/dev/null 2>&1; then
        echo "Instale los paquetes de R necesarios (ggplot2, readr) en el entorno clipon-prep."
      fi
    fi
  else
    echo "  - Entorno no encontrado"
    missing_envs+=("$env")
  fi
  echo

done

if (( ${#missing_envs[@]} )); then
  echo "Entornos faltantes: ${missing_envs[*]}"
  read -rp "¿Desea ejecutar $SCRIPT_DIR/install_envs.sh para instalarlos? [y/N] " answer
  if [[ $answer =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/install_envs.sh"
  fi
fi
