import epw
from datetime import datetime
import pytest
import polars as pl
from polars.testing import assert_frame_equal


def test_empty() -> None:
    assert_frame_equal(
        epw.parse_into_dataframe(_gen_lines(0)),
        pl.DataFrame(schema=epw.SCHEMA),
    )


def test_one_line() -> None:
    assert_frame_equal(
        epw.parse_into_dataframe(_gen_lines(1)),
        pl.DataFrame(
            data={
                "ts": [datetime(2014, 1, 2, 2, 4, 0)],
                "wind_dir": [20.0],
                "wind_speed": [21.0],
            },
            schema=epw.SCHEMA,
        ),
    )


def test_errors() -> None:
    with pytest.raises(ValueError, match="Cannot parse column `Year` at line no. 9"):
        epw.parse_into_dataframe(_gen_lines(0) + b"a")

    with pytest.raises(
        ValueError, match="Missing column `Wind direction` at line no. 9"
    ):
        epw.parse_into_dataframe(_gen_lines(0) + b"1,2,3,4,5,6")


def _gen_lines(n: int) -> bytes:
    return b"\n\n\n\n\n\n\n\n" + (
        b"2014,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26\n"
        * n
    )
