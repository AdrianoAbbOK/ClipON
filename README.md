# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”
## Descripción general del pipeline

1. **Procesamiento inicial** – se filtran secuencias corruptas con `SeqKit`.
2. **Recorte de cebadores** – `Cutadapt` elimina bases al inicio y fin.
3. **Filtrado de calidad y longitud** – `NanoFilt` descarta lecturas cortas o de baja calidad.
4. **Clustering** – `NGSpeciesID` agrupa secuencias y genera consensos.
5. **Unificación de clusters** – se combinan los consensos de distintos experimentos.
6. **Clasificación opcional** – el script `scripts/De3_A4_Classify_NGS.sh` usa `qiime feature-classifier classify-consensus-blast` para asignar taxonomía a los consensos unificados.
7. **Exportación de la clasificación** – `scripts/De3_A4_Export_Classification.sh` guarda `taxonomy.qza`, `search_results.qza` y genera `taxonomy_with_sample.tsv` (con columnas *Reads* y *Sample*) en `MaxAc_5`.


## Uso rápido

Ejecuta todo el flujo con:

```bash
./scripts/run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```
El directorio `<dir_trabajo>/5_unified` contendrá los archivos de clasificación
`taxonomy.qza` y `search_results.qza`. El paso de exportación generará copias en
texto dentro de `5_unified/MaxAc_5`, incluyendo `taxonomy_with_sample.tsv` con
las columnas adicionales *Reads* y *Sample*. Defina las variables de entorno
`BLAST_DB` y `TAXONOMY_DB` apuntando a las bases de datos en formato `.qza` para
habilitar esta etapa.

Esto creará subdirectorios dentro de `<dir_trabajo>` para cada etapa.
Las rutas de entrada y salida también pueden configurarse manualmente al invocar cada script por separado.
## Requisitos

- SeqKit
- Cutadapt
- NanoFilt (debe estar instalado antes de ejecutar `scripts/De1.5_A2_Filtrado_NanoFilt_1.1.sh`)
- QIIME2
- R (opcional, necesario para generar el gráfico de calidad vs longitud; puede instalarse con `sudo apt install r-base`)
- msmtp (utilizado por `scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh` para enviar notificaciones por correo)

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

## Entornos Conda

El repositorio incluye archivos de entorno en `envs/` y un asistente para instalarlos.

Para crear los entornos automáticamente ejecute:

```bash
./scripts/install_envs.sh
```

El script verifica que `conda` esté disponible (instala Miniconda si es necesario) y crea los entornos que falten a partir de los YAML.

### Descripción de los entornos

- `clipon-prep`: control de calidad y recorte inicial.
- `clipon-qiime`: clustering y clasificación con QIIME 2 y VSEARCH.
- `clipon-ngs`: generación de consensos con NGSpeciesID.

También puede crearlos manualmente con `mamba` (o `conda`):

```bash
mamba env create -f envs/clipon-prep.yml
mamba env create -f envs/clipon-qiime.yml
mamba env create -f envs/clipon-ngs.yml
```

Si alguno de los archivos de `envs/` cambia y el entorno ya existe, reconstrúyalo con:

```bash
conda env update -f <archivo>.yml
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
./scripts/De2_A4__VSearch_Procesonuevo2.6.1.sh <manifest.tsv> <prefijo> <dirDB> <email> <cluster_identity> <blast_identity> <maxaccepts>
```
La clasificación se realiza dentro de la función `clasificar_secuencias` de dicho script.
Para ejecutar todas las combinaciones de parámetros de forma automática puede usarse
`scripts/De2_A4_VSearch_ejecutador_combinaciones1.1.sh`. Los valores de manifiesto, prefijo,
base de datos y correo pueden pasarse como argumentos o mediante variables de entorno:
```bash
MANIFEST_FILE=manifest.tsv PREFIX=prueba DIRDB=NCBI_DB EMAIL=me@example.com \
./scripts/De2_A4_VSearch_ejecutador_combinaciones1.1.sh
```

### Ejecución completa
El wrapper `run_clipon_pipeline.sh` puede ejecutarse desde cualquier
directorio.  Activará los entornos Conda necesarios automáticamente.

```bash
./scripts/run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```

### Asistente interactivo con reanudación
El script `scripts/run_clipon_interactive.sh` guía la configuración del pipeline y permite reanudar un procesamiento previo.

```bash
./scripts/run_clipon_interactive.sh
```

Si se elige reanudar, se solicitará el directorio de trabajo existente y se ejecutará `scripts/check_pipeline_status.sh` para mostrar el estado. A continuación, seleccione el paso desde el cual continuar; la elección se guarda en `resume_config.sh` y exporta la variable `RESUME_STEP` antes de llamar al pipeline.

### Formato del Importing Manifest
Consulte [docs/manifest_example.md](docs/manifest_example.md) para un ejemplo de `ImportingManifest_Manual.csv`. El archivo debe tener las columnas:
`sample-id`, `absolute-filepath` y `direction`.
