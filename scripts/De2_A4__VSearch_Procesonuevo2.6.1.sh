#!/usr/bin/env bash
set -euo pipefail

# Process a QIIME2 manifest and classify sequences using vsearch + BLAST.
#
# Required environment variables:
#   BLAST_DB   - path to the reference BLAST database artifact (.qza)
#   TAXONOMY_DB - path to the reference taxonomy artifact (.qza)
# Optional environment variables:
#   EMAIL - address used when notifications are enabled with --notify
#
# Usage:
#   ./scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh \
#       --manifest manifest.csv \
#       --output-dir results_dir \
#       --cluster-id 0.98 \
#       --blast-id 0.8 \
#       --maxaccepts 5 \
#       [--notify|--no-notify] [--email user@example.com]
#
# The script produces taxonomy.qza and search_results.qza in the output
# directory. Intermediate artifacts are also stored there.

usage() {
    cat <<USAGE
Uso: $0 --manifest <archivo> --output-dir <dir> --cluster-id <valor> \\
         --blast-id <valor> --maxaccepts <num> [--notify|--no-notify] [--email <correo>]

Parámetros:
  --manifest     Archivo manifest de QIIME2.
  --output-dir   Directorio de salida para artefactos y resultados.
  --cluster-id   Identidad para clustering de secuencias (0-1).
  --blast-id     Identidad mínima para la clasificación BLAST (0-1).
  --maxaccepts   Número máximo de aciertos BLAST aceptados.
  --notify       Habilita notificaciones por correo (requiere msmtp y EMAIL o --email).
  --no-notify    Deshabilita notificaciones (predeterminado).
  --email        Correo de destino para notificaciones.
  -h, --help     Muestra esta ayuda.
USAGE
}

# Default values
notify=0
email="${EMAIL:-}"

manifest=""
output_dir=""
cluster_id=""
blast_id=""
maxaccepts=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            manifest="${2:-}"
            shift 2
            ;;
        --output-dir)
            output_dir="${2:-}"
            shift 2
            ;;
        --cluster-id)
            cluster_id="${2:-}"
            shift 2
            ;;
        --blast-id)
            blast_id="${2:-}"
            shift 2
            ;;
        --maxaccepts)
            maxaccepts="${2:-}"
            shift 2
            ;;
        --notify)
            notify=1
            shift
            ;;
        --no-notify)
            notify=0
            shift
            ;;
        --email)
            email="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$manifest" || -z "$output_dir" || -z "$cluster_id" || -z "$blast_id" || -z "$maxaccepts" ]]; then
    echo "Faltan parámetros obligatorios." >&2
    usage >&2
    exit 1
fi

if [[ -z "${BLAST_DB:-}" || ! -f "$BLAST_DB" ]]; then
    echo "La variable BLAST_DB debe apuntar a un archivo existente." >&2
    exit 1
fi

if [[ -z "${TAXONOMY_DB:-}" || ! -f "$TAXONOMY_DB" ]]; then
    echo "La variable TAXONOMY_DB debe apuntar a un archivo existente." >&2
    exit 1
fi

if ! command -v qiime >/dev/null; then
    echo "No se encontró 'qiime' en el PATH." >&2
    exit 1
fi

if [[ $notify -eq 1 ]]; then
    if ! command -v msmtp >/dev/null; then
        echo "msmtp no está disponible; instálelo o use --no-notify." >&2
        exit 1
    fi
    if [[ -z "$email" ]]; then
        echo "Se requiere un correo electrónico con --email o variable EMAIL." >&2
        exit 1
    fi
fi

send_notification() {
    local subject="$1"
    local body="$2"
    echo -e "Subject: $subject\n\n$body" | msmtp -a gmail "$email"
}

cleanup() {
    local exit_code=$?
    if [[ $notify -eq 1 ]]; then
        if [[ $exit_code -eq 0 ]]; then
            send_notification "Proceso completado" "Fecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            send_notification "Proceso fallido" "Código: $exit_code\nFecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
    return $exit_code
}
trap cleanup EXIT

if [[ $notify -eq 1 ]]; then
    send_notification "Inicio del proceso" "Fecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
fi

mkdir -p "$output_dir"

# Import sequences from manifest
qiime tools import \
    --type 'SampleData[SequencesWithQuality]' \
    --input-path "$manifest" \
    --input-format 'SingleEndFastqManifestPhred33V2' \
    --output-path "$output_dir/sequences.qza"

# Dereplicate sequences
qiime vsearch dereplicate-sequences \
    --i-sequences "$output_dir/sequences.qza" \
    --o-dereplicated-table "$output_dir/table_derep.qza" \
    --o-dereplicated-sequences "$output_dir/rep_seqs.qza" \
    --verbose

# Cluster sequences de novo
qiime vsearch cluster-features-de-novo \
    --i-sequences "$output_dir/rep_seqs.qza" \
    --i-table "$output_dir/table_derep.qza" \
    --p-perc-identity "$cluster_id" \
    --o-clustered-table "$output_dir/table_clust.qza" \
    --o-clustered-sequences "$output_dir/rep_seqs_clust.qza" \
    --p-threads 19 \
    --verbose

# Classify sequences with BLAST
qiime feature-classifier classify-consensus-blast \
    --i-query "$output_dir/rep_seqs_clust.qza" \
    --i-blastdb "$BLAST_DB" \
    --i-reference-taxonomy "$TAXONOMY_DB" \
    --p-perc-identity "$blast_id" \
    --p-query-cov 0.8 \
    --p-maxaccepts "$maxaccepts" \
    --p-min-consensus 0.51 \
    --p-num-threads 25 \
    --o-classification "$output_dir/taxonomy.qza" \
    --o-search-results "$output_dir/search_results.qza" \
    --verbose

echo "Clasificación completada. Resultados en $output_dir"
