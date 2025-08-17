#!/usr/bin/env python3
"""Generate a stacked bar plot of read proportions per sample.

Usage:
    python scripts/plot_taxon_bar.py <taxonomy.tsv> <output.png>
    python scripts/plot_taxon_bar.py <taxonomy.tsv> <output.png> --code-samples

The input TSV must contain at least the columns Sample, Taxon and Reads.
Empty or missing taxon names are replaced with "Unassigned" to ensure each
sample is represented. When ``--code-samples`` is provided, samples are
replaced by sequential codes (M1, M2, ...) and the mapping is written to
``<output>.sample_map.tsv``. Taxa are displayed using their names; a mapping
to codes (T1, T2, ...) is saved to ``<output>.taxon_map.tsv`` for reference.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


KNOWN_PREFIXES = ["cleaned_", "filtered_", "trimmed_"]
KNOWN_SUFFIXES = ["_trimmed", "_filtered", "_cleaned"]


def clean_fastq_name(name: str) -> str:
    """Return the original FASTQ name without common processing tags."""
    for prefix in KNOWN_PREFIXES:
        if name.startswith(prefix):
            name = name[len(prefix) :]
    for suffix in KNOWN_SUFFIXES:
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def rename_sample(s: str, mapping: dict[str, str]) -> str:
    """Rename sample ``s`` using ``mapping`` with partial matches.

    If no metadata match is found, return the cleaned FASTQ name.
    """
    for key, value in mapping.items():
        if key in s:
            return value
    return clean_fastq_name(s)

def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="TSV file with Sample, Taxon and Reads")
    parser.add_argument("output", help="Path for the generated PNG plot")
    parser.add_argument(
        "--code-samples",
        action="store_true",
        help=(
            "Replace sample names with codes M1, M2, ... and save mapping to "
            "<output>.sample_map.tsv"
        ),
    )
    parser.add_argument(
        "--metadata",
        help="TSV/CSV with columns 'fastq' and 'experiment' to rename samples",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    in_path = Path(args.input)
    out_path = Path(args.output)

    data = pd.read_csv(in_path, sep="\t", dtype=str)

    mapping: dict[str, str] = {}
    if args.metadata:
        meta = pd.read_csv(args.metadata, sep="\t", dtype=str)
        meta["fastq"] = meta["fastq"].apply(lambda x: Path(x).stem)
        mapping = dict(zip(meta["fastq"], meta["experiment"]))
    data["Sample"] = data["Sample"].map(lambda s: rename_sample(s, mapping))

    data["Reads"] = pd.to_numeric(data["Reads"], errors="coerce")
    data["Taxon"] = data["Taxon"].fillna("").replace("", "Unassigned")
    data = data[~data["Reads"].isna() & (data["Reads"] > 0)]

    if data.empty:
        raise ValueError("No valid reads found in input file")

    if args.code_samples:
        samples = sorted(data["Sample"].unique())
        sample_map = {sample: f"M{i+1}" for i, sample in enumerate(samples)}
        map_df = pd.DataFrame(
            {"code": list(sample_map.values()), "sample": samples}
        )
        map_path = out_path.with_suffix(out_path.suffix + ".sample_map.tsv")
        map_df.to_csv(map_path, sep="\t", index=False)
        data["Sample"] = data["Sample"].map(sample_map)

    grouped = data.groupby(["Sample", "Taxon"], as_index=False)["Reads"].sum()
    grouped["Percent"] = grouped.groupby("Sample")["Reads"].transform(
        lambda x: x / x.sum()
    )

    taxa = sorted(grouped["Taxon"].unique())
    taxon_map = {taxon: f"T{i+1}" for i, taxon in enumerate(taxa)}
    map_df = pd.DataFrame({"code": list(taxon_map.values()), "taxon": taxa})
    map_path = out_path.with_suffix(out_path.suffix + ".taxon_map.tsv")
    map_df.to_csv(map_path, sep="\t", index=False)

    pivot = grouped.pivot(index="Sample", columns="Taxon", values="Percent")
    pivot = pivot.fillna(0)

    ax = pivot.plot(kind="bar", stacked=True, figsize=(8, 5))
    ax.set_ylabel("Proportion of reads")
    xlabel = "Sample code" if args.code_samples else "Sample"
    ax.set_xlabel(xlabel)

    ax.legend(title="Taxon")
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    print(out_path.resolve())


if __name__ == "__main__":
    main()
