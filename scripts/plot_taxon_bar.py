#!/usr/bin/env python3
"""Generate a stacked bar plot of read proportions per sample.

Usage:
    python scripts/plot_taxon_bar.py <taxonomy.tsv> <output.png>
    python scripts/plot_taxon_bar.py <taxonomy.tsv> <output.png> --code-samples

The input TSV must contain at least the columns Sample, Taxon and Reads.
Empty or missing taxon names are replaced with "Unassigned" to ensure each
sample is represented. When ``--code-samples`` is provided, samples are
replaced by sequential codes (S1, S2, ...) and the mapping is written to
``<output>.sample_map.tsv``. Taxa are always replaced by codes (T1, T2, ...)
and their mapping is saved to ``<output>.taxon_map.tsv``.
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
    parser.add_argument(
        "--code-samples",
        action="store_true",
        help=(
            "Replace sample names with codes S1, S2, ... and save mapping to "
            "<output>.sample_map.tsv"
        ),
    )
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

    if args.code_samples:
        samples = sorted(data["Sample"].unique())
        sample_map = {sample: f"S{i+1}" for i, sample in enumerate(samples)}
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
    grouped["Taxon"] = grouped["Taxon"].map(taxon_map)

    pivot = grouped.pivot(index="Sample", columns="Taxon", values="Percent")
    pivot = pivot.fillna(0)

    ax = pivot.plot(kind="bar", stacked=True, figsize=(8, 5))
    ax.set_ylabel("Proportion of reads")
    xlabel = "Sample code" if args.code_samples else "Sample"
    ax.set_xlabel(xlabel)
    ax.legend(title="Taxon code (see TSV)")
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    print(out_path.resolve())


if __name__ == "__main__":
    main()
