use chrono::{Datelike, NaiveDateTime, Timelike};
use epw::{EpwReader, Error as EpwError};
use rustler::{
    nif, types::tuple::make_tuple, Binary, Encoder, Env, Error, NifMap,
    NifResult, Term,
};

mod atoms {
    rustler::atoms! {
        ok,
        ts,
        wind_speed,
        wind_dir,
        input_output,
        missing_col,
        invalid_timestamp,
        max_lines_reached,
        cannot_parse_col,
        polars
    }
}

type ErlTime = ((i32, u32, u32), (u32, u32, u32));

#[derive(NifMap)]
struct Args {
    max_lines: usize,
    first_n: usize,
    last_n: usize,
}

#[nif(schedule = "DirtyCpu")]
pub fn parse_into_preview<'a>(
    env: Env<'a>,
    buf: Binary<'a>,
    Args {
        max_lines,
        first_n,
        last_n,
    }: Args,
) -> NifResult<Term<'a>> {
    let reader = EpwReader::from_slice(buf.as_slice()).set_max_lines(max_lines);
    let content = reader.parse().map_err(map_reader_error)?;

    let m = Term::map_new(env)
        .map_put(
            atoms::ts(),
            chrono_to_erl_naive_dt(&first_n_and_last_n(
                content.ts, first_n, last_n,
            )),
        )?
        .map_put(
            atoms::wind_dir(),
            first_n_and_last_n(content.wind_dir, first_n, last_n),
        )?
        .map_put(
            atoms::wind_speed(),
            first_n_and_last_n(content.wind_speed, first_n, last_n),
        )?;

    Ok(make_tuple(env, &[atoms::ok().to_term(env), m]))
}

fn chrono_to_erl_naive_dt(s: &[NaiveDateTime]) -> Vec<ErlTime> {
    s.iter()
        .map(|ts| {
            let date = ts.date();
            let time = ts.time();

            (
                (date.year(), date.month(), date.day()),
                (time.hour(), time.minute(), time.second()),
            )
        })
        .collect()
}

fn first_n_and_last_n<T: std::fmt::Debug>(
    v: Vec<T>,
    first_n: usize,
    last_n: usize,
) -> Vec<T> {
    let mut head = v;
    let mut ts_end = head.split_off(first_n.min(head.len()));
    let tail = ts_end.split_off(ts_end.len().saturating_sub(last_n));
    head.extend(tail);
    head
}

fn map_reader_error(err: EpwError) -> Error {
    match err {
        EpwError::Io(err) => {
            Error::Term(Box::new((atoms::input_output(), format!("{err}")))
                as Box<dyn Encoder>)
        }
        EpwError::MissingColumn { .. } => {
            Error::Term(Box::new((atoms::missing_col(), format!("{err}")))
                as Box<dyn Encoder>)
        }
        EpwError::CannotParseColumn { .. } => {
            Error::Term(Box::new((atoms::cannot_parse_col(), format!("{err}")))
                as Box<dyn Encoder>)
        }
        EpwError::InvalidTimestamp { .. } => {
            Error::Term(Box::new((atoms::invalid_timestamp(), format!("{err}")))
                as Box<dyn Encoder>)
        }
        EpwError::MaxLinesReached { .. } => {
            Error::Term(Box::new((atoms::max_lines_reached(), format!("{err}")))
                as Box<dyn Encoder>)
        }
    }
}

rustler::init!("Elixir.Epw.Native");

#[cfg(test)]
mod test {
    use super::first_n_and_last_n;

    #[test]
    fn first_n_and_last_n_() {
        assert_eq!(vec![1, 5], first_n_and_last_n(vec![1, 2, 3, 4, 5], 1, 1));
        assert_eq!(
            vec![1, 2, 4, 5],
            first_n_and_last_n(vec![1, 2, 3, 4, 5], 2, 2)
        );
        assert_eq!(
            vec![1, 2, 3, 4, 5],
            first_n_and_last_n(vec![1, 2, 3, 4, 5], 5, 5)
        );
        assert_eq!(
            vec![1, 2, 3, 4, 5],
            first_n_and_last_n(vec![1, 2, 3, 4, 5], 6, 6)
        );
        assert_eq!(
            Vec::<i32>::new(),
            first_n_and_last_n(vec![1, 2, 3, 4, 5], 0, 0)
        );
    }
}
