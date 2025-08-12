#!/usr/bin/env python3
import sys
import os

def compute_stats(path):
    total_reads = 0
    total_len = 0
    total_qual = 0
    with open(path, 'r', encoding='utf-8') as fh:
        while True:
            header = fh.readline()
            if not header:
                break
            seq = fh.readline().strip()
            fh.readline()  # plus line
            qual = fh.readline().strip()
            total_reads += 1
            total_len += len(seq)
            total_qual += sum(ord(c) - 33 for c in qual)
    avg_len = total_len / total_reads if total_reads else 0
    avg_qual = total_qual / total_len if total_len else 0
    return total_reads, avg_len, avg_qual


def main():
    if len(sys.argv) != 2:
        print("Uso: collect_read_stats.py <archivo_fastq>", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    reads, avg_len, avg_qual = compute_stats(path)
    print(f"{os.path.basename(path)}\t{reads}\t{avg_len:.2f}\t{avg_qual:.2f}")


if __name__ == "__main__":
    main()
