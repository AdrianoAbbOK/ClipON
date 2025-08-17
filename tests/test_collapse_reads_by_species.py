import subprocess
import sys
from pathlib import Path


def test_collapse_reads(tmp_path):
    table = (
        "Feature ID\tTaxon\tConsensus\tReads\tSample\n"
        "id1\tk__Bacteria; g__Escherichia; s__coli\tC1\t10\tS1\n"
        "id2\tk__Bacteria; g__Bacillus\tC2\t5\tS1\n"
        "id3\tk__Bacteria f__Bacillaceae\tC3\t20\tS2\n"
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
    assert lines[2].startswith("*Escherichia coli*\t10\t")
    assert lines[3].startswith("*Bacillus* (genus)\t5\t")
    assert lines[4] == "Sample: S2"
    assert lines[5] == "Species\tReads\tProportion"
    assert lines[6].startswith("Bacillaceae (family)\t20\t")
    assert lines[6].endswith("100.00")
