import subprocess
import sys
from pathlib import Path


def test_collapse_reads(tmp_path):
    table = (
        "Feature ID\tTaxon\tConsensus\tReads\tSample\n"
        "id1\tSpecies A\tC1\t10\tS1\n"
        "id2\tSpecies B\tC2\t5\tS1\n"
        "id3\tSpecies A\tC3\t20\tS2\n"
    )
    in_file = tmp_path / "taxonomy_with_sample.tsv"
    in_file.write_text(table)

    script = (
        Path(__file__).resolve().parents[1]
        / "scripts"
        / "collapse_reads_by_species.py"
    )
    result = subprocess.run(
        [sys.executable, str(script), str(in_file)],
        check=True,
        capture_output=True,
        text=True,
    )

    lines = [line.strip() for line in result.stdout.strip().splitlines() if line.strip()]

    assert lines[0] == "Sample: S1"
    assert lines[1] == "Species\tReads\tProportion"
    assert lines[2].startswith("Species A\t10\t")
    assert lines[3].startswith("Species B\t5\t")
    assert lines[4] == "Sample: S2"
    assert "100.00" in lines[-1]
