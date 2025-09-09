#!/usr/bin/env python3
"""Add reads and sample columns to a QIIME taxonomy table.

Extracts the number of supporting reads and the sample code from the
``Feature ID`` column produced by NGSpeciesID and writes a new TSV with
columns ``Feature ID``, ``Taxon``, ``Consensus``, ``Reads`` and ``Sample``.
Sample names can optionally be replaced by experiment identifiers using a
metadata file with columns ``fastq`` and ``experiment``.
"""

import argparse
import csv
import pathlib
import re


KNOWN_PREFIXES = ["cleaned_", "filtered_", "trimmed_"]
KNOWN_SUFFIXES = ["_trimmed", "_filtered", "_cleaned"]


def clean_fastq_name(name: str) -> str:
    """Remove common processing prefixes and suffixes from a FASTQ name."""
    for prefix in KNOWN_PREFIXES:
        if name.startswith(prefix):
            name = name[len(prefix) :]
    for suffix in KNOWN_SUFFIXES:
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def load_metadata(path: str | None) -> dict[str, str]:
    mapping: dict[str, str] = {}
    if not path:
        return mapping
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            fastq = pathlib.Path(row["fastq"]).stem
            mapping[fastq] = row["experiment"]
    return mapping


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("taxonomy", help="Input QIIME taxonomy.tsv file")
    parser.add_argument("--metadata", help="TSV/CSV with fastq-experiment mapping")
    args = parser.parse_args()

    in_path = pathlib.Path(args.taxonomy)
    out_path = in_path.with_name("taxonomy_with_sample.tsv")
    mapping = load_metadata(args.metadata)

    with in_path.open() as fin, out_path.open("w", newline="") as fout:
        reader = csv.DictReader(fin, delimiter="\t")
        fieldnames = ["Feature ID", "Taxon", "Consensus", "Reads", "Sample"]
        writer = csv.DictWriter(fout, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for row in reader:
            fid = row["Feature ID"]
            m = re.search(r"_total_supporting_reads_(\d+)_(.+)$", fid)
            if not m:
                raise ValueError(f"Could not parse Feature ID: {fid}")
            reads, sample = m.groups()
            base_id = fid[: m.start()]
            if sample in mapping:
                sample = mapping[sample]
            else:
                cleaned = clean_fastq_name(sample)
                sample = mapping.get(cleaned, cleaned)
            writer.writerow(
                {
                    "Feature ID": base_id,
                    "Taxon": row["Taxon"],
                    "Consensus": row["Consensus"],
                    "Reads": reads,
                    "Sample": sample,
                }
            )

    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
