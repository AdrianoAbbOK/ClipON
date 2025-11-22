# AGENTS

Este repositorio contiene el pipeline **ClipON** para el análisis de metabarcoding a partir de lecturas de Nanopore.

## Estilo de código
- **Python**: seguir [PEP 8](https://peps.python.org/pep-0008/) con indentación de cuatro espacios y un máximo de 88 caracteres por línea. Incluir docstrings descriptivos en funciones y scripts.
- **Bash**: comenzar los scripts con `#!/usr/bin/env bash` y `set -euo pipefail`. Comentar los pasos principales y utilizar variables con nombres claros.

## Pruebas y validación
- Ejecutar `pytest` y asegurarse de que todas las pruebas pasen antes de realizar un commit.
- Si se modifican scripts en `scripts/`, ejecutar `shellcheck` cuando esté disponible.

## Documentación
- Actualizar `README.md` y los archivos en `docs/` cuando se agreguen nuevas funciones o se cambie el comportamiento de los scripts.
- Mantener este archivo actualizado si cambian las reglas de estilo o los procedimientos de prueba.

## Respuestas de los agentes
- Al responder a los usuarios, explicar siempre qué sucede, qué se cambió y por qué se hizo ese cambio.

## Commits
- Usar mensajes de commit breves y descriptivos (preferentemente en inglés).

## Notas recientes de depuración
- El archivo `scripts/ClipON-Cluster-VSearch-Consensus.py` fallaba al leer
  tablas BIOM TSV cuando los conteos venían como strings flotantes (p. ej.,
  "1.0"), lanzando `ValueError` al intentar `int('1.0')`. Convierte los
  conteos con `float` y redondea a entero antes de castear para evitar este
  problema.
