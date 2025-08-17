import csv
import subprocess
import sys
from pathlib import Path


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


def test_collect_read_stats(tmp_path: Path) -> None:
    """Run collect_read_stats.py and validate TSV output."""
    fastq = create_fastq(tmp_path)
    out_tsv = tmp_path / "stats.tsv"
    script = Path(__file__).resolve().parents[1] / "scripts" / "collect_read_stats.py"

    subprocess.run(
        [sys.executable, str(script), str(fastq), str(out_tsv)],
        check=True,
    )

    with out_tsv.open() as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        rows = list(reader)

    assert rows == [
        {"read_id": "read1", "length": "4", "mean_quality": "40.00"},
        {"read_id": "read2", "length": "1", "mean_quality": "0.00"},
    ]
