#!/usr/bin/env python3
"""Generate a stacked bar plot of read proportions per sample.

Usage:
    python scripts/plot_taxon_bar.py <taxonomy.tsv> <output.png>

The input TSV must contain at least the columns Sample, Taxon and Reads.
Empty or missing taxon names are replaced with "Unassigned" to ensure each
sample is represented.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="TSV file with Sample, Taxon and Reads")
    parser.add_argument("output", help="Path for the generated PNG plot")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    in_path = Path(args.input)
    out_path = Path(args.output)

    data = pd.read_csv(in_path, sep="\t", dtype=str)

    data["Reads"] = pd.to_numeric(data["Reads"], errors="coerce")
    data["Taxon"] = data["Taxon"].fillna("").replace("", "Unassigned")
    data = data[~data["Reads"].isna() & (data["Reads"] > 0)]

    if data.empty:
        raise ValueError("No valid reads found in input file")

    grouped = data.groupby(["Sample", "Taxon"], as_index=False)["Reads"].sum()
    grouped["Percent"] = grouped.groupby("Sample")["Reads"].transform(
        lambda x: x / x.sum()
    )

    pivot = grouped.pivot(index="Sample", columns="Taxon", values="Percent")
    pivot = pivot.fillna(0)

    ax = pivot.plot(kind="bar", stacked=True, figsize=(8, 5))
    ax.set_ylabel("Proportion of reads")
    ax.set_xlabel("Sample")
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    print(out_path.resolve())


if __name__ == "__main__":
    main()
