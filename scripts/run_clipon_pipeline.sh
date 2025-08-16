#!/bin/bash

# Wrapper para ejecutar la cadena completa de procesamiento de ClipON
# Uso: ./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
# El directorio de trabajo contendrá subcarpetas para cada etapa

# Para un gráfico avanzado de la calidad de lectura combine los TSV generados en cada etapa (collect_read_stats.py):
# Rscript scripts/read_quality_poster.R "ruta/etapa1.tsv,ruta/etapa2.tsv" salida.png

set -e
set -u
set -o pipefail

# Determinar la raíz del repositorio y usar rutas relativas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Inicializar conda y activar entornos según la etapa
source "$(conda info --base)/etc/profile.d/conda.sh"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <dir_fastq_entrada> <dir_trabajo>"
    exit 1
fi

INPUT_DIR="${1%/}"
WORK_DIR="${2%/}"

# Configuración opcional para el recorte
SKIP_TRIM="${SKIP_TRIM:-0}"
TRIM_FRONT="${TRIM_FRONT:-30}"
TRIM_BACK="${TRIM_BACK:-30}"
RESUME_STEP="${RESUME_STEP:-1}"

# Definir subdirectorios
PROCESSED_DIR="$WORK_DIR/1_processed"
TRIM_DIR="$WORK_DIR/2_trimmed"
FILTER_DIR="$WORK_DIR/3_filtered"
CLUSTER_DIR="$WORK_DIR/4_clustered"
UNIFIED_DIR="$WORK_DIR/5_unified"
LOG_FILE="$FILTER_DIR/nanofilt.log"

mkdir -p "$PROCESSED_DIR" "$TRIM_DIR" "$FILTER_DIR" "$CLUSTER_DIR" "$UNIFIED_DIR"

run_step() {
    local step="$1"
    local env="$2"
    shift 2
    local cmd="$*"

    if [ "$RESUME_STEP" -gt "$step" ]; then
        echo "Saltando paso $step; RESUME_STEP=$RESUME_STEP"
        return 0
    fi

    conda activate "$env"
    eval "$cmd"
    touch "$WORK_DIR/.step${step}_done"
}

trim_reads() {
    if [ "$SKIP_TRIM" -eq 1 ]; then
        echo "Omitiendo recorte de secuencias."
        cp "$PROCESSED_DIR"/*.fastq "$TRIM_DIR"/
    else
        INPUT_DIR="$PROCESSED_DIR" OUTPUT_DIR="$TRIM_DIR" TRIM_FRONT="$TRIM_FRONT" TRIM_BACK="$TRIM_BACK" \
            bash scripts/De1_A1.5_Trim_Fastq.sh
    fi
}

classify_reads() {
    if [[ -z "${BLAST_DB:-}" || -z "${TAXONOMY_DB:-}" ]]; then
        echo "Advertencia: BLAST_DB o TAXONOMY_DB no están definidos. Omitiendo clasificación."
        return 0
    fi
    bash scripts/De3_A4_Classify_NGS.sh \
        "$UNIFIED_DIR/consensos_todos.fasta" \
        "$UNIFIED_DIR" \
        "$BLAST_DB" \
        "$TAXONOMY_DB"
    echo "Clasificación finalizada. Revise $UNIFIED_DIR/MaxAc_5"
}

run_step 1 clipon-prep INPUT_DIR="$INPUT_DIR" OUTPUT_DIR="$PROCESSED_DIR" bash scripts/De0_A1_Process_Fastq.4_SeqKit.sh
run_step 2 clipon-prep trim_reads
run_step 3 clipon-prep INPUT_DIR="$TRIM_DIR" OUTPUT_DIR="$FILTER_DIR" LOG_FILE="$LOG_FILE" bash scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh

# Generar gráfico de calidad vs longitud para múltiples etapas
# Se captura solo la última línea para obtener la ruta del archivo generado
if command -v Rscript >/dev/null 2>&1; then
    PLOT_FILE=$(Rscript scripts/plot_quality_vs_length_multi.R \
        "$FILTER_DIR/read_quality_vs_length.png" \
        "$PROCESSED_DIR"/*_processed_stats.tsv \
        "$FILTER_DIR"/*_filtered_stats.tsv 2>&1 | tee "$WORK_DIR/r_plot.log" | tail -n 1) || {
            echo "Fallo en Rscript: revisar dependencias" >> "$WORK_DIR/r_plot.log"
            PLOT_FILE="N/A"
        }
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico. Instale R, por ejemplo: 'sudo apt install r-base'."
    PLOT_FILE="N/A"
fi

run_step 4 clipon-ngs INPUT_DIR="$FILTER_DIR" OUTPUT_DIR="$CLUSTER_DIR" bash scripts/De2_A2.5_NGSpecies_Clustering.sh
run_step 5 clipon-ngs BASE_DIR="$CLUSTER_DIR" OUTPUT_DIR="$UNIFIED_DIR" bash scripts/De2.5_A3_NGSpecies_Unificar_Clusters.sh

if [ ! -s "$UNIFIED_DIR/consensos_todos.fasta" ]; then
    echo "No se creó el archivo maestro de consensos. Abortando pipeline."
    exit 1
fi

run_step 6 clipon-qiime classify_reads
run_step 7 clipon-qiime bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/MaxAc_5"

TAX_PLOT_FILE="N/A"
if command -v Rscript >/dev/null 2>&1; then
    TAX_PLOT_FILE=$(Rscript scripts/plot_taxon_bar.R \
        "$UNIFIED_DIR/MaxAc_5/taxonomy_with_sample.tsv" \
        "$UNIFIED_DIR/MaxAc_5/taxon_stacked_bar.png" 2>&1 | tee -a "$WORK_DIR/r_plot.log" | tail -n 1) || {
            echo "Fallo en Rscript: revisar dependencias" >> "$WORK_DIR/r_plot.log"
            TAX_PLOT_FILE="N/A"
        }
    read -p "¿Abrir el gráfico ahora? [y/N]: " OPEN_TAX_PLOT
    if [[ $OPEN_TAX_PLOT =~ ^[Yy]$ && -f "$TAX_PLOT_FILE" ]]; then
        xdg-open "$TAX_PLOT_FILE"
    else
        echo "Gráfico de taxones disponible en: $TAX_PLOT_FILE"
    fi
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico de taxones. Instale R, por ejemplo: 'sudo apt install r-base'."
fi

echo -e "\nResumen de lecturas por etapa:"
python3 scripts/summarize_read_counts.py "$WORK_DIR"
echo "Pipeline completado. Resultados en: $WORK_DIR"
echo "Gráfico de calidad vs longitud: $PLOT_FILE"
