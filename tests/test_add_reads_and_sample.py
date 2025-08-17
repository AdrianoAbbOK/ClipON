import csv
import subprocess
import sys
from pathlib import Path


def run_script(input_text: str, tmp_path: Path, metadata: Path | None = None) -> Path:
    in_file = tmp_path / "taxonomy.tsv"
    in_file.write_text(input_text)
    script = Path(__file__).resolve().parents[1] / "scripts" / "add_reads_and_sample.py"
    cmd = [sys.executable, str(script), str(in_file)]
    if metadata is not None:
        cmd.extend(["--metadata", str(metadata)])
    subprocess.run(cmd, check=True)
    return in_file.with_name("taxonomy_with_sample.tsv")


def read_samples(path: Path) -> list[str]:
    with path.open() as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        return [row["Sample"] for row in reader]


def test_clean_prefix_suffix(tmp_path):
    table = (
        "Feature ID\tTaxon\tConsensus\n"
        "foo_total_supporting_reads_10_cleaned_S1_trimmed\tSp1\t1\n"
    )
    out_file = run_script(table, tmp_path)
    samples = read_samples(out_file)
    assert samples == ["S1"]


def test_metadata_replacement(tmp_path):
    table = (
        "Feature ID\tTaxon\tConsensus\n"
        "foo_total_supporting_reads_10_cleaned_S1_trimmed\tSp1\t1\n"
    )
    meta = tmp_path / "meta.tsv"
    meta.write_text("fastq\texperiment\nS1\tExp1\n")
    out_file = run_script(table, tmp_path, metadata=meta)
    samples = read_samples(out_file)
    assert samples == ["Exp1"]

