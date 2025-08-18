#!/usr/bin/env bash
set -euo pipefail

# Parámetro opcional para pasar metadata de FASTQ a experimento
METADATA_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --metadata)
            METADATA_FILE="${2:-}"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# Función auxiliar para solicitar parámetros con un valor por defecto
prompt_param() {
    local var_name="$1"
    local friendly="$2"
    local default="$3"
    local value
    read -r -p "$friendly PREDETERMINADO = [$default]: " value
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
    RESUME_STEP=1
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
    # Leer RESUME_STEP desde el archivo generado por check_pipeline_status.sh
    # shellcheck source=/dev/null
    source "$WORK_DIR/resume_config.sh"
fi

INPUT_DIR="N/A"
if [ "$MODE" = "new" ] || [ "${RESUME_STEP:-1}" -le 1 ]; then
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
fi

# Solicitar archivo de metadata después de los FASTQ si no se proporcionó
# por argumento
if [ -z "$METADATA_FILE" ]; then
    while true; do
        read -rp "Ingrese la ruta del archivo de metadata (Enter para omitir): " METADATA_FILE
        if [ -z "$METADATA_FILE" ]; then
            break
        elif [ -f "$METADATA_FILE" ]; then
            break
        else
            echo "El archivo '$METADATA_FILE' no existe. Intente nuevamente."
        fi
    done
fi

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

while true; do
    read -rp "¿Qué método de clusterización desea usar? (ngspecies/vsearch) " CLUSTER_METHOD
    CLUSTER_METHOD=${CLUSTER_METHOD,,}
    if [[ "$CLUSTER_METHOD" == "ngspecies" || "$CLUSTER_METHOD" == "vsearch" ]]; then
        export CLUSTER_METHOD
        break
    fi
    echo "Opción no válida. Escriba 'ngspecies' o 'vsearch'."
done

if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
    read -rp "¿Desea usar todos los parámetros predeterminados optimizados para COI-FishMock? (s/n) " use_defaults
    if [[ $use_defaults =~ ^[Ss]$ ]]; then
        USE_DEFAULTS=1
    else
        USE_DEFAULTS=0
    fi
else
    USE_DEFAULTS=0
fi

if [ "$USE_DEFAULTS" -eq 0 ]; then
    echo "========================================================="
    echo "Configuración de parametros para el procesamiento"
    echo "-->Aparecerá la variable y el valor estandarizado:"
    echo "-->Modifique con un valor nuevo o presione enter para mantener el valor estandar"
    echo "========================================================="

    if [ "${RESUME_STEP:-1}" -le 2 ]; then
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
    else
        SKIP_TRIM=1
        TRIM_FRONT=0
        TRIM_BACK=0
    fi

    if [ "${RESUME_STEP:-1}" -le 3 ]; then
        print_section "Paso 3: Filtrado con NanoFilt"
        DEFAULT_MIN_LEN=650
        DEFAULT_MAX_LEN=750
        DEFAULT_MIN_QUAL=10
        prompt_param MIN_LEN "  Longitud mínima" "$DEFAULT_MIN_LEN"
        prompt_param MAX_LEN "  Longitud máxima" "$DEFAULT_MAX_LEN"
        prompt_param MIN_QUAL "  Calidad mínima" "$DEFAULT_MIN_QUAL"
    else
        MIN_LEN=650
        MAX_LEN=750
        MIN_QUAL=10
    fi

    if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
        if [ "${RESUME_STEP:-1}" -le 4 ]; then
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
        else
            M_LEN=700
            SUPPORT=150
            THREADS=16
            QUAL=10
            RC_ID=0.98
            ABUND_RATIO=0.01
        fi

        if [ "${RESUME_STEP:-1}" -le 6 ]; then
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
        else
            NUM_THREADS=5
            PERC_ID=0.8
            QUERY_COV=0.8
            MAX_ACCEPTS=1
            MIN_CONSENSUS=0.51
        fi
    else
        print_section "Paso 4: Clustering con VSearch"
        DEFAULT_CLUSTER_IDENTITY=0.98
        DEFAULT_BLAST_IDENTITY=0.5
        DEFAULT_MAXACCEPTS=5
        prompt_param CLUSTER_IDENTITY "  Identidad de clustering (--p-perc-identity)" "$DEFAULT_CLUSTER_IDENTITY"
        prompt_param BLAST_IDENTITY "  Identidad de BLAST (--p-perc-identity)" "$DEFAULT_BLAST_IDENTITY"
        prompt_param MAXACCEPTS "  Máximos aceptados (--p-maxaccepts)" "$DEFAULT_MAXACCEPTS"
    fi

    print_section "Parámetros avanzados (opcional)"
    if [ "${RESUME_STEP:-1}" -le 2 ]; then
        read -rp "¿Agregar parámetros avanzados al recorte? (s/n) " resp
        if [[ $resp =~ ^[Ss]$ ]]; then
            read -rp "  Parámetros para recorte: " TRIM_EXTRA_ARGS
        fi
    fi
    if [ "${RESUME_STEP:-1}" -le 3 ]; then
        read -rp "¿Agregar parámetros avanzados al filtrado? (s/n) " resp
        if [[ $resp =~ ^[Ss]$ ]]; then
            read -rp "  Parámetros para filtrado: " FILTER_EXTRA_ARGS
        fi
    fi
    if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
        if [ "${RESUME_STEP:-1}" -le 4 ]; then
            read -rp "¿Agregar parámetros avanzados al clustering? (s/n) " resp
            if [[ $resp =~ ^[Ss]$ ]]; then
                read -rp "  Parámetros para clustering: " CLUSTER_EXTRA_ARGS
            fi
        fi
        if [ "${RESUME_STEP:-1}" -le 6 ]; then
            read -rp "¿Agregar parámetros avanzados a la clasificación? (s/n) " resp
            if [[ $resp =~ ^[Ss]$ ]]; then
                read -rp "  Parámetros para clasificación: " CLASSIFY_EXTRA_ARGS
            fi
        fi
    fi
else
    echo "Usando parámetros predeterminados para COI-FishMock."
    SKIP_TRIM=1
    TRIM_FRONT=0
    TRIM_BACK=0
    MIN_LEN=650
    MAX_LEN=750
    MIN_QUAL=10
    M_LEN=700
    SUPPORT=150
    THREADS=16
    QUAL=10
    RC_ID=0.98
    ABUND_RATIO=0.01
    NUM_THREADS=5
    PERC_ID=0.8
    QUERY_COV=0.8
    MAX_ACCEPTS=1
    MIN_CONSENSUS=0.51
    TRIM_EXTRA_ARGS=""
    FILTER_EXTRA_ARGS=""
    CLUSTER_EXTRA_ARGS=""
    CLASSIFY_EXTRA_ARGS=""
fi

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
echo " *Método de clustering: $CLUSTER_METHOD"
if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
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
else
    echo " *VSearch:"
    echo "    cluster_identity: $CLUSTER_IDENTITY"
    echo "    blast_identity: $BLAST_IDENTITY"
    echo "    maxaccepts: $MAXACCEPTS"
fi
echo " *Parámetros avanzados:"
echo "    Recorte: ${TRIM_EXTRA_ARGS:-ninguno}"
echo "    Filtrado: ${FILTER_EXTRA_ARGS:-ninguno}"
echo "    Clustering: ${CLUSTER_EXTRA_ARGS:-ninguno}"
if [ "$CLUSTER_METHOD" = "ngspecies" ]; then
    echo "    Clasificación: ${CLASSIFY_EXTRA_ARGS:-ninguno}"
fi
echo "========================================================="
read -rp "¿Continuar con la ejecución del pipeline? (y/n) " go
if [[ ! $go =~ ^[Yy]$ ]]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi
echo "========================================================="
echo "Iniciando pipeline..."
CLUSTER_IDENTITY=${CLUSTER_IDENTITY:-}
BLAST_IDENTITY=${BLAST_IDENTITY:-}
MAXACCEPTS=${MAXACCEPTS:-}

export SKIP_TRIM TRIM_FRONT TRIM_BACK MIN_LEN MAX_LEN MIN_QUAL \
    M_LEN SUPPORT THREADS QUAL RC_ID ABUND_RATIO \
    NUM_THREADS PERC_ID QUERY_COV MAX_ACCEPTS MIN_CONSENSUS \
    TRIM_EXTRA_ARGS FILTER_EXTRA_ARGS CLUSTER_EXTRA_ARGS CLASSIFY_EXTRA_ARGS \
    CLUSTER_METHOD CLUSTER_IDENTITY BLAST_IDENTITY MAXACCEPTS RESUME_STEP

cmd=("scripts/run_clipon_pipeline.sh")
if [ -n "$METADATA_FILE" ]; then
    cmd+=(--metadata "$METADATA_FILE")
fi
cmd+=("$INPUT_DIR" "$WORK_DIR")

run_step 4 clipon-ngs "Paso 4: Clustering de NGSpecies" "$CLUSTER_EXTRA_ARGS" \
    M_LEN="$M_LEN" SUPPORT="$SUPPORT" THREADS="$THREADS" \
    QUAL="$QUAL" RC_ID="$RC_ID" ABUND_RATIO="$ABUND_RATIO" \
    INPUT_DIR="$FILTER_DIR" OUTPUT_DIR="$CLUSTER_DIR" \
    bash scripts/De2_A2.5_NGSpecies_Clustering.sh

run_step 5 clipon-ngs "Paso 5: Unificación de clusters" "" \
    BASE_DIR="$CLUSTER_DIR" OUTPUT_DIR="$UNIFIED_DIR" \
    bash scripts/De2.5_A3_NGSpecies_Unificar_Clusters.sh

if [ ! -s "$UNIFIED_DIR/consensos_todos.fasta" ]; then
    echo "No se creó el archivo maestro de consensos. Abortando pipeline."
    exit 1
fi

run_step 6 clipon-qiime "Paso 6: Clasificación taxonómica" "$CLASSIFY_EXTRA_ARGS" classify_reads

run_step 7 clipon-qiime "Paso 7: Exportación de clasificación" "" \
    METADATA_FILE="$METADATA_FILE" bash scripts/De3_A4_Export_Classification.sh "$UNIFIED_DIR"

echo "Clasificación y exportación finalizadas. Revise $UNIFIED_DIR/Results"

print_section "Gráfico de taxones"
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
    if [ -f "$TAX_PLOT_FILE" ] && [ "$TAX_PLOT_FILE" != "N/A" ]; then
        if command -v eog >/dev/null 2>&1; then
            # Abrir el gráfico de taxones en una ventana nueva
            eog "$TAX_PLOT_FILE" >/dev/null 2>&1 &
        elif command -v chafa >/dev/null 2>&1; then
            # Visualizar el gráfico de taxones en la terminal
            chafa "$TAX_PLOT_FILE" | less -R
        else
            echo "Instale 'eog' o 'chafa' para visualizar el gráfico."
        fi
    else
        echo "No se pudo generar el gráfico de taxones. Revise $WORK_DIR/taxon_plot.log"
    fi
else
    echo "Python no encontrado; omitiendo la generación del gráfico de taxones."
fi
echo "Gráfico de taxones disponible en: $TAX_PLOT_FILE"

print_section "Lecturas por especie"
python3 scripts/collapse_reads_by_species.py \
    "$UNIFIED_DIR/Results/taxonomy_with_sample.tsv" \
    | tee "$UNIFIED_DIR/Results/reads_per_species.tsv"
echo "La tabla y el resto de resultados se guardaron en $UNIFIED_DIR/Results"

echo "Pipeline completado. Resultados en: $WORK_DIR"
echo "Gráfico de calidad vs longitud: $PLOT_FILE"

"${cmd[@]}"
