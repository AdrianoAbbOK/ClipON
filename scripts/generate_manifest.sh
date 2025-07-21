#!/bin/bash
set -e
set -u
set -o pipefail

usage() {
    echo "Usage: $0 (--filtered DIR | --ngspecies DIR)" >&2
    exit 1
}

if [ "$#" -ne 2 ]; then
    usage
fi

mode="$1"
input_dir="$2"

if [ ! -d "$input_dir" ]; then
    echo "Directory not found: $input_dir" >&2
    exit 1
fi

# Print CSV header
echo "sample-id,absolute-filepath,direction"

case "$mode" in
    --filtered)
        shopt -s nullglob
        for f in "$input_dir"/*.fastq "$input_dir"/*.fq; do
            [ -f "$f" ] || continue
            sample=$(basename "$f")
            sample=${sample%.fastq}
            sample=${sample%.fq}
            abs=$(readlink -f "$f")
            echo "${sample},${abs},forward"
        done
        ;;
    --ngspecies)
        for d in "$input_dir"/*; do
            [ -d "$d" ] || continue
            sample=$(basename "$d")
            file=""
            if [ -f "$d/consensus.fastq" ]; then
                file="$d/consensus.fastq"
            elif [ -f "$d/consensus.fasta" ]; then
                file="$d/consensus.fasta"
            else
                candidate=$(find "$d" -maxdepth 1 -type f \( -name '*.fastq' -o -name '*.fasta' -o -name '*.fa' \) | head -n 1)
                if [ -n "$candidate" ]; then
                    file="$candidate"
                else
                    continue
                fi
            fi
            abs=$(readlink -f "$file")
            echo "${sample},${abs},forward"
        done
        ;;
    *)
        usage
        ;;
esac
