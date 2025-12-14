# Notas para el próximo release

Estas notas resumen los puntos más recientes para preparar el siguiente release de
ClipON y destacan temas que pueden describirse en la página de GitHub.

## Resumen rápido
- El asistente `run_clipon_interactive.sh` instala dependencias, valida entradas y
  permite reanudar ejecuciones del pipeline.
- Se mantiene la ruta dual de clustering: NGSpeciesID como flujo predeterminado y
  VSEARCH como alternativa integrada en QIIME 2.
- Los scripts de clasificación exportan tablas listas para su análisis y permiten
  generar gráficos de barras de taxones con opciones para codificar muestras y
  taxones.
- Los archivos de entorno en `envs/` y el instalador `install_envs.sh` permiten
  recrear los entornos de conda de forma reproducible.
- Se añadió `CITATION.cff` para facilitar cómo citar ClipON desde la página del
  proyecto.

## Pasos recomendados para armar el release
1. Ejecutar `pytest` para verificar las utilidades de manejo de tablas antes de
   empaquetar.
2. Ejecutar `./scripts/test_envs.sh` si hubo cambios en los YAML de entornos.
3. Generar el artefacto con `tar -czf ClipON.tar.gz --exclude-vcs .` desde la
   raíz del repositorio.
4. Subir el artefacto a la sección de releases y vincular el enlace de descarga
   directa en `README.md` si cambia el nombre del archivo.
5. Copiar los temas destacados de la siguiente sección en la descripción del
   release.

## Temas sugeridos para la página del release
- **Compatibilidad Nanopore COI**: pipeline reproducible para lecturas de eDNA.
- **Asistente interactivo**: instala dependencias y guía cada etapa con valores
  predeterminados seguros.
- **Clustering flexible**: NGSpeciesID o VSEARCH/QIIME 2 con unificación estándar
  de consensos.
- **Clasificación y reportes**: exportación de tablas, conteo por especie y
  gráfico de barras apiladas.
- **Entornos reproducibles**: YAML versionados y script de instalación
  automatizada con mamba.
- **Novedades**: documento de citación disponible en `CITATION.cff`.
