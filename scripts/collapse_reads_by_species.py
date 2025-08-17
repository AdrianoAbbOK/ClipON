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

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path


def format_taxon(taxon: str) -> str:
    """Return a readable representation of a taxon string.

    Parameters
    ----------
    taxon:
        Taxonomic annotation where ranks are separated by ``;`` or spaces and
        encoded as ``r__name`` (e.g. ``g__Escherichia``).

    Returns
    -------
    str
        A simplified representation using genus and species when available.
    """

    parts = taxon.split(";") if ";" in taxon else taxon.split()
    parts = [p.strip() for p in parts if p.strip()]
    ranks: dict[str, str] = {}
    rank_map = {
        "k": "kingdom",
        "p": "phylum",
        "c": "class",
        "o": "order",
        "f": "family",
        "g": "genus",
        "s": "species",
    }

    last_name = taxon.strip()
    last_rank = "unknown"
    for part in parts:
        if "__" in part:
            rank_code, name = part.split("__", 1)
            ranks[rank_code] = name
            last_name = name
            last_rank = rank_map.get(rank_code, rank_code)

    genus = ranks.get("g")
    species = ranks.get("s")
    if genus and species:
        return f"*{genus.capitalize()} {species.lower()}*"
    if genus:
        return f"*{genus.capitalize()}* (genus)"
    return f"{last_name} ({last_rank})"


def parse_args() -> Path:
    """Return the path to the TSV file containing reads and taxonomic data."""

    parser = argparse.ArgumentParser(
        description="Collapse read counts per species for each sample."
    )
    parser.add_argument(
        "tsv",
        type=Path,
        help="Path to the taxonomy_with_sample.tsv file",
    )
    return parser.parse_args().tsv


def collapse_by_species(path: Path) -> dict[str, dict[str, int]]:
    """Parse *path* and accumulate read counts per sample and species."""

    data: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    with path.open() as fin:
        reader = csv.DictReader(fin, delimiter="\t")
        for row in reader:
            sample = row["Sample"]
            species = format_taxon(row["Taxon"])
            try:
                reads = int(row["Reads"])
            except ValueError:
                reads = 0
            data[sample][species] += reads
    return data


def print_results(data: dict[str, dict[str, int]]) -> None:
    """Print ``data`` produced by :func:`collapse_by_species`."""

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


def main() -> None:
    """Entry point for command-line execution."""

    tsv_path = parse_args()
    if not tsv_path.is_file():
        print(f"File not found: {tsv_path}", file=sys.stderr)
        sys.exit(1)

    data = collapse_by_species(tsv_path)
    print_results(data)


if __name__ == "__main__":
    main()
