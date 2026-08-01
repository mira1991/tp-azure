"""Tests unitaires de scripts/validate-inputs.py."""

from __future__ import annotations

import importlib.util
import shutil
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent.parent


def load_script(name: str):
    path = REPO_ROOT / "scripts" / name
    spec = importlib.util.spec_from_file_location(name.replace("-", "_").removesuffix(".py"), path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


validate_inputs = load_script("validate-inputs.py")


def test_repo_config_is_valid() -> None:
    assert validate_inputs.main(["--config-dir", str(REPO_ROOT / "config")]) == 0


def _copy_config(tmp_path: Path) -> Path:
    config_dir = tmp_path / "config"
    shutil.copytree(REPO_ROOT / "config", config_dir)
    return config_dir


def test_missing_management_first_fails(tmp_path: Path, capsys) -> None:
    config_dir = _copy_config(tmp_path)
    profiles_path = config_dir / "profiles.yml"
    profiles = yaml.safe_load(profiles_path.read_text(encoding="utf-8"))
    profiles["profiles"]["minimal"]["nodes"]["aio"]["networks"] = ["internal_api", "management"]
    profiles_path.write_text(yaml.safe_dump(profiles), encoding="utf-8")

    assert validate_inputs.main(["--config-dir", str(config_dir)]) == 1
    assert "management" in capsys.readouterr().err


def test_unknown_network_role_fails(tmp_path: Path, capsys) -> None:
    config_dir = _copy_config(tmp_path)
    profiles_path = config_dir / "profiles.yml"
    profiles = yaml.safe_load(profiles_path.read_text(encoding="utf-8"))
    profiles["profiles"]["minimal"]["nodes"]["aio"]["networks"] = ["management", "does_not_exist"]
    profiles_path.write_text(yaml.safe_dump(profiles), encoding="utf-8")

    assert validate_inputs.main(["--config-dir", str(config_dir)]) == 1
    assert "does_not_exist" in capsys.readouterr().err


def test_unknown_node_role_fails(tmp_path: Path, capsys) -> None:
    config_dir = _copy_config(tmp_path)
    profiles_path = config_dir / "profiles.yml"
    profiles = yaml.safe_load(profiles_path.read_text(encoding="utf-8"))
    profiles["profiles"]["minimal"]["nodes"]["mystery"] = {
        "count": 1,
        "vcpu": 2,
        "memory_mb": 2048,
        "disk_gb": 20,
        "networks": ["management"],
    }
    profiles_path.write_text(yaml.safe_dump(profiles), encoding="utf-8")

    assert validate_inputs.main(["--config-dir", str(config_dir)]) == 1
    assert "mystery" in capsys.readouterr().err


def test_invalid_schema_fails(tmp_path: Path, capsys) -> None:
    config_dir = _copy_config(tmp_path)
    profiles_path = config_dir / "profiles.yml"
    profiles = yaml.safe_load(profiles_path.read_text(encoding="utf-8"))
    profiles["profiles"]["minimal"]["nodes"]["aio"]["count"] = 0
    profiles_path.write_text(yaml.safe_dump(profiles), encoding="utf-8")

    assert validate_inputs.main(["--config-dir", str(config_dir)]) == 1
    assert "count" in capsys.readouterr().err
