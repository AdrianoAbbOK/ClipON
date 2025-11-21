#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: $0 [--output FILE] (--filtered DIR | --unified DIR | --workdir DIR STEP)

Generate a QIIME2 manifest from the ClipON pipeline outputs.

  --filtered DIR       Directory containing filtered FASTQ files.
  --unified DIR        Directory produced by the unification step.
  --workdir DIR STEP   Use DIR/3_filtered or DIR/5_unified depending on STEP
                       (filtered|unified).
  -o, --output FILE    Write the manifest TSV to FILE (with Unix line endings).
EOF
    exit 1
}

mode=""
input_dir=""
output_file=""
workdir_step=""

while (($#)); do
    case "$1" in
        --filtered|--unified)
            mode="$1"
            input_dir="${2-}"
            shift 2
            ;;
        --workdir)
            mode="$1"
            input_dir="${2-}"
            workdir_step="${3-}"
            shift 3
            ;;
        -o|--output)
            output_file="${2-}"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$mode" || -z "$input_dir" ]]; then
    usage
fi

if [ "$mode" = "--workdir" ]; then
    case "$workdir_step" in
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

write_manifest() {
    local dest="$1"

    printf 'sample-id\tabsolute-filepath\tdirection\n' >"$dest"

    case "$mode" in
        --filtered)
            shopt -s nullglob
            for f in "$input_dir"/*.fastq "$input_dir"/*.fq; do
                [ -f "$f" ] || continue
                sample=$(basename "$f")
                sample=${sample%.fastq}
                sample=${sample%.fq}
                abs=$(readlink -f "$f")
                printf '%s\t%s\t%s\n' "$sample" "$abs" "forward" >>"$dest"
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
                printf '%s\t%s\t%s\n' "$sample" "$abs" "forward" >>"$dest"
            done
            ;;
        *)
            usage
            ;;
    esac
}

if [ -n "$output_file" ]; then
    tmp_file="$(mktemp)"
    trap 'rm -f "$tmp_file"' EXIT

    write_manifest "$tmp_file"

    if command -v dos2unix >/dev/null; then
        dos2unix "$tmp_file" >/dev/null 2>&1
    else
        sed -i 's/\r$//' "$tmp_file"
    fi

    mkdir -p "$(dirname "$output_file")"
    mv "$tmp_file" "$output_file"
    trap - EXIT
else
    write_manifest /dev/stdout
fi
