"""Tests for the main ClipON pipeline."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def _write_dummy_fastq(path: Path) -> None:
    """Create a minimal FASTQ file at ``path``."""
    content = "@r1\nACGT\n+\n!!!!\n"
    path.write_text(content)


def test_run_clipon_pipeline_vsearch_creates_taxonomy(tmp_path: Path) -> None:
    """Pipeline with VSearch creates ``taxonomy.qza`` in the unified directory."""
    input_dir = tmp_path / "input"
    work_dir = tmp_path / "work"
    input_dir.mkdir()
    work_dir.mkdir()
    _write_dummy_fastq(input_dir / "sample.fastq")

    env = os.environ.copy()
    env.update({"CLUSTER_METHOD": "vsearch", "RESUME_STEP": "4"})
    subprocess.run(
        ["bash", "scripts/run_clipon_pipeline.sh", str(input_dir), str(work_dir)],
        cwd=REPO_ROOT,
        env=env,
        check=True,
        text=True,
        input="\n",
        capture_output=True,
    )

    taxonomy = work_dir / "5_unified" / "taxonomy.qza"
    assert taxonomy.exists(), "taxonomy.qza was not created"


def test_run_clipon_pipeline_ngspecies_skips_steps(tmp_path: Path) -> None:
    """Default pipeline with ``ngspecies`` can skip heavy steps."""
    input_dir = tmp_path / "input"
    work_dir = tmp_path / "work"
    input_dir.mkdir()
    work_dir.mkdir()
    unified_dir = work_dir / "5_unified"
    unified_dir.mkdir(parents=True)
    (unified_dir / "consensos_todos.fasta").write_text(
        ">consensus\nACGT\n"
    )

    env = os.environ.copy()
    env["RESUME_STEP"] = "8"
    subprocess.run(
        ["bash", "scripts/run_clipon_pipeline.sh", str(input_dir), str(work_dir)],
        cwd=REPO_ROOT,
        env=env,
        check=True,
        text=True,
        input="\n",
        capture_output=True,
    )

    assert (unified_dir / "consensos_todos.fasta").exists()
