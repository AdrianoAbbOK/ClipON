#!/usr/bin/env python3
"""Collect basic read statistics from a FASTQ file.

Outputs a TSV with per-read length and mean quality score.
Usage: python scripts/collect_read_stats.py <fastq> <output_tsv>
"""
import sys
import csv

if len(sys.argv) != 3:
    print("Usage: collect_read_stats.py <fastq> <output_tsv>", file=sys.stderr)
    sys.exit(1)

fastq_path = sys.argv[1]
out_tsv = sys.argv[2]

try:
    fh_fastq = open(fastq_path)
except OSError as e:
    print(f"Could not open FASTQ file: {e}", file=sys.stderr)
    sys.exit(1)

with fh_fastq, open(out_tsv, 'w', newline='') as out_fh:
    writer = csv.writer(out_fh, delimiter='\t')
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
        if length:
            mean_q = sum(ord(c) - 33 for c in qual) / length
        else:
            mean_q = 0
        writer.writerow([read_id, length, f"{mean_q:.2f}"])
