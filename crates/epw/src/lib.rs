#![allow(clippy::missing_errors_doc)]

use chrono::{NaiveDate, NaiveDateTime};
use itertools::Itertools;
use std::{
    io::{self, BufRead, BufReader},
    marker::PhantomData,
    str::FromStr,
};
use thiserror::Error;

const BASE_CAPACITY: usize = 8760 * 5;

#[derive(Debug)]
#[cfg_attr(test, derive(serde::Serialize))]
pub struct Epw {
    pub ts: Vec<NaiveDateTime>,
    pub wind_speed: Vec<f32>,
    pub wind_dir: Vec<f32>,
}

pub struct EpwReader<'a, T> {
    r: T,
    max_lines: Option<usize>,
    phantom: PhantomData<&'a T>,
}

impl<'a> EpwReader<'a, BufReader<&'a [u8]>> {
    #[must_use]
    pub fn from_slice(s: &'a [u8]) -> Self {
        Self {
            r: BufReader::new(s),
            max_lines: None,
            phantom: PhantomData,
        }
    }
}

impl<T: BufRead> EpwReader<'_, T> {
    pub fn new(r: T) -> Self {
        Self {
            r,
            max_lines: None,
            phantom: PhantomData,
        }
    }

    #[must_use]
    pub fn set_max_lines(mut self, max_lines: usize) -> Self {
        self.max_lines = Some(max_lines);
        self
    }

    pub fn parse(self) -> Result<Epw, Error> {
        let lines = self
            .r
            .lines()
            .enumerate()
            .map(|(idx, line)| (idx + 1, line));

        let mut ts = Vec::<NaiveDateTime>::with_capacity(BASE_CAPACITY);
        let mut wind_speed = Vec::<f32>::with_capacity(BASE_CAPACITY);
        let mut wind_dir = Vec::<f32>::with_capacity(BASE_CAPACITY);

        for (actual_lines, (line_no, line)) in lines.skip(8).enumerate() {
            if let Some(max_lines) = self.max_lines {
                if actual_lines + 1 > max_lines {
                    return Err(Error::MaxLinesReached { max_lines });
                }
            }

            let line = line?;
            let cols = line.split(',').collect_vec();

            ts.push(compose_ts(&cols, line_no)?);
            wind_dir.push(parse_col(&cols, "Wind direction", 20, line_no)?);
            wind_speed.push(parse_col(&cols, "Wind speed", 21, line_no)?);
        }

        Ok(Epw {
            ts,
            wind_speed,
            wind_dir,
        })
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

fn parse_col<T>(
    cols: &[&str],
    name: &'static str,
    idx: usize,
    line_no: usize,
) -> Result<T, Error>
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

    #[error("Max amount of lines ({max_lines}) reached")]
    MaxLinesReached { max_lines: usize },
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_matches;
    use std::io::BufReader;

    const EXAMPLE_1: &str = include_str!("fixtures/example1.epw");
    const MISSING_COLS: &str = include_str!("fixtures/missing_columns.epw");
    const CANNOT_PARSE_COL: &str = include_str!("fixtures/bad_wind_dir_col.epw");
    const INVALID_TIMESTAMP: &str =
        include_str!("fixtures/invalid_timestamp.epw");

    #[test]
    fn fixture_1() {
        let epw = EpwReader::from_slice(EXAMPLE_1.as_bytes()).parse().unwrap();

        insta::assert_json_snapshot!(&epw);
    }

    #[test]
    fn over_max_lines() {
        let res = EpwReader::from_slice(EXAMPLE_1.as_bytes())
            .set_max_lines(5)
            .parse();

        assert_matches!(res, Err(Error::MaxLinesReached { max_lines: 5 }));
    }

    #[test]
    fn missing_cols() {
        let res = EpwReader::from_slice(MISSING_COLS.as_bytes()).parse();

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
        let res = EpwReader::from_slice(CANNOT_PARSE_COL.as_bytes()).parse();

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
        let res =
            EpwReader::new(BufReader::new(INVALID_TIMESTAMP.as_bytes())).parse();

        assert_matches!(res, Err(Error::InvalidTimestamp { line_no: 12 }));
    }
}
