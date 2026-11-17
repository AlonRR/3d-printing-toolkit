# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""add_brim_ears.py's STL reader on a file that is not a binary STL. A text STL's bytes 80-83 are ASCII, so read
as a facet count they claim hundreds of millions of facets: the box fixture's four spaces claim 538,976,288, about
27 GB. The reader must refuse from the file's size, never by asking for that many bytes first: the request alone
can raise MemoryError, which is how the golden case ears-not-binary failed in some runs with other suites running."""

import builtins
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import add_brim_ears

ROOT = Path(__file__).resolve().parents[1]
TEXT_STL = ROOT / "tests" / "fixtures" / "box.stl"


class _Recording:
    """A file that refuses any read larger than the file itself, and records each size asked for."""

    def __init__(self, f, size, asked):
        self._f, self._size, self._asked = f, size, asked

    def read(self, n=-1):
        self._asked.append(n)
        if n > self._size:
            raise AssertionError(f"read({n}) asked for more than the file's {self._size} bytes")
        return self._f.read(n)

    def __getattr__(self, name):
        return getattr(self._f, name)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self._f.close()


@pytest.fixture
def asked(monkeypatch):
    sizes = []

    def recording_open(path, mode="r", *args, **kwargs):
        f = builtins.open(path, mode, *args, **kwargs)
        return _Recording(f, Path(path).stat().st_size, sizes)

    monkeypatch.setattr(add_brim_ears, "open", recording_open, raising=False)
    return sizes


def test_text_stl_refused_without_reading_its_claimed_size(asked):
    size = TEXT_STL.stat().st_size
    with pytest.raises(SystemExit) as exc:
        add_brim_ears.read_stl(TEXT_STL)
    assert str(exc.value) == (
        f"{TEXT_STL}: not a binary STL, or truncated "
        f"(header claims 538976288 facets = {538976288 * 50} bytes, got {size - 84})"
    )
    assert asked and max(asked) <= size


def test_binary_stl_still_reads(asked, tmp_path):
    rec, tri = add_brim_ears.read_stl(ROOT / "tests" / "fixtures" / "ell.stl")
    assert rec.shape[1] == 50 and tri.shape == (len(rec), 3, 3)


@pytest.mark.parametrize(
    ("option", "value", "floor"),
    [("--diameter", "3", "the smallest ear tried is 4 mm"), ("--overlap", "1", "the smallest overlap tried is 1.5 mm")],
)
def test_sizes_that_cannot_place_an_ear_are_refused(option, value, floor, tmp_path, capsys):
    """Below these, place_ears tries no size at all, and used to crash on its unset skip reason."""
    stl = tmp_path / "ell.stl"
    stl.write_bytes((ROOT / "tests" / "fixtures" / "ell.stl").read_bytes())
    with pytest.raises(SystemExit) as exc:
        add_brim_ears.main(["add_brim_ears.py", str(stl), option, value, "--dry-run"])
    assert exc.value.code == 2
    assert floor in capsys.readouterr().err


def test_trailing_bytes_still_accepted(asked, tmp_path):
    padded = tmp_path / "padded.stl"
    padded.write_bytes((ROOT / "tests" / "fixtures" / "ell.stl").read_bytes() + b"\0" * 7)
    rec, _ = add_brim_ears.read_stl(padded)
    assert len(rec) > 0
