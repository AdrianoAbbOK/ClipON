#!/usr/bin/env bash
set -euo pipefail

# Exporta archivos de clasificacion de QIIME2
# Uso:
#   ./scripts/De3_A5_Export_Classification.sh <dir_clasificacion>
#   o defina la variable CLASS_DIR

class_dir="${CLASS_DIR:-${1-}}"

if [[ -z "$class_dir" ]]; then
    echo "Uso: $0 <dir_clasificacion>" >&2
    echo "   o defina la variable CLASS_DIR" >&2
    exit 1
fi

if ! command -v qiime >/dev/null; then
    echo "No se encontro 'qiime' en el PATH." >&2
    exit 1
fi

export_dir="$class_dir/Results"
mkdir -p "$export_dir"
log_file="$export_dir/export.log"

# Activar entorno por si el script se ejecuta de forma independiente
if command -v conda >/dev/null; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate clipon-qiime
fi

qiime tools export \
    --input-path "$class_dir/taxonomy.qza" \
    --output-path "$export_dir" \
    >>"$log_file" 2>&1

qiime tools export \
    --input-path "$class_dir/search_results.qza" \
    --output-path "$export_dir" \
    >>"$log_file" 2>&1

# Generar tabla con columnas adicionales de lecturas y muestra
if [[ -n "${METADATA_FILE:-}" ]]; then
    python3 "$(dirname "$0")/add_reads_and_sample.py" \
        --metadata "$METADATA_FILE" "$export_dir/taxonomy.tsv" >>"$log_file" 2>&1
else
    python3 "$(dirname "$0")/add_reads_and_sample.py" "$export_dir/taxonomy.tsv" >>"$log_file" 2>&1
fi

if [[ -f "$export_dir/taxonomy_with_sample.tsv" ]]; then
    echo "Exportación completada:"
    echo "  Taxonomía: $export_dir/taxonomy.tsv"
    echo "  Búsqueda BLAST: $export_dir/search_results.tsv"
    echo "  Tabla con muestras: $export_dir/taxonomy_with_sample.tsv"
    echo "Log detallado: $log_file"
else
    echo "Error en la exportación. Revise $log_file" >&2
    exit 1
fi

echo "Exportación finalizada. Resultados en: $export_dir"
