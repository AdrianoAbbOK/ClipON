#!/usr/bin/env bash
set -euo pipefail

# Clasifica consensos con QIIME2 empleando el clasificador BLAST
# Uso:
#   ./scripts/De3_A4_Classify_NGS.sh <consensos.fasta> <output_dir> <blast_db.qza> <taxonomy.qza>
# O defina las variables de entorno INPUT_FASTA, OUTPUT_DIR, BLAST_DB y TAXONOMY_DB

input_fasta="${INPUT_FASTA:-${1-}}"
output_dir="${OUTPUT_DIR:-${2-}}"
blast_db="${BLAST_DB:-${3-}}"
taxonomy_db="${TAXONOMY_DB:-${4-}}"

if [[ -z "$input_fasta" || -z "$output_dir" || -z "$blast_db" || -z "$taxonomy_db" ]]; then
    echo "Uso: $0 <fasta> <output_dir> <blast_db.qza> <taxonomy.qza>" >&2
    echo "   o defina las variables INPUT_FASTA, OUTPUT_DIR, BLAST_DB y TAXONOMY_DB" >&2
    exit 1
fi

if [[ ! -f "$blast_db" ]]; then
    echo "El archivo BLAST_DB no existe: $blast_db" >&2
    exit 1
fi

if [[ ! -f "$taxonomy_db" ]]; then
    echo "El archivo TAXONOMY_DB no existe: $taxonomy_db" >&2
    exit 1
fi

# Parámetros de clasificación con valores por defecto
NUM_THREADS="${NUM_THREADS:-5}"
PERC_ID="${PERC_ID:-0.8}"
QUERY_COV="${QUERY_COV:-0.8}"
MAX_ACCEPTS="${MAX_ACCEPTS:-1}"
MIN_CONSENSUS="${MIN_CONSENSUS:-0.51}"

if ! command -v qiime >/dev/null; then
    echo "No se encontró 'qiime' en el PATH." >&2
    exit 1
fi

mkdir -p "$output_dir"
log_file="$output_dir/classify.log"

# Activar entorno por si el script se ejecuta de forma independiente
if command -v conda >/dev/null; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate clipon-qiime
fi

# Importar secuencias y redirigir salida a un archivo de log
if qiime tools import \
    --input-path "$input_fasta" \
    --type 'FeatureData[Sequence]' \
    --output-path "$output_dir/consensus_sequences.qza" \
    >>"$log_file" 2>&1; then
    echo "Importación completada: $output_dir/consensus_sequences.qza"
else
    echo "Error en la importación. Revise $log_file" >&2
    exit 1
fi

# Clasificación BLAST y redirección al log
if qiime feature-classifier classify-consensus-blast \
    --i-query "$output_dir/consensus_sequences.qza" \
    --i-blastdb "$blast_db" \
    --i-reference-taxonomy "$taxonomy_db" \
    --p-num-threads "$NUM_THREADS" \
    --p-perc-identity "$PERC_ID" \
    --p-query-cov "$QUERY_COV" \
    --p-maxaccepts "$MAX_ACCEPTS" \
    --p-min-consensus "$MIN_CONSENSUS" \
    --o-classification "$output_dir/taxonomy.qza" \
    --o-search-results "$output_dir/search_results.qza" \
    >>"$log_file" 2>&1; then
    echo "Clasificación completada:"
    echo "  Taxonomía: $output_dir/taxonomy.qza"
    echo "  Resultados de búsqueda: $output_dir/search_results.qza"
    echo "Log detallado: $log_file"
else
    echo "Error en la clasificación. Revise $log_file" >&2
    exit 1
fi

echo "Clasificación finalizada. Archivos .qza disponibles en: $output_dir"
