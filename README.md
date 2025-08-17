# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”
## Descripción general del pipeline

1. **Procesamiento inicial** – se filtran secuencias corruptas con `SeqKit`.
2. **Recorte de cebadores** – `Cutadapt` elimina bases al inicio y fin.
3. **Filtrado de calidad y longitud** – `NanoFilt` descarta lecturas cortas o de baja calidad.
4. **Clustering** – por defecto, `NGSpeciesID` agrupa secuencias y genera consensos; alternativamente, use `--cluster-method vsearch` para ejecutar `VSEARCH`.
5. **Unificación de clusters** – se combinan los consensos de distintos experimentos.
6. **Clasificación opcional** – el script `scripts/De3_A4_Classify_NGS.sh` usa `qiime feature-classifier classify-consensus-blast` para asignar taxonomía a los consensos unificados.
7. **Exportación de la clasificación** – `scripts/De3_A4_Export_Classification.sh` guarda `taxonomy.qza`, `search_results.qza` y genera `taxonomy_with_sample.tsv` (con columnas *Reads* y *Sample*) en `Results`. Además, crea `reads_per_species.tsv` con el número total de lecturas por especie y muestra.


## Uso rápido

Ejecuta todo el flujo con:

```bash
./scripts/run_clipon_pipeline.sh [--cluster-method <ngspecies|vsearch>] <dir_fastq_entrada> <dir_trabajo>
```

Defina la variable de entorno `CLUSTER_METHOD` para elegir el método de
clustering (`ngspecies` o `vsearch`). El valor predeterminado es
`ngspecies`.

Para reemplazar los nombres de los archivos FASTQ por identificadores de
experimento, proporcione un archivo de metadata con columnas `fastq` y
`experiment`:

```bash
./scripts/run_clipon_pipeline.sh --metadata fastq_metadata.tsv [--cluster-method <ngspecies|vsearch>] <dir_fastq_entrada> <dir_trabajo>
```
Consulte [docs/metadata_example.md](docs/metadata_example.md) para un ejemplo de
formato.
El directorio `<dir_trabajo>/5_unified` contendrá los archivos de clasificación
`taxonomy.qza` y `search_results.qza`. El paso de exportación generará copias en
texto dentro de `5_unified/Results`, incluyendo `taxonomy_with_sample.tsv` con
las columnas adicionales *Reads* y *Sample* y `reads_per_species.tsv` con los
conteos de lecturas por especie y muestra. Defina las variables de entorno
`BLAST_DB` y `TAXONOMY_DB` apuntando a las bases de datos en formato `.qza` para
habilitar esta etapa.

Esto creará subdirectorios dentro de `<dir_trabajo>` para cada etapa.
Las rutas de entrada y salida también pueden configurarse manualmente al invocar cada script por separado.

## Configuración

Ejecuta `./setup.sh` para instalar Miniconda, crear los entornos necesarios y asegurar la presencia de `eog` para la visualización de imágenes.
## Requisitos

 - SeqKit
 - Cutadapt
 - NanoFilt (debe estar instalado antes de ejecutar
   `scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh`)
 - QIIME2
- Python con pandas y matplotlib (opcional, necesario para el gráfico de
   barras de taxones)
- R (opcional, necesario para generar el gráfico de calidad vs longitud;
   puede instalarse con `sudo apt install r-base`)
- eog (opcional, instale con `apt install eog` para abrir gráficos PNG en un
  entorno gráfico)
- msmtp (opcional, utilizado por `scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh`
  para enviar notificaciones por correo)

## Ejemplos de ejecución

### Procesamiento con SeqKit
```bash
./scripts/De0_A1_Process_Fastq.4_SeqKit.sh <dir_entrada> <dir_salida>
```

### Recorte con Cutadapt
```bash
./scripts/De1_A1.5_Trim_Fastq.sh <dir_entrada> <dir_salida>
```

### Filtrado con NanoFilt
```bash
./scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh <dir_entrada> <dir_salida> <log_file>
```

### Estadísticas de lecturas
Para obtener longitudes y calidades por lectura utilice el script ya incluido
en el repositorio:

```bash
python scripts/collect_read_stats.py <archivo.fastq>
```
Así evita implementar herramientas duplicadas para esta tarea.

### Gráfico de barras de taxones
El script `scripts/plot_taxon_bar.py` genera un gráfico de barras apiladas con
la proporción de lecturas por muestra. Puede asignar nombres de experimento a
las muestras con `--metadata <archivo>` y, opcionalmente, reemplazar los nombres
por códigos secuenciales (`M1`, `M2`, ...) con `--code-samples`, guardando la
tabla de equivalencias en `<salida>.sample_map.tsv`. Los taxones se codifican
siempre como `T1`, `T2`, ... y su correspondencia se escribe en
`<salida>.taxon_map.tsv`.

```bash
python scripts/plot_taxon_bar.py taxonomy_with_sample.tsv plot.png \
    --metadata fastq_metadata.tsv --code-samples
```

## Entornos Conda

El repositorio incluye archivos de entorno en `envs/` y un asistente para instalarlos.

Para crear los entornos automáticamente ejecute:

```bash
./scripts/install_envs.sh
```

El script verifica que `mamba` esté disponible (instala Miniconda y mamba si es necesario) y crea los entornos que falten a partir de los YAML.

### Descripción de los entornos

- `clipon-prep`: control de calidad y recorte inicial.
- `clipon-qiime`: clustering y clasificación con QIIME 2 y VSEARCH.
- `clipon-ngs`: generación de consensos con NGSpeciesID.

También puede crearlos manualmente con `mamba`:

```bash
mamba env create -f envs/clipon-prep.yml
mamba env create -f envs/clipon-qiime.yml
mamba env create -f envs/clipon-ngs.yml
```

Si alguno de los archivos de `envs/` cambia y el entorno ya existe, reconstrúyalo con:

```bash
mamba env update -f <archivo>.yml
```

Después de instalar los entornos, verifique su funcionamiento con:

```bash
./scripts/test_envs.sh
```

Este script comprueba que `cutadapt`, `qiime` y `minimap2` estén disponibles en los
entornos configurados.

Active cada entorno solo la primera vez para instalarlo. El script `run_clipon_pipeline.sh` se encarga de activar el entorno adecuado en cada etapa, por lo que puede ejecutarse sin activar nada manualmente. Si desea ejecutar las etapas por separado, active el entorno correspondiente de forma manual. El entorno `clipon-qiime` también se reutiliza para el módulo **Classifier** y contiene `msmtp` para habilitar las notificaciones por correo.


### Clustering con NGSpeciesID
```bash
./scripts/De2_A2.5_NGSpecies_Clustering.sh <dir_entrada> <dir_salida>
```

### Unificación de clusters
```bash
./scripts/De2.5_A3_NGSpecies_Unificar_Clusters.sh <dir_base> <dir_salida>
```

### Generar manifest automáticamente
El archivo `manifest.csv` requerido por QIIME2 puede crearse con:

```bash
./scripts/generate_manifest.sh --workdir <dir_trabajo> filtered > manifest.csv
```

También puede generarse a partir de los consensos unificados:

```bash
./scripts/generate_manifest.sh --workdir <dir_trabajo> unified > manifest.csv
```

### Clasificación con QIIME2
```bash
./scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh \
    --manifest manifest.tsv \
    --output-dir resultados \
    --cluster-id 0.98 \
    --blast-id 0.8 \
    --maxaccepts 5 \
    --notify --email me@example.com
```
La clasificación utiliza las variables de entorno `BLAST_DB` y `TAXONOMY_DB`
para localizar los artefactos de referencia. Las notificaciones por correo son
opcionales y requieren `msmtp`.

### Ejecución completa
El wrapper `run_clipon_pipeline.sh` puede ejecutarse desde cualquier
directorio.  Activará los entornos Conda necesarios automáticamente.

```bash
./scripts/run_clipon_pipeline.sh [--cluster-method <ngspecies|vsearch>] <dir_fastq_entrada> <dir_trabajo>
```

### Asistente interactivo con reanudación
El script `scripts/run_clipon_interactive.sh` guía la configuración del pipeline y permite reanudar un procesamiento previo.
Puede recibir `--metadata <archivo>`; si no se proporciona, pedirá la ruta durante la ejecución
después de indicar los archivos FASTQ.
Intentará abrir las imágenes con `eog` si está instalado en el sistema.

Durante la configuración se consultará qué método de clusterización utilizar (`ngspecies` o `vsearch`).
En caso de elegir **VSearch**, se solicitarán los parámetros `cluster_identity`,
`blast_identity` y `maxaccepts`, que se exportarán como variables de entorno al
invocar el pipeline.

```bash
./scripts/run_clipon_interactive.sh
```

Si se elige reanudar, se solicitará el directorio de trabajo existente; podrá sobrescribirlo o copiarlo a un nuevo directorio. Luego se ejecutará `scripts/check_pipeline_status.sh` para mostrar el estado y solicitar el paso desde el cual continuar. El valor elegido se guarda en `resume_config.sh` y se carga automáticamente para definir la variable `RESUME_STEP` antes de llamar al pipeline.

Tras el resumen de configuración, el asistente permite ingresar una línea con parámetros adicionales que se añadirán a los comandos de los scripts internos. Esta opción ofrece flexibilidad para ajustar hilos, filtros u otros valores sin modificar directamente los scripts.

```bash
./scripts/run_clipon_interactive.sh
# ...
# Parámetros extra para los scripts (opcional):
--threads 8 --max-accepts 5
```

En un procesamiento nuevo, si el directorio de salida ya existe y contiene archivos, se pedirá confirmación antes de sobrescribirlo.

### Formato del Importing Manifest
Consulte [docs/manifest_example.md](docs/manifest_example.md) para un ejemplo de `ImportingManifest_Manual.csv`. El archivo debe tener las columnas:
`sample-id`, `absolute-filepath` y `direction`.
