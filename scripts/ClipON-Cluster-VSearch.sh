#!/usr/bin/env bash
set -euo pipefail

# Cluster sequences with QIIME2 + VSEARCH using the ClipON directory layout.
#
# Uso:
#   INPUT_DIR=/ruta/a/fastq OUTPUT_DIR=/ruta/a/salida ./ClipON-Cluster-VSearch.sh
#   o: ./ClipON-Cluster-VSearch.sh <dir_entrada> <dir_salida>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input_dir="${INPUT_DIR:-${1-}}"
output_dir="${OUTPUT_DIR:-${2-}}"
manifest_path="${MANIFEST_PATH:-$output_dir/manifest.csv}"

# Parámetros de VSEARCH
VS_IDENTITY="${VS_IDENTITY:-0.98}"
VS_THREADS="${VS_THREADS:-16}"

if [[ -z "$input_dir" || -z "$output_dir" ]]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> $0" >&2
    echo "   o: $0 <dir entrada> <dir salida>" >&2
    exit 1
fi

if ! command -v qiime >/dev/null; then
    echo "No se encontró 'qiime' en el PATH." >&2
    exit 1
fi

if ! command -v biom >/dev/null; then
    echo "No se encontró 'biom' en el PATH." >&2
    exit 1
fi

mkdir -p "$output_dir"

# Limpiar consensos previos para evitar contaminar nuevas ejecuciones
rm -f "$output_dir/consensos_todos.fasta"
find "$output_dir" -mindepth 1 -maxdepth 1 -type d ! -name export -exec rm -rf {} +

# Generar manifiesto de importación
bash "$SCRIPT_DIR/generate_manifest.sh" --filtered "$input_dir" >"$manifest_path"

sequences_qza="$output_dir/sequences.qza"
demux_qzv="$output_dir/demux_summary.qzv"
derep_table_qza="$output_dir/table_derep.qza"
derep_seqs_qza="$output_dir/rep_seqs_derep.qza"
cluster_table_qza="$output_dir/table_clustered.qza"
cluster_seqs_qza="$output_dir/rep_seqs_clustered.qza"
export_dir="$output_dir/export"

qiime tools import \
    --type 'SampleData[SequencesWithQuality]' \
    --input-path "$manifest_path" \
    --input-format 'SingleEndFastqManifestPhred33V2' \
    --output-path "$sequences_qza"

qiime demux summarize \
    --i-data "$sequences_qza" \
    --o-visualization "$demux_qzv"

qiime vsearch dereplicate-sequences \
    --i-sequences "$sequences_qza" \
    --o-dereplicated-table "$derep_table_qza" \
    --o-dereplicated-sequences "$derep_seqs_qza" \
    --verbose

qiime vsearch cluster-features-de-novo \
    --i-sequences "$derep_seqs_qza" \
    --i-table "$derep_table_qza" \
    --p-perc-identity "$VS_IDENTITY" \
    --p-threads "$VS_THREADS" \
    --o-clustered-table "$cluster_table_qza" \
    --o-clustered-sequences "$cluster_seqs_qza" \
    --verbose

rm -rf "$export_dir"
mkdir -p "$export_dir"

qiime tools export --input-path "$cluster_seqs_qza" --output-path "$export_dir"
qiime tools export --input-path "$cluster_table_qza" --output-path "$export_dir"

biom convert \
    -i "$export_dir/feature-table.biom" \
    -o "$export_dir/feature-table.tsv" \
    --to-tsv

python "$SCRIPT_DIR/ClipON-Cluster-VSearch-Consensus.py" \
    --sequences "$export_dir/dna-sequences.fasta" \
    --table "$export_dir/feature-table.tsv" \
    --output-dir "$output_dir"

cat <<EOF
Clustering VSEARCH finalizado.
  - Secuencias importadas: $sequences_qza
  - Resumen demux: $demux_qzv
  - Tabla de features: $cluster_table_qza
  - Secuencias clusterizadas: $cluster_seqs_qza
EOF
