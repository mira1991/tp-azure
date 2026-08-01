"""Fixtures pytest partagées."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


@pytest.fixture()
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture()
def fixtures_dir() -> Path:
    return FIXTURES_DIR


@pytest.fixture()
def sample_outputs_file() -> Path:
    return FIXTURES_DIR / "terraform-outputs.json"


@pytest.fixture()
def sample_outputs(sample_outputs_file: Path) -> dict[str, Any]:
    with sample_outputs_file.open(encoding="utf-8") as handle:
        return {name: payload["value"] for name, payload in json.load(handle).items()}


@pytest.fixture()
def live_outputs_file() -> Path:
    """Outputs Terraform réels (jobs d'intégration) — skip hors pipeline."""
    path = os.environ.get("TF_OUTPUTS_FILE", "")
    if not path or not Path(path).exists():
        pytest.skip("TF_OUTPUTS_FILE absent : test d'intégration exécutable uniquement en pipeline.")
    return Path(path)


@pytest.fixture()
def live_outputs(live_outputs_file: Path) -> dict[str, Any]:
    with live_outputs_file.open(encoding="utf-8") as handle:
        return {name: payload["value"] for name, payload in json.load(handle).items()}
