#!/bin/bash

# Wrapper para ejecutar la cadena completa de procesamiento de ClipON
# Uso: ./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
# El directorio de trabajo contendrá subcarpetas para cada etapa

set -e
set -u
set -o pipefail

# Determinar la ruta del directorio donde está este script para poder invocar
# los demás scripts sin importar desde dónde se ejecute
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Inicializar conda y activar entornos según la etapa
source "$(conda info --base)/etc/profile.d/conda.sh"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <dir_fastq_entrada> <dir_trabajo>"
    exit 1
fi

INPUT_DIR="$1"
WORK_DIR="$2"

# Configuración opcional para el recorte
SKIP_TRIM="${SKIP_TRIM:-0}"
TRIM_FRONT="${TRIM_FRONT:-30}"
TRIM_BACK="${TRIM_BACK:-30}"

# Definir subdirectorios
PROCESSED_DIR="$WORK_DIR/1_processed"
TRIM_DIR="$WORK_DIR/2_trimmed"
FILTER_DIR="$WORK_DIR/3_filtered"
CLUSTER_DIR="$WORK_DIR/4_clustered"
UNIFIED_DIR="$WORK_DIR/5_unified"
LOG_FILE="$FILTER_DIR/nanofilt.log"

mkdir -p "$PROCESSED_DIR" "$TRIM_DIR" "$FILTER_DIR" "$CLUSTER_DIR" "$UNIFIED_DIR"

# Ejecutar paso 1: limpieza con SeqKit
conda activate clipon-prep
INPUT_DIR="$INPUT_DIR" OUTPUT_DIR="$PROCESSED_DIR" "$script_dir/De0_A1_Process_Fastq.4_SeqKit.sh"

# Paso 2: recorte de cebadores (opcional)
if [ "$SKIP_TRIM" -eq 1 ]; then
    echo "Omitiendo recorte de secuencias."
    cp "$PROCESSED_DIR"/*.fastq "$TRIM_DIR"/
else
    INPUT_DIR="$PROCESSED_DIR" OUTPUT_DIR="$TRIM_DIR" TRIM_FRONT="$TRIM_FRONT" TRIM_BACK="$TRIM_BACK" "$script_dir/De1_A1.5_Trim_Fastq.sh"
fi

# Paso 3: filtrado por calidad y longitud
INPUT_DIR="$TRIM_DIR" OUTPUT_DIR="$FILTER_DIR" LOG_FILE="$LOG_FILE" "$script_dir/De1.5_A2_Filtrado_NanoFilt_1.1.sh"

# Mostrar resumen de lecturas por etapa
CRUDO_STATS="$PROCESSED_DIR/read_stats_crudo.tsv"
PROC_STATS="$PROCESSED_DIR/read_stats_procesado.tsv"
FILT_STATS="$FILTER_DIR/read_stats_filtrado.tsv"
if [ -f "$CRUDO_STATS" ] && [ -f "$PROC_STATS" ] && [ -f "$FILT_STATS" ]; then
    echo "\nResumen de lecturas por etapa:"
    join -t $'\t' -a1 -e0 -o '1.1,1.2,2.2' <(tail -n +2 "$CRUDO_STATS" | sort) <(tail -n +2 "$PROC_STATS" | sort) | \
    join -t $'\t' -a1 -e0 -o '1.1,1.2,1.3,2.2' - <(tail -n +2 "$FILT_STATS" | sort) | \
    awk 'BEGIN {printf "%-40s %-10s %-10s %-10s\n", "Archivo", "crudo", "procesado", "filtrado"} {printf "%-40s %-10s %-10s %-10s\n", $1, $2, $3, $4}'
else
    echo "\nAdvertencia: No se encontraron todos los archivos de estadísticas para mostrar el resumen."
fi

conda activate clipon-ngs

# Paso 4: clusterizado con NGSpeciesID
INPUT_DIR="$FILTER_DIR" OUTPUT_DIR="$CLUSTER_DIR" "$script_dir/De2_A2.5_NGSpecies_Clustering.sh"

# Paso 5: unificación de clusters
BASE_DIR="$CLUSTER_DIR" OUTPUT_DIR="$UNIFIED_DIR" "$script_dir/De2.5_A3_NGSpecies_Unificar_Clusters.sh"

# Paso 6: clasificación con QIIME2
if [[ -z "${BLAST_DB:-}" || -z "${TAXONOMY_DB:-}" ]]; then
    echo "Advertencia: BLAST_DB o TAXONOMY_DB no están definidos. Omitiendo clasificación."
else
    conda activate clipon-qiime
    "$script_dir/De3_A4_Classify_NGS.sh" \
        "$UNIFIED_DIR/consensos_todos.fasta" \
        "$UNIFIED_DIR" \
        "$BLAST_DB" \
        "$TAXONOMY_DB"
    echo "Clasificación finalizada. Revise $UNIFIED_DIR/MaxAc_5"
fi
    
# Paso 7: exportar resultados de clasificación
"$script_dir/De3_A4_Export_Classification.sh" "$UNIFIED_DIR"

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/MaxAc_5"

echo "Pipeline completado. Resultados en: $WORK_DIR"
