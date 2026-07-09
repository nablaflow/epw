import epw
from datetime import datetime
import pytest


def test_empty() -> None:
    assert epw.parse(_gen_lines(0)) == {
        "ts": [],
        "wind_dir": [],
        "wind_speed": [],
    }


def test_one_line() -> None:
    assert epw.parse(_gen_lines(1)) == {
        "ts": [datetime(2014, 1, 2, 2, 4, 0)],
        "wind_dir": [20.0],
        "wind_speed": [21.0],
    }


def test_errors() -> None:
    with pytest.raises(ValueError, match="Cannot parse column `Year` at line no. 9"):
        epw.parse(_gen_lines(0) + b"a")

    with pytest.raises(
        ValueError, match="Missing column `Wind direction` at line no. 9"
    ):
        epw.parse(_gen_lines(0) + b"1,2,3,4,5,6")


def _gen_lines(n: int) -> bytes:
    return b"\n\n\n\n\n\n\n\n" + (
        b"2014,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26\n"
        * n
    )
