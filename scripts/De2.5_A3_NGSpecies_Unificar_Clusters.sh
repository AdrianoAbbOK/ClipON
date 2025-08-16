#!/bin/bash
set -e
set -u
set -o pipefail

# Uso:
#   BASE_DIR=/ruta/a/clustered OUTPUT_DIR=/ruta/a/unificado ./De2.5_A3_NGSpecies_Unificar_Clusters.sh
#   o: ./De2.5_A3_NGSpecies_Unificar_Clusters.sh <dir_base> <dir_salida>

# Directorio base donde están las carpetas y de salida
BASE_DIR="${BASE_DIR:-$1}"
DIR_SALIDA="${OUTPUT_DIR:-$2}"

if [ -z "$BASE_DIR" ] || [ -z "$DIR_SALIDA" ]; then
    echo "Uso: BASE_DIR=<dir base> OUTPUT_DIR=<dir salida> $0"
    echo "   o: $0 <dir base> <dir salida>"
    exit 1
fi

# Crear el directorio de salida si no existe
mkdir -p "$DIR_SALIDA"

# Archivo maestro que contendrá todas las secuencias con el identificador de experimento
archivo_maestro="$DIR_SALIDA/consensos_todos.fasta"
> "$archivo_maestro"

# Inicializar una variable para verificar si se han procesado secuencias
se_agregaron_secuencias=false

# Recorrer todas las carpetas dentro del directorio base
for carpeta in "$BASE_DIR"/*; do
  if [ -d "$carpeta" ]; then
    # Extraer el nombre de la carpeta
    nombre_carpeta=$(basename "$carpeta")

    # Usar el nombre completo de la carpeta como identificador de muestra

    identificador="$nombre_carpeta"

    # Archivo de salida individual
    archivo_salida="$DIR_SALIDA/consensos_${identificador}.fasta"

    # Inicializar el archivo individual vacío
    > "$archivo_salida"

    # Unificar los archivos .fasta dentro de la carpeta y modificar los IDs
    for fasta in "$carpeta"/consensus_reference_*.fasta; do
      [ -f "$fasta" ] || continue
      awk -v id="$identificador" '/^>/ {print $0 "_" id} !/^>/ {print $0}' "$fasta" >> "$archivo_salida"
    done

    # Verificar si el archivo individual no está vacío
    if [ -s "$archivo_salida" ]; then
      echo "Se creó el archivo: $archivo_salida"

      # Añadir las secuencias procesadas al archivo maestro
      cat "$archivo_salida" >> "$archivo_maestro"
      se_agregaron_secuencias=true
    else
      echo "No se encontraron secuencias en la carpeta: $carpeta"
      rm "$archivo_salida"  # Eliminar archivos vacíos
    fi
  fi
done

# Verificar si se agregaron secuencias al archivo maestro
if [ "$se_agregaron_secuencias" = true ]; then
  echo "Se creó el archivo maestro con todas las secuencias: $archivo_maestro"
else
  echo "No se encontraron secuencias en ninguna carpeta. No se creó el archivo maestro."
fi
