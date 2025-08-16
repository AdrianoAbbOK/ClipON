#!/bin/bash
set -euo pipefail

# Script interactivo para ejecutar el pipeline de ClipON paso a paso
# Nota: la extracción de longitudes y calidades por lectura ya se realiza con
# scripts/collect_read_stats.py

# Determinar la raíz del repositorio y usar rutas relativas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "========================================================="
echo "Bienvenido al asistente de ejecución de ClipON"
echo "Este script lo guiará para preparar e iniciar el pipeline."
echo "========================================================="
read -rp "Presione Enter para comenzar" _

# Verificar que los entornos requeridos funcionen correctamente
if ! scripts/test_envs.sh; then
    echo "Fallo en la verificación de entornos. Abortando."
    exit 1
fi
echo "========================================================="
echo "Configuración de directorios y bases de datos"
echo "========================================================="

# Elegir entre procesamiento nuevo o reanudación
read -rp "¿Desea iniciar un procesamiento nuevo o reanudar uno previo? (n/r) " run_mode
if [[ $run_mode =~ ^[Rr]$ ]]; then
    MODE="resume"
    while true; do
        read -rp "Ingrese el directorio de trabajo existente: " WORK_DIR
        WORK_DIR="${WORK_DIR%/}"
        if [ ! -d "$WORK_DIR" ]; then
            echo "El directorio '$WORK_DIR' no existe o no es accesible. Intente nuevamente."
            continue
        fi
        break
    done
    scripts/check_pipeline_status.sh "$WORK_DIR"
    read -rp "Seleccione el paso de reanudación: " RESUME_STEP
    echo "export RESUME_STEP=\"$RESUME_STEP\"" > "$WORK_DIR/resume_config.sh"
    source "$WORK_DIR/resume_config.sh"
else
    MODE="new"
fi

while true; do
    read -rp "Ingrese el directorio que contiene los archivos FASTQ: " INPUT_DIR
    INPUT_DIR="${INPUT_DIR%/}"
    if [ ! -d "$INPUT_DIR" ]; then
        echo "El directorio '$INPUT_DIR' no existe o no es accesible. Intente nuevamente."
        continue
    fi
    shopt -s nullglob
    fastqs=("$INPUT_DIR"/*.fastq "$INPUT_DIR"/*.fq)
    shopt -u nullglob
    if [ ${#fastqs[@]} -eq 0 ]; then
        echo "No se encontraron archivos FASTQ en '$INPUT_DIR'. Intente nuevamente."
        continue
    fi
    break
done

if [ "$MODE" = "new" ]; then
    read -rp "Ingrese el directorio de trabajo donde se guardarán los resultados: " WORK_DIR
    WORK_DIR="${WORK_DIR%/}"
    mkdir -p "$WORK_DIR"
fi

# Paso opcional de recorte de secuencias
read -rp "¿Desea recortar las secuencias con cutadapt? (y/n) " do_trim
DEFAULT_TRIM_FRONT=0
DEFAULT_TRIM_BACK=0
if [[ $do_trim =~ ^[Yy]$ ]]; then
    echo "Valores estándar: inicio ${DEFAULT_TRIM_FRONT} bases, final ${DEFAULT_TRIM_BACK} bases."
    read -p "¿Desea mantener estos valores? (y/n) " keep_defaults
    if [[ $keep_defaults =~ ^[Yy]$ ]]; then
        TRIM_FRONT=$DEFAULT_TRIM_FRONT
        TRIM_BACK=$DEFAULT_TRIM_BACK
    else
        read -p "Número de bases a recortar del inicio [${DEFAULT_TRIM_FRONT}]: " TRIM_FRONT
        TRIM_FRONT=${TRIM_FRONT:-$DEFAULT_TRIM_FRONT}
        read -p "Número de bases a recortar del final [${DEFAULT_TRIM_BACK}]: " TRIM_BACK
        TRIM_BACK=${TRIM_BACK:-$DEFAULT_TRIM_BACK}
    fi
    SKIP_TRIM=0
else
    SKIP_TRIM=1
    TRIM_FRONT=$DEFAULT_TRIM_FRONT
    TRIM_BACK=$DEFAULT_TRIM_BACK
fi

# Solicitar rutas para bases de datos necesarias
while true; do
    read -rp "Ingrese la ruta al archivo de base de datos BLAST (.qza): " BLAST_DB
    if [ ! -f "$BLAST_DB" ]; then
        echo "El archivo '$BLAST_DB' no existe. Intente nuevamente."
        continue
    fi
    export BLAST_DB
    break
done

while true; do
    read -rp "Ingrese la ruta al archivo de taxonomía (.qza): " TAXONOMY_DB
    if [ ! -f "$TAXONOMY_DB" ]; then
        echo "El archivo '$TAXONOMY_DB' no existe. Intente nuevamente."
        continue
    fi
    export TAXONOMY_DB
    break
done

echo "========================================================="
echo "Resumen de directorios"
echo "========================================================="
echo "  Directorio FASTQ: $INPUT_DIR"
echo "  Directorio de trabajo: $WORK_DIR"
if [ "$MODE" = "resume" ]; then
    echo "  Reanudación desde el paso: $RESUME_STEP"
fi
if [ "$SKIP_TRIM" -eq 1 ]; then
    echo "  Recorte: no"
else
    echo "  Recorte: sí (inicio $TRIM_FRONT, final $TRIM_BACK)"
fi
echo "  Base de datos BLAST: $BLAST_DB"
echo "  Base de datos de taxonomía: $TAXONOMY_DB"
read -rp "¿Continuar con la ejecución del pipeline? (y/n) " go
if [[ ! $go =~ ^[Yy]$ ]]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi

echo "Iniciando pipeline..."

source "$(conda info --base)/etc/profile.d/conda.sh"
RESUME_STEP="${RESUME_STEP:-1}"

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

print_section() {
    echo "========================================================="
    echo "$1"
    echo "========================================================="
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
    NUM_THREADS="$NUM_THREADS" PERC_ID="$PERC_ID" QUERY_COV="$QUERY_COV" \
    MAX_ACCEPTS="$MAX_ACCEPTS" MIN_CONSENSUS="$MIN_CONSENSUS" \
    bash scripts/De3_A4_Classify_NGS.sh \
        "$UNIFIED_DIR/consensos_todos.fasta" \
        "$UNIFIED_DIR" \
        "$BLAST_DB" \
        "$TAXONOMY_DB"
    echo "Clasificación finalizada. Revise $UNIFIED_DIR/MaxAc_5"
}

print_section "Paso 1: Procesamiento inicial de FASTQ"
run_step 1 clipon-prep INPUT_DIR="$INPUT_DIR" OUTPUT_DIR="$PROCESSED_DIR" bash scripts/De0_A1_Process_Fastq.4_SeqKit.sh

print_section "Paso 2: Recorte de secuencias"
run_step 2 clipon-prep trim_reads

DEFAULT_MIN_LEN=650
DEFAULT_MAX_LEN=750
DEFAULT_MIN_QUAL=10
echo "Valores estándar: longitud mínima ${DEFAULT_MIN_LEN} bp, máxima ${DEFAULT_MAX_LEN} bp, calidad mínima ${DEFAULT_MIN_QUAL}" 
read -p "¿Desea modificar estos valores? (y/n) " modify_filters
if [[ $modify_filters =~ ^[Yy]$ ]]; then
    read -p "Longitud mínima [${DEFAULT_MIN_LEN}]: " MIN_LEN
    MIN_LEN=${MIN_LEN:-$DEFAULT_MIN_LEN}
    read -p "Longitud máxima [${DEFAULT_MAX_LEN}]: " MAX_LEN
    MAX_LEN=${MAX_LEN:-$DEFAULT_MAX_LEN}
    read -p "Calidad mínima [${DEFAULT_MIN_QUAL}]: " MIN_QUAL
    MIN_QUAL=${MIN_QUAL:-$DEFAULT_MIN_QUAL}
else
    MIN_LEN=$DEFAULT_MIN_LEN
    MAX_LEN=$DEFAULT_MAX_LEN
    MIN_QUAL=$DEFAULT_MIN_QUAL
fi

print_section "Paso 3: Filtrado con NanoFilt"
run_step 3 clipon-prep MIN_LEN="$MIN_LEN" MAX_LEN="$MAX_LEN" MIN_QUAL="$MIN_QUAL" INPUT_DIR="$TRIM_DIR" OUTPUT_DIR="$FILTER_DIR" LOG_FILE="$LOG_FILE" bash scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh

echo -e "\nResumen de lecturas tras filtrado:"
python3 scripts/summarize_read_counts.py "$WORK_DIR"

print_section "Gráfico de calidad vs longitud"
if command -v Rscript >/dev/null 2>&1; then
    PLOT_FILE=$(Rscript scripts/plot_quality_vs_length_multi.R \
        "$FILTER_DIR/read_quality_vs_length.png" \
        "$PROCESSED_DIR"/*_processed_stats.tsv \
        "$FILTER_DIR"/*_filtered_stats.tsv 2>&1 | tee "$WORK_DIR/r_plot.log" | tail -n 1) || {
            echo "Fallo en Rscript: revisar dependencias" >> "$WORK_DIR/r_plot.log"
            PLOT_FILE="N/A"
        }
    echo "Gráfico de calidad vs longitud: $PLOT_FILE"
    if [ -f "$PLOT_FILE" ] && [ "$PLOT_FILE" != "N/A" ]; then
        Rscript -e "archivo <- '$PLOT_FILE'; if (.Platform\$OS.type=='unix') system2('xdg-open', archivo, wait=TRUE) else if (.Platform\$OS.type=='windows') shell.exec(archivo) else system2('open', archivo, wait=TRUE)"
    else
        echo "No se pudo abrir el gráfico automáticamente."
    fi
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico. Instale R, por ejemplo: 'sudo apt install r-base'."
    PLOT_FILE="N/A"
    echo "Gráfico de calidad vs longitud: $PLOT_FILE"
fi

# Configuración de parámetros para NGSpeciesID
DEFAULT_M_LEN=700
DEFAULT_SUPPORT=150
DEFAULT_THREADS=16
DEFAULT_QUAL=10
DEFAULT_RC_ID=0.98
DEFAULT_ABUND_RATIO=0.01

echo "Parámetros de NGSpeciesID:" 
echo "  Longitud esperada del consenso (--m): $DEFAULT_M_LEN"
echo "  Número mínimo de lecturas de soporte (--s): $DEFAULT_SUPPORT"
echo "  Número de hilos (--t): $DEFAULT_THREADS"
echo "  Calidad mínima (--q): $DEFAULT_QUAL"
echo "  Umbral de identidad de RC (--rc_identity_threshold): $DEFAULT_RC_ID"
echo "  Proporción mínima de abundancia (--abundance_ratio): $DEFAULT_ABUND_RATIO"
read -p "¿Desea modificar estos valores? (y/n) " modify_ngs
if [[ $modify_ngs =~ ^[Yy]$ ]]; then
    read -p "Longitud esperada del consenso [${DEFAULT_M_LEN}]: " M_LEN
    M_LEN=${M_LEN:-$DEFAULT_M_LEN}
    read -p "Número mínimo de lecturas de soporte [${DEFAULT_SUPPORT}]: " SUPPORT
    SUPPORT=${SUPPORT:-$DEFAULT_SUPPORT}
    read -p "Número de hilos [${DEFAULT_THREADS}]: " THREADS
    THREADS=${THREADS:-$DEFAULT_THREADS}
    read -p "Calidad mínima [${DEFAULT_QUAL}]: " QUAL
    QUAL=${QUAL:-$DEFAULT_QUAL}
    read -p "Umbral de identidad de RC [${DEFAULT_RC_ID}]: " RC_ID
    RC_ID=${RC_ID:-$DEFAULT_RC_ID}
    read -p "Proporción mínima de abundancia [${DEFAULT_ABUND_RATIO}]: " ABUND_RATIO
    ABUND_RATIO=${ABUND_RATIO:-$DEFAULT_ABUND_RATIO}
else
    M_LEN=$DEFAULT_M_LEN
    SUPPORT=$DEFAULT_SUPPORT
    THREADS=$DEFAULT_THREADS
    QUAL=$DEFAULT_QUAL
    RC_ID=$DEFAULT_RC_ID
    ABUND_RATIO=$DEFAULT_ABUND_RATIO
fi

print_section "Paso 4: Clustering de NGSpecies"
run_step 4 clipon-ngs \
    M_LEN="$M_LEN" SUPPORT="$SUPPORT" THREADS="$THREADS" \
    QUAL="$QUAL" RC_ID="$RC_ID" ABUND_RATIO="$ABUND_RATIO" \
    INPUT_DIR="$FILTER_DIR" OUTPUT_DIR="$CLUSTER_DIR" \
    bash scripts/De2_A2.5_NGSpecies_Clustering.sh

print_section "Paso 5: Unificación de clusters"
run_step 5 clipon-ngs BASE_DIR="$CLUSTER_DIR" OUTPUT_DIR="$UNIFIED_DIR" bash scripts/De2.5_A3_NGSpecies_Unificar_Clusters.sh

if [ ! -s "$UNIFIED_DIR/consensos_todos.fasta" ]; then
    echo "No se creó el archivo maestro de consensos. Abortando pipeline."
    exit 1
fi

# Configuración de parámetros para la clasificación BLAST
DEFAULT_NUM_THREADS=5
DEFAULT_PERC_ID=0.8
DEFAULT_QUERY_COV=0.8
DEFAULT_MAX_ACCEPTS=1
DEFAULT_MIN_CONSENSUS=0.51

echo "Parámetros de clasificación BLAST:"
echo "  Número de hilos (--p-num-threads): $DEFAULT_NUM_THREADS"
echo "  Identidad mínima (--p-perc-identity): $DEFAULT_PERC_ID"
echo "  Cobertura de consulta (--p-query-cov): $DEFAULT_QUERY_COV"
echo "  Máximos aceptados (--p-maxaccepts): $DEFAULT_MAX_ACCEPTS"
echo "  Consenso mínimo (--p-min-consensus): $DEFAULT_MIN_CONSENSUS"
read -p "¿Desea modificar estos valores? (y/n) " modify_class
if [[ $modify_class =~ ^[Yy]$ ]]; then
    read -p "Número de hilos [${DEFAULT_NUM_THREADS}]: " NUM_THREADS
    NUM_THREADS=${NUM_THREADS:-$DEFAULT_NUM_THREADS}
    read -p "Identidad mínima [${DEFAULT_PERC_ID}]: " PERC_ID
    PERC_ID=${PERC_ID:-$DEFAULT_PERC_ID}
    read -p "Cobertura de consulta [${DEFAULT_QUERY_COV}]: " QUERY_COV
    QUERY_COV=${QUERY_COV:-$DEFAULT_QUERY_COV}
    read -p "Máximos aceptados [${DEFAULT_MAX_ACCEPTS}]: " MAX_ACCEPTS
    MAX_ACCEPTS=${MAX_ACCEPTS:-$DEFAULT_MAX_ACCEPTS}
    read -p "Consenso mínimo [${DEFAULT_MIN_CONSENSUS}]: " MIN_CONSENSUS
    MIN_CONSENSUS=${MIN_CONSENSUS:-$DEFAULT_MIN_CONSENSUS}
else
    NUM_THREADS=$DEFAULT_NUM_THREADS
    PERC_ID=$DEFAULT_PERC_ID
    QUERY_COV=$DEFAULT_QUERY_COV
    MAX_ACCEPTS=$DEFAULT_MAX_ACCEPTS
    MIN_CONSENSUS=$DEFAULT_MIN_CONSENSUS
fi

print_section "Paso 6: Clasificación taxonómica"
run_step 6 clipon-qiime classify_reads

print_section "Paso 7: Exportación de clasificación"
run_step 7 clipon-qiime bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/MaxAc_5"

print_section "Gráfico de taxones"
TAX_PLOT_FILE="N/A"
if command -v Rscript >/dev/null 2>&1; then
    TAX_PLOT_FILE=$(Rscript scripts/plot_taxon_bar.R \
        "$UNIFIED_DIR/MaxAc_5/taxonomy_with_sample.tsv" \
        "$UNIFIED_DIR/MaxAc_5/taxon_stacked_bar.png" 2>&1 | tee -a "$WORK_DIR/r_plot.log" | tail -n 1) || {
            echo "Fallo en Rscript: revisar dependencias" >> "$WORK_DIR/r_plot.log"
            TAX_PLOT_FILE="N/A"
        }
    if [ -f "$TAX_PLOT_FILE" ] && [ "$TAX_PLOT_FILE" != "N/A" ]; then
        Rscript -e "archivo <- '$TAX_PLOT_FILE'; if (.Platform\$OS.type=='unix') system2('xdg-open', archivo, wait=TRUE) else if (.Platform\$OS.type=='windows') shell.exec(archivo) else system2('open', archivo, wait=TRUE)"
    else
        echo "Gráfico de taxones disponible en: $TAX_PLOT_FILE"
    fi
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico de taxones. Instale R, por ejemplo: 'sudo apt install r-base'."
fi

echo "Pipeline completado. Resultados en: $WORK_DIR"
echo "Gráfico de calidad vs longitud: $PLOT_FILE"
