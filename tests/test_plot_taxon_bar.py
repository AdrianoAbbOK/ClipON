import os
import subprocess
import sys
from pathlib import Path


def test_sample_codes(tmp_path):
    table = (
        "Sample\tTaxon\tReads\n" "A\tSp1\t10\n" "B\tSp2\t5\n"
    )
    in_file = tmp_path / "taxonomy.tsv"
    in_file.write_text(table)
    out_file = tmp_path / "plot.png"

    script = Path(__file__).resolve().parents[1] / "scripts" / "plot_taxon_bar.py"
    env = os.environ.copy()
    env["MPLBACKEND"] = "Agg"
    subprocess.run(
        [
            sys.executable,
            str(script),
            str(in_file),
            str(out_file),
            "--code-samples",
        ],
        check=True,
        env=env,
    )

    map_file = tmp_path / "plot.png.sample_map.tsv"
    content = map_file.read_text().strip().splitlines()
    assert content[0] == "code\tsample"
    assert content[1] == "M1\tA"
    assert content[2] == "M2\tB"


def test_metadata_mapping(tmp_path):
    table = "Sample\tTaxon\tReads\nA\tSp1\t10\n"
    in_file = tmp_path / "taxonomy.tsv"
    in_file.write_text(table)
    out_file = tmp_path / "plot.png"

    meta = tmp_path / "meta.tsv"
    meta.write_text("fastq\texperiment\nA\tExp1\n")

    script = Path(__file__).resolve().parents[1] / "scripts" / "plot_taxon_bar.py"
    env = os.environ.copy()
    env["MPLBACKEND"] = "Agg"
    subprocess.run(
        [
            sys.executable,
            str(script),
            str(in_file),
            str(out_file),
            "--metadata",
            str(meta),
            "--code-samples",
        ],
        check=True,
        env=env,
    )

    map_file = tmp_path / "plot.png.sample_map.tsv"
    content = map_file.read_text().strip().splitlines()
    assert content[1] == "M1\tExp1"
