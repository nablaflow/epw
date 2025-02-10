use epw::{EpwReader, Error as EpwError};
use pyo3::{exceptions::PyValueError, prelude::*};
use pyo3_polars::PyDataFrame;

#[pyfunction]
#[pyo3(signature = (bytes, /, max_lines=None))]
fn parse_into_dataframe(
    bytes: &[u8],
    max_lines: Option<usize>,
) -> PyResult<PyDataFrame> {
    let mut reader = EpwReader::from_slice(bytes);

    if let Some(max_lines) = max_lines {
        reader = reader.set_max_lines(max_lines);
    }

    let df = reader
        .parse()
        .map_err(|err| to_value_error(&err))?
        .into_dataframe()
        .map_err(|err| to_value_error(&err))?;

    Ok(PyDataFrame(df))
}

fn to_value_error(err: &EpwError) -> PyErr {
    PyValueError::new_err(format!("{err}"))
}

#[pymodule(name = "epw")]
fn build_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(parse_into_dataframe, m)?)?;

    Ok(())
}
