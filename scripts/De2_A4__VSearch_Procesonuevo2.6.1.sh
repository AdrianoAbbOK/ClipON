#!/bin/bash
set -e
set -u

# Verificar que se han proporcionado los parámetros necesarios
if [ "$#" -ne 7 ]; then
    echo "Uso: $0 <manifest_file> <prefix> <dirDB> <email> <cluster_identity> <blast_identity> <maxaccepts>"
    exit 1
fi

manifest_file=$1
prefix=$2
dirDB=$3
email=$4
cluster_identity=$5
blast_identity=$6
maxaccepts=$7

# Controla el envío de notificaciones por correo; establezca en 0 para desactivar
EMAIL_NOTIFY="${EMAIL_NOTIFY:-1}"

# Parámetros personalizables fijos
blast_consensus="0.51"
blast_coverage="0.8"


# Directorio general
main_dir="${prefix}_Cl${cluster_identity}_Bl${blast_identity}_MA${maxaccepts}"
mkdir -p "$main_dir"

# Directorios de salida dentro del directorio general
artifacts_dir="${main_dir}/Artifacts_Import"
visual_dir="${main_dir}/VisualFiles_Import"
classif_dir="${main_dir}/Artifacts_Classif"
artifacts_final_dir="${main_dir}/Artifacts_Final"
visualizations_final_dir="${main_dir}/Visualizations_Final"
exported_biom_dir="${main_dir}/exportedBIOMtables"

# Crear subdirectorios
mkdir -p "$artifacts_dir" "$visual_dir" "$classif_dir" "$artifacts_final_dir" "$visualizations_final_dir" "$exported_biom_dir"

# Función para manejar errores y hacer salida del script
handle_error() {
    echo "Error en el proceso: $1"
    exit 1
}

# Función para reiniciar si ya se completó alguna fase
check_and_continue() {
    if [ -f "$1" ]; then
        echo "Saltando: $1 ya fue generado."
        return 0  # Continúa el flujo normal si el archivo ya existe
    fi
    return 1  # Indica que el archivo no existe, por lo que el paso debe ejecutarse
}

# Función para registrar el tiempo
log_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "Tiempo transcurrido: $duration segundos."
}

# Procesar manifiesto
process_manifest() {
    echo "Procesando manifiesto..."
    local start_time=$(date +%s)

    if check_and_continue "$artifacts_dir/sequences_${prefix}.qza"; then
        echo "Saltando la importación de secuencias..."
    else
        echo "Importando archivos fastq..."
        if ! qiime tools import \
			--type 'SampleData[SequencesWithQuality]'\
            --input-path "$manifest_file" \
            --input-format 'SingleEndFastqManifestPhred33V2' \
            --output-path "$artifacts_dir/sequences_${prefix}.qza"; then
            handle_error "Falló la importación de fastq."
        fi
    fi
    log_time $start_time

    start_time=$(date +%s)
    if check_and_continue "$visual_dir/demux_summary_${prefix}.qzv"; then
        echo "Saltando el resumen de secuencias..."
    else
        echo "Resumiendo información de secuencias..."
        if ! qiime demux summarize --i-data "$artifacts_dir/sequences_${prefix}.qza" \
                                   --o-visualization "$visual_dir/demux_summary_${prefix}.qzv"; then
            handle_error "Falló el resumen de secuencias."
        fi
    fi
    log_time $start_time

    start_time=$(date +%s)
    if check_and_continue "$artifacts_dir/rep-seqs_tmp_${prefix}.qza"; then
        echo "Saltando el derreplicado de secuencias..."
    else
        echo "Derreplicando secuencias..."
        if ! qiime vsearch dereplicate-sequences \
            --i-sequences "$artifacts_dir/sequences_${prefix}.qza" \
            --o-dereplicated-table "$artifacts_dir/table_deReplicated_tmp_${prefix}.qza" \
            --o-dereplicated-sequences "$artifacts_dir/rep-seqs_tmp_${prefix}.qza" \
            --verbose; then
            handle_error "Falló el derreplicado de secuencias."
        fi
    fi
    log_time $start_time

    start_time=$(date +%s)
    if check_and_continue "$artifacts_dir/rep-seqs_${prefix}.qza"; then
        echo "Saltando el clustering de secuencias..."
    else
        echo "Clusterizando secuencias..."
        if ! qiime vsearch cluster-features-de-novo \
            --i-sequences "$artifacts_dir/rep-seqs_tmp_${prefix}.qza" \
            --i-table "$artifacts_dir/table_deReplicated_tmp_${prefix}.qza" \
			--verbose \
            --p-perc-identity $cluster_identity \
            --o-clustered-table "$artifacts_dir/table_clust_${prefix}.qza" \
            --o-clustered-sequences "$artifacts_dir/rep-seqs_${prefix}.qza" \
            --p-threads 19; then
            handle_error "Falló el clustering de novo."
        fi
    fi
    log_time $start_time

    start_time=$(date +%s)
	 if check_and_continue "$visual_dir/table_clust_${prefix}.qzv"; then
        echo "Saltando el archivo de visualizacion..."
	else
		echo "Generando archivo de visualización..."
    if ! qiime feature-table summarize \
        --i-table "$artifacts_dir/table_clust_${prefix}.qza" \
        --o-visualization "$visual_dir/table_clust_${prefix}.qzv"; then
        handle_error "Falló la generación de visualización."
		fi
	fi
    log_time $start_time
}

# Clasificar secuencias con BLAST
classificar_secuencias() {
    echo "Clasificando secuencias con BLAST..."
    local start_time=$(date +%s)

    check_and_continue "$classif_dir/taxonomy_${prefix}.qza" || {
        echo "Clasificando secuencias..."
        if ! qiime feature-classifier classify-consensus-blast \
            --i-query "$artifacts_dir/rep-seqs_${prefix}.qza" \
            --i-blastdb "$dirDB/${dirDB}_BlastDB.qza" \
            --i-reference-taxonomy "$dirDB/${dirDB}_derep1_taxa.qza" \
			--verbose \
            --p-num-threads 25 \
            --p-perc-identity $blast_identity \
            --p-query-cov $blast_coverage \
            --p-maxaccepts $maxaccepts \
            --p-min-consensus $blast_consensus \
            --o-classification "$classif_dir/taxonomy_${prefix}.qza" \
            --o-search-results "$classif_dir/search_results_${prefix}.qza"; then
            handle_error "Falló la clasificación con BLAST."
        fi
    }
    log_time $start_time

    SUBJECT="Notificación - Clasificación completada"
    BODY="Clasificación completada.\nFecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    if [ "$EMAIL_NOTIFY" = "1" ]; then
        echo -e "Subject: $SUBJECT\n\n$BODY" | msmtp -a gmail "$email"
    fi
}

# Extraer datos
extraer_datos() {
    niveles=(3 6 7)
    for nivel in "${niveles[@]}"; do
        echo "Procesando nivel $nivel..."
        local start_time=$(date +%s)

        check_and_continue "$artifacts_final_dir/table_collapsed_level${nivel}_${prefix}.qza" || {
            echo "Colapsando tablas de nivel $nivel..."
            if ! qiime taxa collapse \
                --i-table "$artifacts_dir/table_clust_${prefix}.qza" \
                --i-taxonomy "$classif_dir/taxonomy_${prefix}.qza" \
                --p-level $nivel \
                --o-collapsed-table "$artifacts_final_dir/table_collapsed_level${nivel}_${prefix}.qza"; then
                handle_error "Falló la colapsación en nivel $nivel."
            fi
        }
        log_time $start_time

        start_time=$(date +%s)
        echo "Tabulando datos del nivel $nivel..."
        if ! qiime metadata tabulate \
            --m-input-file "$artifacts_final_dir/table_collapsed_level${nivel}_${prefix}.qza" \
            --o-visualization "$visualizations_final_dir/table_collapsed_level${nivel}_${prefix}.qzv"; then
            handle_error "Falló la tabulación de datos."
        fi
        log_time $start_time

        exportar_y_procesar_tablas "$nivel"
    done
}

# Exportar y procesar tablas
exportar_y_procesar_tablas() {
    nivel=$1
    echo "Exportando tabla del nivel $nivel..."

    if ! qiime tools export \
        --input-path "$artifacts_final_dir/table_collapsed_level${nivel}_${prefix}.qza" \
        --output-path "./$exported_biom_dir/"; then
        handle_error "Falló la exportación de la tabla."
    fi

    mv "./$exported_biom_dir/feature-table.biom" \
        "./$exported_biom_dir/table_collapsed_level${nivel}_${prefix}.biom"
    if ! biom convert \
        -i "./$exported_biom_dir/table_collapsed_level${nivel}_${prefix}.biom" \
        -o "./$exported_biom_dir/table_collapsed_level${nivel}_${prefix}.tsv" \
        --to-tsv; then
        handle_error "Falló la conversión a TSV."
    fi
}

# Envío de notificación al inicio del proceso
SUBJECT="Notificación - Inicio del proceso"
BODY="El proceso ha comenzado.\nFecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
if [ "$EMAIL_NOTIFY" = "1" ]; then
    echo -e "Subject: $SUBJECT\n\n$BODY" | msmtp -a gmail "$email"
fi

# Ejecución de funciones
process_manifest
classificar_secuencias
extraer_datos

# Notificación de finalización
SUBJECT="Notificación - Proceso completo"
BODY="El proceso ha terminado.\nFecha y Hora: $(date '+%Y-%m-%d %H:%M:%S')"
if [ "$EMAIL_NOTIFY" = "1" ]; then
    echo -e "Subject: $SUBJECT\n\n$BODY" | msmtp -a gmail "$email"
fi
