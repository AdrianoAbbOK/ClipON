#!/usr/bin/env bash
set -euo pipefail

# Función auxiliar para solicitar parámetros con un valor por defecto
prompt_param() {
    local var_name="$1"
    local friendly="$2"
    local default="$3"
    local value
    read -p "$friendly PREDETERMINADO = [$default]: " value
    value=${value:-$default}
    eval "$var_name=\"$value\""
    echo "$friendly ELEGIDO : $value"
}

print_section() {
    echo "========================================================="
    echo "$1"
    echo "========================================================="
}

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

# Elegir entre procesamiento nuevo o reanudación antes de configurar directorios
read -rp "¿Desea iniciar un procesamiento nuevo o reanudar uno previo? (n/r) " run_mode
if [[ $run_mode =~ ^[Rr]$ ]]; then
    MODE="resume"
else
    MODE="new"
fi

echo "========================================================="
echo "Configuración de directorios y bases de datos"
echo "========================================================="

if [ "$MODE" = "resume" ]; then
    while true; do
        read -rp "Ingrese el directorio de trabajo existente: " WORK_DIR
        WORK_DIR="${WORK_DIR%/}"
        if [ ! -d "$WORK_DIR" ]; then
            echo "El directorio '$WORK_DIR' no existe o no es accesible. Intente nuevamente."
            continue
        fi
        break
    done
    # Permitir sobrescribir o copiar el directorio de trabajo
    while true; do
        read -rp "¿Desea sobrescribir el directorio de trabajo o copiar los datos a uno nuevo? (s/c) " copy_choice
        if [[ $copy_choice =~ ^[Cc]$ ]]; then
            read -rp "Ingrese la ruta del nuevo directorio de trabajo: " NEW_WORK_DIR
            NEW_WORK_DIR="${NEW_WORK_DIR%/}"
            mkdir -p "$NEW_WORK_DIR"
            rsync -a "$WORK_DIR/" "$NEW_WORK_DIR/"
            WORK_DIR="$NEW_WORK_DIR"
            break
        elif [[ $copy_choice =~ ^[Ss]$ ]]; then
            break
        else
            echo "Respuesta no válida. Intente nuevamente."
        fi
    done
    scripts/check_pipeline_status.sh "$WORK_DIR"
    read -rp "Seleccione el paso de reanudación: " RESUME_STEP
    echo "export RESUME_STEP=\"$RESUME_STEP\"" > "$WORK_DIR/resume_config.sh"
    source "$WORK_DIR/resume_config.sh"
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
    while true; do
        read -rp "Ingrese el directorio de trabajo donde se guardarán los resultados: " WORK_DIR
        WORK_DIR="${WORK_DIR%/}"
        if [ -d "$WORK_DIR" ] && [ "$(ls -A "$WORK_DIR")" ]; then
            read -rp "El directorio '$WORK_DIR' ya existe y contiene archivos. ¿Desea sobrescribirlo? (s/n) " overwrite
            if [[ $overwrite =~ ^[Ss]$ ]]; then
                rm -rf "$WORK_DIR"
                mkdir -p "$WORK_DIR"
                break
            else
                continue
            fi
        else
            mkdir -p "$WORK_DIR"
            break
        fi
    done
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
echo "Configuración de parametros para el procesamiento"
echo "-->Aparecerá la variable y el valor estandarizado:"
echo "-->Modifique con un valor nuevo o presione enter para mantener el valor estandar"
echo "========================================================="

print_section "Paso 2: Recorte de secuencias"

read -rp "¿Desea recortar las secuencias con cutadapt? (y/n) " do_trim
DEFAULT_TRIM_FRONT=0
DEFAULT_TRIM_BACK=0
if [[ $do_trim =~ ^[Yy]$ ]]; then
    prompt_param TRIM_FRONT "Número de bases a recortar del inicio" "$DEFAULT_TRIM_FRONT"
    prompt_param TRIM_BACK "Número de bases a recortar del final" "$DEFAULT_TRIM_BACK"
    SKIP_TRIM=0
else
    SKIP_TRIM=1
    TRIM_FRONT=$DEFAULT_TRIM_FRONT
    TRIM_BACK=$DEFAULT_TRIM_BACK
fi

print_section "Paso 3: Filtrado con NanoFilt"
DEFAULT_MIN_LEN=650
DEFAULT_MAX_LEN=750
DEFAULT_MIN_QUAL=10
prompt_param MIN_LEN "  Longitud mínima" "$DEFAULT_MIN_LEN"
prompt_param MAX_LEN "  Longitud máxima" "$DEFAULT_MAX_LEN"
prompt_param MIN_QUAL "  Calidad mínima" "$DEFAULT_MIN_QUAL"

print_section "Paso 4: Clustering de NGSpecies"
DEFAULT_M_LEN=700
DEFAULT_SUPPORT=150
DEFAULT_THREADS=16
DEFAULT_QUAL=10
DEFAULT_RC_ID=0.98
DEFAULT_ABUND_RATIO=0.01
prompt_param M_LEN "  Longitud esperada del consenso (--m)" "$DEFAULT_M_LEN"
prompt_param SUPPORT "  Número mínimo de lecturas de soporte (--s)" "$DEFAULT_SUPPORT"
prompt_param THREADS "  Número de hilos (--t)" "$DEFAULT_THREADS"
prompt_param QUAL "  Calidad mínima (--q)" "$DEFAULT_QUAL"
prompt_param RC_ID "  Umbral de identidad de RC (--rc_identity_threshold)" "$DEFAULT_RC_ID"
prompt_param ABUND_RATIO "  Proporción mínima de abundancia (--abundance_ratio)" "$DEFAULT_ABUND_RATIO"

print_section "Paso 6: Clasificación taxonómica"
DEFAULT_NUM_THREADS=5
DEFAULT_PERC_ID=0.8
DEFAULT_QUERY_COV=0.8
DEFAULT_MAX_ACCEPTS=1
DEFAULT_MIN_CONSENSUS=0.51
prompt_param NUM_THREADS "  Número de hilos (--p-num-threads)" "$DEFAULT_NUM_THREADS"
prompt_param PERC_ID "  Identidad mínima (--p-perc-identity)" "$DEFAULT_PERC_ID"
prompt_param QUERY_COV "  Cobertura de consulta (--p-query-cov)" "$DEFAULT_QUERY_COV"
prompt_param MAX_ACCEPTS "  Máximos aceptados (--p-maxaccepts)" "$DEFAULT_MAX_ACCEPTS"
prompt_param MIN_CONSENSUS "  Consenso mínimo (--p-min-consensus)" "$DEFAULT_MIN_CONSENSUS"

echo "========================================================="
echo "Resumen de configuración"
echo "========================================================="
echo " *Directorios:"
echo "  Directorio FASTQ: $INPUT_DIR"
echo "  Directorio de trabajo: $WORK_DIR"
echo "  Base de datos BLAST: $BLAST_DB"
echo "  Base de datos de taxonomía: $TAXONOMY_DB"
if [ "$MODE" = "resume" ]; then
    echo "  Reanudación desde el paso: $RESUME_STEP"
fi
echo " *Recorte de secuencias"
if [ "$SKIP_TRIM" -eq 1 ]; then
    echo "  Sin recorte"
else
    echo "  Recorte en -$TRIM_FRONT y +$TRIM_BACK"
fi
echo " *Filtro NanoFilt: longitudes $MIN_LEN-$MAX_LEN, calidad mínima $MIN_QUAL"
echo " *NGSpeciesID:"
echo "    Longitud esperada del consenso: $M_LEN"
echo "    Lecturas de soporte: $SUPPORT"
echo "    Hilos: $THREADS"
echo "    Calidad mínima: $QUAL"
echo "    RC identidad: $RC_ID"
echo "    Proporción mínima de abundancia: $ABUND_RATIO"
echo " *Clasificación BLAST:"
echo "    Número de hilos: $NUM_THREADS"
echo "    Identidad mínima: $PERC_ID"
echo "    Cobertura de consulta: $QUERY_COV"
echo "    Máximos aceptados: $MAX_ACCEPTS"
echo "    Consenso mínimo: $MIN_CONSENSUS"
echo "========================================================="
read -rp "¿Continuar con la ejecución del pipeline? (y/n) " go
if [[ ! $go =~ ^[Yy]$ ]]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi
echo "========================================================="
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

        if command -v chafa >/dev/null 2>&1; then
            # Mostrar el gráfico en la terminal usando chafa
            chafa "$PLOT_FILE" | less -R
        else
            echo "Instale 'chafa' para visualizar el gráfico en la terminal. Archivo: $PLOT_FILE"
        fi

    else
        echo "No se pudo abrir el gráfico automáticamente."
    fi
else
    echo "Rscript no encontrado; omitiendo la generación del gráfico. Instale R, por ejemplo: 'sudo apt install r-base'."
    PLOT_FILE="N/A"
    echo "Gráfico de calidad vs longitud: $PLOT_FILE"
fi

echo "El gráfico se encuentra en: $PLOT_FILE"
read -rp "Revise el gráfico y presione 's' para continuar o cualquier otra tecla para abortar: " RESP
[[ $RESP =~ ^[Ss]$ ]] || { echo "Pipeline abortado."; exit 0; }

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

print_section "Paso 6: Clasificación taxonómica"
run_step 6 clipon-qiime classify_reads

print_section "Paso 7: Exportación de clasificación"
run_step 7 clipon-qiime bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/MaxAc_5"

print_section "Gráfico de taxones"
TAX_PLOT_FILE="N/A"
if command -v python >/dev/null 2>&1; then
    TAX_PLOT_FILE=$(python scripts/plot_taxon_bar.py \
        "$UNIFIED_DIR/MaxAc_5/taxonomy_with_sample.tsv" \
        "$UNIFIED_DIR/MaxAc_5/taxon_stacked_bar.png" 2>&1 | \
        tee -a "$WORK_DIR/taxon_plot.log" | tail -n 1) || {
            echo "Fallo en python: revisar dependencias" >> "$WORK_DIR/taxon_plot.log"
            TAX_PLOT_FILE="N/A"
        }
    if [ -f "$TAX_PLOT_FILE" ] && [ "$TAX_PLOT_FILE" != "N/A" ]; then

        if command -v chafa >/dev/null 2>&1; then
            # Visualizar el gráfico de taxones en la terminal
            chafa "$TAX_PLOT_FILE" | less -R
        else
            echo "Instale 'chafa' para visualizar el gráfico en la terminal. Archivo: $TAX_PLOT_FILE"
        fi

    else
        echo "Gráfico de taxones disponible en: $TAX_PLOT_FILE"
    fi
else
    echo "Python no encontrado; omitiendo la generación del gráfico de taxones."
fi

print_section "Lecturas por especie"
python3 scripts/collapse_reads_by_species.py \
    "$UNIFIED_DIR/MaxAc_5/taxonomy_with_sample.tsv" \
    | tee "$UNIFIED_DIR/MaxAc_5/reads_per_species.tsv"
echo "La tabla y el resto de resultados se guardaron en $UNIFIED_DIR/MaxAc_5"

echo "Pipeline completado. Resultados en: $WORK_DIR"
echo "Gráfico de calidad vs longitud: $PLOT_FILE"
