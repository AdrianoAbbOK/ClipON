#!/usr/bin/env python3
"""Add reads and sample columns to a QIIME taxonomy table.

Extracts the number of supporting reads and the sample code from the
``Feature ID`` column produced by NGSpeciesID and writes a new TSV with
columns ``Feature ID``, ``Taxon``, ``Consensus``, ``Reads`` and ``Sample``.

Usage:
    python scripts/add_reads_and_sample.py taxonomy.tsv
The output ``taxonomy_with_sample.tsv`` is written in the same directory.
"""

import csv
import pathlib
import re
import sys


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: add_reads_and_sample.py <taxonomy.tsv>", file=sys.stderr)
        sys.exit(1)

    in_path = pathlib.Path(sys.argv[1])
    out_path = in_path.with_name("taxonomy_with_sample.tsv")

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
