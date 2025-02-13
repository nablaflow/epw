import polars as pl

from ._epw import parse

SCHEMA = pl.Schema(
    {
        "ts": pl.Datetime(time_unit="ms"),
        "wind_dir": pl.Float32(),
        "wind_speed": pl.Float32(),
    }
)


def parse_into_dataframe(buf: bytes, /, max_lines: int | None = None) -> pl.DataFrame:
    return pl.DataFrame(
        data=parse(buf, max_lines=max_lines),
        schema=SCHEMA,
    )
