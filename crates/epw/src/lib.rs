use chrono::{NaiveDate, NaiveDateTime};
use itertools::Itertools;
use polars::prelude::*;
use std::{
    io::{self, BufRead},
    str::FromStr,
};
use thiserror::Error;

const BASE_CAPACITY: usize = 8760 * 5;

pub struct EpwReader<T> {
    r: T,
    max_lines: Option<usize>,
}

impl<T: BufRead> EpwReader<T> {
    pub fn new(r: T) -> Self {
        Self { r, max_lines: None }
    }

    #[must_use]
    pub fn set_max_lines(mut self, max_lines: usize) -> Self {
        self.max_lines = Some(max_lines);
        self
    }

    #[allow(clippy::missing_errors_doc)]
    pub fn parse(self) -> Result<DataFrame, Error> {
        let lines = self
            .r
            .lines()
            .enumerate()
            .map(|(idx, line)| (idx + 1, line));

        let mut timestamps = Vec::<NaiveDateTime>::with_capacity(BASE_CAPACITY);
        let mut wind_speed = Vec::<f32>::with_capacity(BASE_CAPACITY);
        let mut wind_dir = Vec::<f32>::with_capacity(BASE_CAPACITY);

        for (actual_lines, (line_no, line)) in lines.skip(8).enumerate() {
            if let Some(max_lines) = self.max_lines {
                if actual_lines > max_lines {
                    return Err(Error::MaxLinesReached { max_lines });
                }
            }

            let line = line?;
            let cols = line.split(',').collect_vec();

            timestamps.push(compose_ts(&cols, line_no)?);
            wind_dir.push(parse_col(&cols, "Wind direction", 20, line_no)?);
            wind_speed.push(parse_col(&cols, "Wind speed", 21, line_no)?);
        }

        Ok(DataFrame::new(vec![
            Series::new("ts".into(), timestamps).into(),
            Series::from_vec("wind_dir".into(), wind_dir).into(),
            Series::from_vec("wind_speed".into(), wind_speed).into(),
        ])?)
    }
}

fn compose_ts(cols: &[&str], line_no: usize) -> Result<NaiveDateTime, Error> {
    let year: i32 = parse_col(cols, "Year", 0, line_no)?;
    let month: u32 = parse_col(cols, "Month", 1, line_no)?;
    let day: u32 = parse_col(cols, "Day", 2, line_no)?;
    let hour: u32 = parse_col(cols, "Hour", 3, line_no)?;
    let minute: u32 = parse_col(cols, "Minute", 4, line_no)?;

    NaiveDate::from_ymd_opt(year, month, day)
        .ok_or(Error::InvalidTimestamp { line_no })?
        .and_hms_opt(
            hour.checked_sub(1)
                .ok_or(Error::InvalidTimestamp { line_no })?,
            minute,
            0,
        )
        .ok_or(Error::InvalidTimestamp { line_no })
}

fn parse_col<T>(cols: &[&str], name: &'static str, idx: usize, line_no: usize) -> Result<T, Error>
where
    T: std::fmt::Debug + FromStr,
{
    let col = cols
        .get(idx)
        .ok_or(Error::MissingColumn { line_no, name })?;

    col.parse::<T>()
        .map_err(|_err| Error::CannotParseColumn { line_no, name })
}

#[derive(Error, Debug)]
pub enum Error {
    #[error("I/O error {0:?}")]
    Io(#[from] io::Error),

    #[error("Missing column `{name}` at line no. {line_no}")]
    MissingColumn { name: &'static str, line_no: usize },

    #[error("Cannot parse column `{name}` at line no. {line_no}")]
    CannotParseColumn { name: &'static str, line_no: usize },

    #[error("Invalid timestamp at line no. {line_no}")]
    InvalidTimestamp { line_no: usize },

    #[error("Failed to compose DataFrame: {0:?}")]
    Polars(#[from] PolarsError),

    #[error("Max amount of lines ({max_lines}) reached")]
    MaxLinesReached { max_lines: usize },
}

#[cfg(test)]
mod tests {
    use super::*;
    use insta::assert_snapshot;
    use pretty_assertions::assert_matches;
    use std::io::{BufReader, Cursor};

    const EXAMPLE_1: Cursor<&[u8]> = Cursor::new(include_bytes!("fixtures/example1.epw"));
    const MISSING_COLS: Cursor<&[u8]> = Cursor::new(include_bytes!("fixtures/missing_columns.epw"));
    const CANNOT_PARSE_COL: Cursor<&[u8]> =
        Cursor::new(include_bytes!("fixtures/bad_wind_dir_col.epw"));
    const INVALID_TIMESTAMP: Cursor<&[u8]> =
        Cursor::new(include_bytes!("fixtures/invalid_timestamp.epw"));

    #[test]
    fn fixture_1() {
        let df = EpwReader::new(BufReader::new(EXAMPLE_1)).parse().unwrap();
        assert_snapshot!(df_to_json(df));
    }

    #[test]
    fn over_max_lines() {
        let res = EpwReader::new(BufReader::new(EXAMPLE_1))
            .set_max_lines(5)
            .parse();

        assert_matches!(res, Err(Error::MaxLinesReached { max_lines: 5 }));
    }

    #[test]
    fn missing_cols() {
        let res = EpwReader::new(BufReader::new(MISSING_COLS)).parse();

        assert_matches!(
            res,
            Err(Error::MissingColumn {
                name: "Wind direction",
                line_no: 9
            })
        );
    }

    #[test]
    fn cannot_parse_col() {
        let res = EpwReader::new(BufReader::new(CANNOT_PARSE_COL)).parse();

        assert_matches!(
            res,
            Err(Error::CannotParseColumn {
                name: "Wind direction",
                line_no: 9
            })
        );
    }

    #[test]
    fn invalid_timestamp() {
        let res = EpwReader::new(BufReader::new(INVALID_TIMESTAMP)).parse();

        assert_matches!(res, Err(Error::InvalidTimestamp { line_no: 12 }));
    }

    fn df_to_json(mut df: DataFrame) -> String {
        let mut buf = Cursor::new(Vec::new());

        JsonWriter::new(&mut buf)
            .with_json_format(JsonFormat::JsonLines)
            .finish(&mut df)
            .unwrap();

        String::from_utf8(buf.into_inner()).unwrap()
    }
}
