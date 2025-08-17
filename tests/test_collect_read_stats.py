import csv
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from collect_read_stats import collect_read_stats  # type: ignore


def create_fastq(tmp_path: Path) -> Path:
    """Create a minimal FASTQ file with two reads."""
    content = (
        "@read1\n"
        "ACGT\n"
        "+\n"
        "IIII\n"
        "@read2\n"
        "A\n"
        "+\n"
        "!\n"
    )
    path = tmp_path / "reads.fastq"
    path.write_text(content)
    return path


def validate_output(out_tsv: Path) -> None:
    """Validate the generated TSV file."""
    with out_tsv.open() as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        rows = list(reader)
    assert rows == [
        {"read_id": "read1", "length": "4", "mean_quality": "40.00"},
        {"read_id": "read2", "length": "1", "mean_quality": "0.00"},
    ]


def test_collect_read_stats_function(tmp_path: Path) -> None:
    """Call collect_read_stats directly and validate output."""
    fastq = create_fastq(tmp_path)
    out_tsv = tmp_path / "stats.tsv"

    collect_read_stats(str(fastq), str(out_tsv))
    validate_output(out_tsv)


def test_collect_read_stats_cli(tmp_path: Path) -> None:
    """Run the script via subprocess and validate output."""
    fastq = create_fastq(tmp_path)
    out_tsv = tmp_path / "stats.tsv"
    script = Path(__file__).resolve().parents[1] / "scripts" / "collect_read_stats.py"

    subprocess.run(
        [sys.executable, str(script), str(fastq), str(out_tsv)],
        check=True,
    )
    validate_output(out_tsv)
