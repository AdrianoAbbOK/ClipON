#!/bin/bash
set -e
set -u

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

if ! command -v qiime >/dev/null; then
    echo "No se encontró 'qiime' en el PATH." >&2
    exit 1
fi

mkdir -p "$output_dir"
export_dir="$output_dir/MaxAc_5"
mkdir -p "$export_dir"

# Activar entorno por si el script se ejecuta de forma independiente
if command -v conda >/dev/null; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate clipon-qiime
fi

qiime tools import \
    --input-path "$input_fasta" \
    --type 'FeatureData[Sequence]' \
    --output-path "$output_dir/consensus_sequences.qza"

qiime feature-classifier classify-consensus-blast \
    --i-query "$output_dir/consensus_sequences.qza" \
    --i-blastdb "$blast_db" \
    --i-reference-taxonomy "$taxonomy_db" \
    --verbose \
    --p-num-threads 5 \
    --p-perc-identity 0.8 \
    --p-query-cov 0.8 \
    --p-maxaccepts 5 \
    --p-min-consensus 0.51 \
    --o-classification "$output_dir/taxonomy.qza" \
    --o-search-results "$output_dir/search_results.qza"

qiime tools export \
        --input-path "$output_dir/taxonomy.qza" \
        --output-path "$export_dir"

qiime tools export \
        --input-path "$output_dir/search_results.qza" \
        --output-path "$export_dir"

echo "Clasificación completada. Resultados en: $export_dir"
