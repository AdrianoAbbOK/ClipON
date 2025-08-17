import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from summarize_read_counts import summarize_counts


def write_stats(path, n):
    content = "header\n" + "\n".join(f"r{i}\tdata" for i in range(n)) + "\n"
    path.write_text(content)


def test_cleaned_files_update_filtered(tmp_path):
    write_stats(tmp_path / "CAV_37C01C_raw_stats.tsv", 2)
    write_stats(tmp_path / "SAV_926008_raw_stats.tsv", 2)
    write_stats(tmp_path / "cleaned_CAV_37C01C_filtered_stats.tsv", 3)
    write_stats(tmp_path / "cleaned_SAV_926008_filtered_stats.tsv", 4)

    counts = summarize_counts(str(tmp_path), {})

    assert counts["CAV_37C01C"]["raw"] == 2
    assert counts["CAV_37C01C"]["filtered"] == 3
    assert counts["SAV_926008"]["raw"] == 2
    assert counts["SAV_926008"]["filtered"] == 4
    assert "cleaned_CAV_37C01C" not in counts
    assert "cleaned_SAV_926008" not in counts


def test_trimmed_files_are_aggregated(tmp_path):
    write_stats(tmp_path / "sample_raw_stats.tsv", 2)
    write_stats(tmp_path / "sample_trimmed_raw_stats.tsv", 3)
    write_stats(tmp_path / "sample_processed_stats.tsv", 4)
    write_stats(tmp_path / "sample_trimmed_processed_stats.tsv", 5)

    counts = summarize_counts(str(tmp_path), {})

    assert counts["sample"]["raw"] == 5
    assert counts["sample"]["processed"] == 9
    assert "sample_trimmed" not in counts


def test_metadata_mapping(tmp_path):
    write_stats(tmp_path / "s1_raw_stats.tsv", 1)
    write_stats(tmp_path / "s1_processed_stats.tsv", 2)
    write_stats(tmp_path / "s1_filtered_stats.tsv", 3)

    meta = tmp_path / "meta.tsv"
    meta.write_text("fastq\texperiment\ns1\tExpA\n")

    counts = summarize_counts(str(tmp_path), {"s1": "ExpA"})

    assert "ExpA" in counts
    assert counts["ExpA"]["filtered"] == 3
    assert "s1" not in counts
