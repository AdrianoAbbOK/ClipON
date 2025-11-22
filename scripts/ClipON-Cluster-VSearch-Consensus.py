"""Generate per-sample consensus FASTA files from VSEARCH clustering outputs.

The script expects the exported FASTA file produced by QIIME2 (dna-sequences
from ``clustered-sequences``) and the corresponding feature table in TSV
format. For each feature present in a sample, a new FASTA record is emitted
with the number of supporting reads and the sample identifier in the header.

Output structure (within ``--output-dir``):
- ``<sample>/consensus_reference_<sample>.fasta`` for each sample present.
- ``consensos_todos.fasta`` combining all sample-level consensuses.
"""

from __future__ import annotations

import argparse
import pathlib


def read_sequences(fasta_path: pathlib.Path) -> dict[str, str]:
    """Load sequences from a FASTA file into a dictionary."""

    sequences: dict[str, str] = {}
    current_id: str | None = None
    parts: list[str] = []

    with fasta_path.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if current_id is not None:
                    sequences[current_id] = "".join(parts)
                current_id = line[1:]
                parts = []
            else:
                parts.append(line)

    if current_id is not None:
        sequences[current_id] = "".join(parts)

    return sequences


def read_feature_table(
    table_path: pathlib.Path,
) -> tuple[list[str], dict[str, dict[str, int]]]:
    """Parse a BIOM TSV feature table.

    Returns a tuple with the list of sample IDs and a mapping of feature IDs to
    counts per sample.
    """

    samples: list[str] = []
    counts: dict[str, dict[str, int]] = {}
    with table_path.open() as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line or line.startswith("# Constructed"):
                continue
            if line.startswith("#OTU ID"):
                _, *samples = line.split("\t")
                continue
            fields = line.split("\t")
            feature_id, raw_counts = fields[0], fields[1:]
            counts[feature_id] = {}
            for sample, value in zip(samples, raw_counts):
                if not value:
                    counts[feature_id][sample] = 0
                    continue

                numeric_value = int(float(value))
                counts[feature_id][sample] = numeric_value
    return samples, counts


def write_consensus_fastas(
    sequences: dict[str, str],
    samples: list[str],
    counts: dict[str, dict[str, int]],
    output_dir: pathlib.Path,
) -> None:
    """Write per-sample and combined consensus FASTA files."""

    output_dir.mkdir(parents=True, exist_ok=True)
    combined_path = output_dir / "consensos_todos.fasta"
    combined_handle = combined_path.open("w")

    sample_handles: dict[str, pathlib.Path] = {}

    try:
        for sample in samples:
            sample_dir = output_dir / sample
            sample_dir.mkdir(parents=True, exist_ok=True)
            sample_path = sample_dir / f"consensus_reference_{sample}.fasta"
            sample_handles[sample] = sample_path

        open_files = {sample: path.open("w") for sample, path in sample_handles.items()}

        for feature_id, per_sample in counts.items():
            sequence = sequences.get(feature_id)
            if sequence is None:
                continue
            for sample, count in per_sample.items():
                if count <= 0:
                    continue
                header = f">{feature_id}_total_supporting_reads_{count}_{sample}"
                record = f"{header}\n{sequence}\n"
                open_files[sample].write(record)
                combined_handle.write(record)
    finally:
        combined_handle.close()
        for handle in locals().get("open_files", {}).values():
            handle.close()

    print(f"Per-sample consensuses in: {output_dir}")
    print(f"Archivo maestro: {combined_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sequences",
        required=True,
        help="Exported dna-sequences.fasta",
    )
    parser.add_argument(
        "--table",
        required=True,
        help="BIOM table converted to TSV",
    )
    parser.add_argument(
        "--output-dir", required=True, help="Directory for consensus FASTA files"
    )
    args = parser.parse_args()

    sequences = read_sequences(pathlib.Path(args.sequences))
    samples, counts = read_feature_table(pathlib.Path(args.table))

    write_consensus_fastas(sequences, samples, counts, pathlib.Path(args.output_dir))


if __name__ == "__main__":
    main()
