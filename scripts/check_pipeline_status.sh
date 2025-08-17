#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <dir_trabajo>" >&2
    exit 1
fi

WORK_DIR="$1"

STEPS=(
    "Procesamiento inicial (SeqKit)"
    "Recorte de secuencias (Cutadapt)"
    "Filtrado de calidad/longitud (NanoFilt)"
    "Clusterizado (NGSpeciesID)"
    "Unificación de clusters"
    "Clasificación (QIIME2)"
    "Exportación de resultados"
)

MARKERS=(
    "$WORK_DIR/1_processed/*.fastq"
    "$WORK_DIR/2_trimmed/*.fastq"
    "$WORK_DIR/3_filtered/*.fastq"
    "$WORK_DIR/4_clustered/*"
    "$WORK_DIR/5_unified/consensos_todos.fasta"
    "$WORK_DIR/5_unified/taxonomy.qza"
    "$WORK_DIR/5_unified/Results"
)

echo "Comprobando estado del pipeline en $WORK_DIR"
for i in "${!STEPS[@]}"; do
    num=$((i+1))
    marker=${MARKERS[$i]}
    shopt -s nullglob
    files=( $marker )
    shopt -u nullglob
    if [ ${#files[@]} -gt 0 ]; then
        status="COMPLETADO"
    else
        status="PENDIENTE"
    fi
    echo "[$num] ${STEPS[$i]}: $status"
done

read -rp "Ingrese el número del paso desde el cual desea reanudar: " choice
if ! [[ "$choice" =~ ^[1-7]$ ]]; then
    echo "Elección inválida" >&2
    exit 1
fi

config_file="$WORK_DIR/resume_config.sh"
echo "export RESUME_STEP=$choice" > "$config_file"
chmod +x "$config_file"
echo "Configuración guardada en $config_file"
echo "Para reanudar ejecute: source \"$config_file\" && scripts/run_clipon_pipeline.sh <dir_fastq_entrada> \"$WORK_DIR\""
