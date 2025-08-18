#!/usr/bin/env bash
set -euo pipefail

# Wrapper para ejecutar la cadena completa de procesamiento de ClipON
# Uso: ./run_clipon_pipeline.sh [--metadata <archivo>] [--cluster-method <ngspecies|vsearch>] <dir_fastq_entrada> <dir_trabajo>
# El directorio de trabajo contendrá subcarpetas para cada etapa

# Para un gráfico avanzado de la calidad de lectura combine los TSV generados en cada etapa (collect_read_stats.py):
# Rscript scripts/read_quality_poster.R "ruta/etapa1.tsv,ruta/etapa2.tsv" salida.png


# Determinar la raíz del repositorio y usar rutas relativas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Inicializar conda y activar entornos según la etapa
if command -v conda >/dev/null 2>&1; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    CONDA_AVAILABLE=1
else
    echo "Advertencia: conda no está disponible; continuando sin entornos." >&2
    CONDA_AVAILABLE=0
fi

CLUSTER_METHOD="${CLUSTER_METHOD:-ngspecies}"
METADATA_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --metadata)
            METADATA_FILE="${2:-}"
            shift 2
            ;;
        --cluster-method)
            CLUSTER_METHOD="${2:-ngspecies}"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 [--metadata <archivo>] [--cluster-method <ngspecies|vsearch>] <dir_fastq_entrada> <dir_trabajo>"
    exit 1
fi

INPUT_DIR="${1%/}"
WORK_DIR="${2%/}"

# Configuración opcional para el recorte
SKIP_TRIM="${SKIP_TRIM:-0}"
TRIM_FRONT="${TRIM_FRONT:-30}"
TRIM_BACK="${TRIM_BACK:-30}"
RESUME_STEP="${RESUME_STEP:-1}"
CLUSTER_METHOD="${CLUSTER_METHOD:-ngspecies}"

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

    if [ "$CONDA_AVAILABLE" -eq 1 ]; then
        conda activate "$env"
    fi
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
    echo "Clasificación finalizada. Revise $UNIFIED_DIR/Results"
}

cluster_with_vsearch() {
    scripts/generate_manifest.sh --filtered "$FILTER_DIR" > "$FILTER_DIR/manifest.csv"
    scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh "$FILTER_DIR/manifest.csv" "$VSEARCH_PREFIX" "$DIRDB" "$EMAIL" "$CLUSTER_ID" "$BLAST_ID" "$MAX_ACCEPTS"
    cp "$VSEARCH_PREFIX"/taxonomy.qza "$UNIFIED_DIR/taxonomy.qza"
    cp "$VSEARCH_PREFIX"/search_results.qza "$UNIFIED_DIR/search_results.qza"
}

run_step 1 clipon-prep INPUT_DIR="$INPUT_DIR" OUTPUT_DIR="$PROCESSED_DIR" bash scripts/De0_A1_Process_Fastq.4_SeqKit.sh
run_step 2 clipon-prep trim_reads
run_step 3 clipon-prep INPUT_DIR="$TRIM_DIR" OUTPUT_DIR="$FILTER_DIR" LOG_FILE="$LOG_FILE" bash scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh

echo -e "\nResumen de lecturas tras filtrado:"
python3 scripts/summarize_read_counts.py "$WORK_DIR" ${METADATA_FILE:+--metadata "$METADATA_FILE"}

# Generar gráfico de calidad vs longitud para múltiples etapas
# Se captura solo la última línea para obtener la ruta del archivo generado
if command -v Rscript >/dev/null 2>&1; then
    PLOT_FILE=$(Rscript scripts/plot_quality_vs_length_multi.R \
        "$FILTER_DIR/read_quality_vs_length.png" \
        ${METADATA_FILE:+--metadata "$METADATA_FILE"} \
        "$PROCESSED_DIR"/*_processed_stats.tsv \
        "$FILTER_DIR"/*_filtered_stats.tsv 2>&1 | tee "$WORK_DIR/r_plot.log" | tail -n 1) || {
            echo "Fallo en Rscript: revisar dependencias" >> "$WORK_DIR/r_plot.log"
            PLOT_FILE="N/A"
        }
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico. Instale R, por ejemplo: 'sudo apt install r-base'."
    PLOT_FILE="N/A"
fi

echo "Gráfico de calidad vs longitud: $PLOT_FILE"

if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
    run_step 4 clipon-ngs INPUT_DIR="$FILTER_DIR" OUTPUT_DIR="$CLUSTER_DIR" \
        bash scripts/De2_A2.5_NGSpecies_Clustering.sh
    run_step 5 clipon-ngs BASE_DIR="$CLUSTER_DIR" OUTPUT_DIR="$UNIFIED_DIR" \
        bash scripts/De2.5_A3_NGSpecies_Unificar_Clusters.sh

    if [ ! -s "$UNIFIED_DIR/consensos_todos.fasta" ]; then
        echo "No se creó el archivo maestro de consensos. Abortando pipeline."

        exit 1
        ;;
esac
run_step 7 clipon-qiime METADATA_FILE="$METADATA_FILE" bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"


    run_step 6 clipon-qiime classify_reads
    run_step 7 clipon-qiime METADATA_FILE="$METADATA_FILE" \
        bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"
elif [ "$CLUSTER_METHOD" = "vsearch" ]; then
    MANIFEST_FILE="$WORK_DIR/manifest_vsearch.csv"
    scripts/generate_manifest.sh --filtered "$FILTER_DIR" > "$MANIFEST_FILE"

    if command -v qiime >/dev/null 2>&1 && \
        [ -n "${BLAST_DB:-}" ] && [ -n "${TAXONOMY_DB:-}" ]; then
        run_step 4 clipon-qiime bash scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh \
            --manifest "$MANIFEST_FILE" \
            --output-dir "$UNIFIED_DIR" \
            --cluster-id "${CLUSTER_IDENTITY:-0.98}" \
            --blast-id "${BLAST_IDENTITY:-0.5}" \
            --maxaccepts "${MAXACCEPTS:-5}"
        run_step 5 clipon-qiime METADATA_FILE="$METADATA_FILE" \
            bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"
    else
        echo "Advertencia: dependencias de vsearch no disponibles; " \
            "creando taxonomy.qza ficticio." >&2
        touch "$UNIFIED_DIR/taxonomy.qza" "$UNIFIED_DIR/search_results.qza"
    fi
else
    echo "Método de clusterización '$CLUSTER_METHOD' no soportado en run_clipon_pipeline.sh" >&2
    exit 1
fi

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/Results"

TAX_PLOT_FILE="N/A"
if command -v python >/dev/null 2>&1; then
    COLLAPSED_TAX="$UNIFIED_DIR/Results/species_reads.tsv"
    python scripts/collapse_reads_by_species.py \
        "$UNIFIED_DIR/Results/taxonomy_with_sample.tsv" > "$COLLAPSED_TAX"
    TAX_PLOT_FILE=$(python scripts/plot_taxon_bar.py \
        "$COLLAPSED_TAX" \
        "$UNIFIED_DIR/Results/taxon_stacked_bar.png" \
        ${METADATA_FILE:+--metadata "$METADATA_FILE"} --code-samples 2>&1 | \
        tee -a "$WORK_DIR/taxon_plot.log" | tail -n 1) || {
            echo "Fallo en python: revisar dependencias" >> "$WORK_DIR/taxon_plot.log"
            TAX_PLOT_FILE="N/A"
        }
    read -p "¿Abrir el gráfico ahora? [y/N]: " OPEN_TAX_PLOT
    if [[ $OPEN_TAX_PLOT =~ ^[Yy]$ && -f "$TAX_PLOT_FILE" ]]; then
        xdg-open "$TAX_PLOT_FILE"
    else
        echo "Gráfico de taxones disponible en: $TAX_PLOT_FILE"
    fi
else
    echo "Python no encontrado; omitiendo la generación del gráfico de taxones."
fi

echo "Pipeline completado. Resultados en: $WORK_DIR"
echo "Gráfico de calidad vs longitud: $PLOT_FILE"
