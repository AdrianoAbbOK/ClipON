# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”
## Descripción general del pipeline

1. **Procesamiento inicial** – se filtran secuencias corruptas con `SeqKit`.
2. **Recorte de cebadores** – `Cutadapt` elimina bases al inicio y fin.
3. **Filtrado de calidad y longitud** – `NanoFilt` descarta lecturas cortas o de baja calidad.
4. **Clustering** – `NGSpeciesID` agrupa secuencias y genera consensos.
5. **Unificación de clusters** – se combinan los consensos de distintos experimentos.
6. **Clasificación opcional** – el script `scripts/De3_A4_Classify_NGS.sh` usa `qiime feature-classifier classify-consensus-blast` para asignar taxonomía a los consensos unificados.
7. **Exportación de la clasificación** – `scripts/De3_A4_Export_Classification.sh` guarda `taxonomy.qza`, `search_results.qza` y genera `taxonomy_with_sample.tsv` (con columnas *Reads* y *Sample*) en `Results`. Además, crea `reads_per_species.tsv` con el número total de lecturas por especie y muestra.

## Instalación

Descargue el último release desde la página de [releases](https://github.com/AdrianoAbbOK/ClipON/releases) o con:

```bash
wget https://github.com/AdrianoAbbOK/ClipON/releases/latest/download/ClipON.tar.gz
```

Antes de utilizar el pipeline ejecute:

```bash
./setup.sh
```

Este script instala las dependencias y prepara los entornos necesarios.

## Componentes principales que usa ClipON

ClipON es software libre y reconoce el trabajo de varias herramientas de código abierto, que el instalador descarga de forma automática:

- [SeqKit](https://github.com/shenwei356/seqkit)
- [Cutadapt](https://github.com/marcelm/cutadapt)
- [NanoFilt](https://github.com/wdecoster/nanofilt)
- [NGSpeciesID](https://github.com/esteininger/NGSpeciesID)
- [QIIME 2](https://github.com/qiime2/qiime2)
- [Python](https://www.python.org/) con [pandas](https://github.com/pandas-dev/pandas) y [matplotlib](https://github.com/matplotlib/matplotlib)
- [R](https://www.r-project.org/) (opcional)
- [eog](https://gitlab.gnome.org/GNOME/eog) (opcional para visualizar gráficos PNG)
- [msmtp](https://marlam.de/msmtp/) (opcional para notificaciones)

Para ejecutarlo se necesita un entorno GNU/Linux o WSL con `bash`. `conda` y [mamba](https://github.com/mamba-org/mamba) se utilizarán para gestionar los entornos y se instalarán automáticamente durante la instalación.

## Uso

### Ejecución interactiva

`run_clipon_interactive.sh` es el corazón del proyecto y la forma recomendada de ejecutar ClipON. El asistente, totalmente de código abierto, guía paso a paso a cualquier persona con nociones básicas de la terminal: instala y configura los componentes necesarios, valida los archivos de entrada y permite reanudar ejecuciones previas. También genera automáticamente el manifest que requiere QIIME2. Si se dispone de un archivo de metadata, puede suministrarse de manera opcional con `--metadata <archivo>`. Al final ofrece editar parámetros avanzados de cada etapa.

```bash
./scripts/run_clipon_interactive.sh
```

### Uso avanzado

Usuarios con experiencia en la línea de comandos pueden adaptar los scripts individuales o ejecutar el pipeline completo:

```bash
./scripts/run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```

## Ejemplos de ejecución

Las siguientes instrucciones están pensadas para usuarios avanzados que deseen ejecutar o modificar etapas específicas. El asistente interactivo ya realiza estos pasos automáticamente.

### Procesamiento con SeqKit
```bash
./scripts/ClipON-Prep-Cleaning.sh <dir_entrada> <dir_salida>
```

### Recorte con Cutadapt
```bash
./scripts/ClipON-Prep-Trimming.sh <dir_entrada> <dir_salida>
```

### Filtrado con NanoFilt
```bash
./scripts/ClipON-Prep-Filtering.sh <dir_entrada> <dir_salida> <log_file>
```

### Estadísticas de lecturas
Para obtener longitudes y calidades por lectura utilice el script ya incluido
en el repositorio:

```bash
python scripts/ClipON-Prep-CollectReadStats.py <archivo.fastq>
```
Así evita implementar herramientas duplicadas para esta tarea.

### Gráfico de barras de taxones
El script `scripts/ClipON-Classif-PlotTaxonBar.py` genera un gráfico de barras apiladas con
la proporción de lecturas por muestra. Puede asignar nombres de experimento a
las muestras con `--metadata <archivo>` y, opcionalmente, reemplazar los nombres
por códigos secuenciales (`M1`, `M2`, ...) con `--code-samples`, guardando la
tabla de equivalencias en `<salida>.sample_map.tsv`. De forma predeterminada se
conservan los nombres de taxones, pero se pueden reemplazar por códigos
secuenciales (`T1`, `T2`, ...) con `--code-taxa`, guardando la tabla de
equivalencias en `<salida>.taxon_map.tsv`.

```bash
python scripts/ClipON-Classif-PlotTaxonBar.py taxonomy_with_sample.tsv plot.png \
    --metadata fastq_metadata.tsv --code-samples --code-taxa
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
./scripts/ClipON-Cluster-NGS-Clustering.sh <dir_entrada> <dir_salida>
```

### Unificación de clusters
```bash
./scripts/ClipON-Cluster-NGS-Unifying.sh <dir_base> <dir_salida>
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


### Formato del Importing Manifest
Consulte [docs/manifest_example.md](docs/manifest_example.md) para un ejemplo de `ImportingManifest_Manual.csv`. No es necesario generarlo si usa `run_clipon_interactive.sh`, ya que el asistente crea un manifest correcto de forma automática. Solo se requiere al ejecutar las etapas por separado; en ese caso el archivo debe tener las columnas: `sample-id`, `absolute-filepath` y `direction`.
