#!/bin/bash
set -e
set -u
set -o pipefail

usage() {
    cat >&2 <<'EOF'
Usage: $0 (--filtered DIR | --unified DIR | --workdir DIR STEP)

Generate a QIIME2 manifest from the ClipON pipeline outputs.

  --filtered DIR      Directory containing filtered FASTQ files.
  --unified DIR       Directory produced by the unification step.
  --workdir DIR STEP  Use DIR/3_filtered or DIR/5_unified depending on STEP
                      (filtered|unified).
EOF
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

mode="$1"
input_dir="$2"

if [ "$mode" = "--workdir" ]; then
    if [ "$#" -ne 3 ]; then
        usage
    fi
    case "$3" in
        filtered)
            mode="--filtered"
            input_dir="$input_dir/3_filtered"
            ;;
        unified)
            mode="--unified"
            input_dir="$input_dir/5_unified"
            ;;
        *)
            usage
            ;;
    esac
fi

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
    --unified)
        shopt -s nullglob
        for f in "$input_dir"/consensos_*.fasta; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            sample=${base#consensos_}
            sample=${sample%.fasta}
            abs=$(readlink -f "$f")
            echo "${sample},${abs},forward"
        done
        ;;
    *)
        usage
        ;;
esac
