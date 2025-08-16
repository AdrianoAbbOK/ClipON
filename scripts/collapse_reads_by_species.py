#!/usr/bin/env python3
"""Collapse read counts per species for each sample.

Reads the ``taxonomy_with_sample.tsv`` table produced by
``add_reads_and_sample.py`` and outputs, for cada muestra, una tabla con las
columnas ``Species``, ``Reads`` y ``Proportion`` (0-100). Las especies se
ordenan por número de lecturas de forma descendente.

Usage:
    python scripts/collapse_reads_by_species.py <taxonomy_with_sample.tsv>
"""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        print(
            "Usage: collapse_reads_by_species.py <taxonomy_with_sample.tsv>",
            file=sys.stderr,
        )
        sys.exit(1)

    in_path = Path(sys.argv[1])
    if not in_path.is_file():
        print(f"File not found: {in_path}", file=sys.stderr)
        sys.exit(1)

    data: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    with in_path.open() as fin:
        reader = csv.DictReader(fin, delimiter="\t")
        for row in reader:
            sample = row["Sample"]
            species = row["Taxon"]
            try:
                reads = int(row["Reads"])
            except ValueError:
                reads = 0
            data[sample][species] += reads

    for sample in sorted(data):
        species_counts = data[sample]
        total_reads = sum(species_counts.values())
        print(f"Sample: {sample}")
        print("Species\tReads\tProportion")
        for species, count in sorted(
            species_counts.items(), key=lambda kv: kv[1], reverse=True
        ):
            proportion = (count / total_reads * 100) if total_reads else 0
            print(f"{species}\t{count}\t{proportion:.2f}")
        print()


if __name__ == "__main__":
    main()
