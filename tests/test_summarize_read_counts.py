import subprocess
import sys
from pathlib import Path


def write_stats(path, n):
    content = "header\n" + "\n".join(f"r{i}\tdata" for i in range(n)) + "\n"
    path.write_text(content)


def test_cleaned_files_update_filtered(tmp_path):
    write_stats(tmp_path / "CAV_37C01C_raw_stats.tsv", 2)
    write_stats(tmp_path / "SAV_926008_raw_stats.tsv", 2)
    write_stats(tmp_path / "cleaned_CAV_37C01C_filtered_stats.tsv", 3)
    write_stats(tmp_path / "cleaned_SAV_926008_filtered_stats.tsv", 4)

    script = Path(__file__).resolve().parents[1] / "scripts" / "summarize_read_counts.py"
    result = subprocess.run(
        [sys.executable, str(script), str(tmp_path)],
        check=True,
        capture_output=True,
        text=True,
    )

    lines = result.stdout.strip().splitlines()
    table = {}
    for line in lines[1:]:
        sample, raw, processed, filtered = line.split("\t")
        table[sample] = {
            "raw": int(raw),
            "processed": int(processed),
            "filtered": int(filtered),
        }

    assert table["CAV_37C01C"]["raw"] == 2
    assert table["CAV_37C01C"]["filtered"] == 3
    assert table["SAV_926008"]["raw"] == 2
    assert table["SAV_926008"]["filtered"] == 4
    assert "cleaned_CAV_37C01C" not in table
    assert "cleaned_SAV_926008" not in table


def test_trimmed_files_are_aggregated(tmp_path):
    write_stats(tmp_path / "sample_raw_stats.tsv", 2)
    write_stats(tmp_path / "sample_trimmed_raw_stats.tsv", 3)
    write_stats(tmp_path / "sample_processed_stats.tsv", 4)
    write_stats(tmp_path / "sample_trimmed_processed_stats.tsv", 5)

    script = Path(__file__).resolve().parents[1] / "scripts" / "summarize_read_counts.py"
    result = subprocess.run(
        [sys.executable, str(script), str(tmp_path)],
        check=True,
        capture_output=True,
        text=True,
    )

    lines = result.stdout.strip().splitlines()
    table = {}
    for line in lines[1:]:
        sample, raw, processed, filtered = line.split("\t")
        table[sample] = {
            "raw": int(raw),
            "processed": int(processed),
            "filtered": int(filtered),
        }

    assert table["sample"]["raw"] == 5
    assert table["sample"]["processed"] == 9
    assert "sample_trimmed" not in table


def test_metadata_mapping(tmp_path):
    write_stats(tmp_path / "s1_raw_stats.tsv", 1)
    write_stats(tmp_path / "s1_processed_stats.tsv", 2)
    write_stats(tmp_path / "s1_filtered_stats.tsv", 3)

    meta = tmp_path / "meta.tsv"
    meta.write_text("fastq\texperiment\ns1\tExpA\n")

    script = Path(__file__).resolve().parents[1] / "scripts" / "summarize_read_counts.py"
    result = subprocess.run(
        [sys.executable, str(script), str(tmp_path), "--metadata", str(meta)],
        check=True,
        capture_output=True,
        text=True,
    )

    lines = result.stdout.strip().splitlines()
    assert lines[1].startswith("ExpA")
