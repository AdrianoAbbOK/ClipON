#!/usr/bin/env python3
"""Collect basic read statistics from a FASTQ file.

Outputs a TSV with per-read length and mean quality score.
Usage: collect_read_stats.py FASTQ OUTPUT_TSV
"""
import argparse
import csv
import sys


def collect_read_stats(fastq_path: str, out_tsv: str) -> None:
    """Collect per-read length and mean quality from a FASTQ file.

    Parameters
    ----------
    fastq_path: str
        Path to the input FASTQ file.
    out_tsv: str
        Path to the TSV file that will store per-read statistics.
    """
    with open(fastq_path) as fh_fastq, open(out_tsv, "w", newline="") as out_fh:
        writer = csv.writer(out_fh, delimiter="\t")
        writer.writerow(["read_id", "length", "mean_quality"])

        while True:
            header = fh_fastq.readline().rstrip()
            if not header:
                break
            seq = fh_fastq.readline().rstrip()
            fh_fastq.readline()  # skip plus line
            qual = fh_fastq.readline().rstrip()

            read_id = header[1:].split()[0]
            length = len(seq)
            mean_q = (
                sum(ord(c) - 33 for c in qual) / length if length else 0
            )
            writer.writerow([read_id, length, f"{mean_q:.2f}"])


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Collect basic read statistics from a FASTQ file."
    )
    parser.add_argument("fastq", help="Path to the input FASTQ file.")
    parser.add_argument(
        "output_tsv", help="Path to write the per-read statistics in TSV format."
    )
    return parser.parse_args()


def main() -> None:
    """Entry point for command-line execution."""
    args = parse_args()
    try:
        collect_read_stats(args.fastq, args.output_tsv)
    except OSError as e:
        print(f"Could not open FASTQ file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
