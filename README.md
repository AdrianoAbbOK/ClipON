# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”
## Descripción general del pipeline

1. **Procesamiento inicial** – se filtran secuencias corruptas con `SeqKit`.
2. **Recorte de cebadores** – `Cutadapt` elimina bases al inicio y fin.
3. **Filtrado de calidad y longitud** – `NanoFilt` descarta lecturas cortas o de baja calidad.
4. **Clustering** – `NGSpeciesID` (predeterminado) o `VSEARCH` generan
   consensos a partir de las lecturas filtradas.
5. **Unificación de clusters** – se combinan los consensos de distintos experimentos.
6. **Clasificación opcional** – el script `scripts/ClipON-Classif-NGS.sh` usa `qiime feature-classifier classify-consensus-blast` para asignar taxonomía a los consensos unificados.
7. **Exportación de la clasificación** – `scripts/ClipON-Classif-Export.sh` guarda `taxonomy.qza`, `search_results.qza` y genera `taxonomy_with_sample.tsv` (con columnas *Reads* y *Sample*) en `Results`. Además, crea `reads_per_species.tsv` con el número total de lecturas por especie y muestra.

### Scripts por etapa

- **ClipON-Prep**
  - `ClipON-Prep-Cleaning.sh`
  - `ClipON-Prep-Trimming.sh`
  - `ClipON-Prep-Filtering.sh`
  - `ClipON-Prep-CollectReadStats.py`
- **ClipON-Cluster**
  - `ClipON-Cluster-NGS-Clustering.sh`
  - `ClipON-Cluster-NGS-Unifying.sh`
  - `ClipON-Cluster-VSearch.sh`
  - `ClipON-Cluster-VSearch-Consensus.py`
- **ClipON-Classif**
  - `ClipON-Classif-NGS.sh`
  - `ClipON-Classif-Export.sh`
  - `ClipON-Classif-AddReadsAndSample.py`
  - `ClipON-Classif-ReadsPerSpecies.py`
  - `ClipON-Classif-PlotTaxonBar.py`

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

`run_clipon_interactive.sh` es el corazón del proyecto y la forma recomendada de ejecutar ClipON. El asistente, totalmente de código abierto, guía paso a paso a cualquier persona con nociones básicas de la terminal: instala y configura los componentes necesarios, valida los archivos de entrada y permite reanudar ejecuciones previas. También genera automáticamente el manifest que requiere QIIME2. Si se dispone de un archivo de metadata, puede suministrarse de manera opcional con `--metadata <archivo>`. Al final ofrece editar parámetros avanzados de cada etapa. Incluye una única pregunta para elegir el método de clustering (NGS = NGSpeciesID o VS = VSearch); la ruta VS importa las lecturas filtradas, ejecuta VSEARCH desde QIIME2 y crea consensos compatibles con el paso de unificación estándar.

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

## Cómo citar

Si ClipON resulta útil en su trabajo, cite el proyecto utilizando los metadatos
incluidos en `CITATION.cff`. GitHub mostrará el formato sugerido en la página
principal del repositorio.

## Notas de release

El archivo `docs/release_notes.md` resume los puntos destacados del próximo
release, los pasos recomendados para crear el artefacto y los temas sugeridos
para la descripción pública.

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

### Clustering con VSEARCH (QIIME2)
El script `ClipON-Cluster-VSearch.sh` parte de los FASTQ filtrados
(`3_filtered`), genera automáticamente el manifest de importación para QIIME2,
importa las lecturas y ejecuta `vsearch cluster-features-de-novo`.
Los consensos se guardan en `4_clustered/<muestra>/consensus_reference_*.fasta`
y en `4_clustered/consensos_todos.fasta`, listos para el paso estándar de
unificación.
```bash
INPUT_DIR=/ruta/a/3_filtered OUTPUT_DIR=/ruta/a/4_clustered \
  ./scripts/ClipON-Cluster-VSearch.sh
```

### Unificación de clusters
```bash
./scripts/ClipON-Cluster-NGS-Unifying.sh <dir_base> <dir_salida>
```

### Generar manifest automáticamente
El archivo `manifest.tsv` requerido por QIIME2 puede crearse con:

```bash
./scripts/generate_manifest.sh --workdir <dir_trabajo> filtered --output manifest.tsv
```

También puede generarse a partir de los consensos unificados:

```bash
./scripts/generate_manifest.sh --workdir <dir_trabajo> unified --output manifest.tsv
```

El script escribe el manifest con separadores de tabulación y normaliza los saltos
de línea al formato Unix (usa `dos2unix` si está disponible).

### Clasificación con QIIME2
```bash
./scripts/ClipON-Classif-NGS.sh consensos.fasta class_dir blast_db.qza taxonomy.qza
```
El script `ClipON-Classif-NGS.sh` clasifica los consensos con BLAST empleando QIIME2. Los
parámetros pueden ajustarse mediante variables de entorno como `NUM_THREADS`, `PERC_ID`
o `MAX_ACCEPTS`.

Tras la clasificación, exporte los resultados a un formato tabular con:
```bash
./scripts/ClipON-Classif-Export.sh class_dir
```


### Video de Ejecución de prueba -- DE PRUEBA XD
https://youtu.be/mj88hCP_qiE
