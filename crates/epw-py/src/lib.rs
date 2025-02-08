use epw::EpwReader;
use pyo3::{exceptions::PyException, prelude::*};
use pyo3_polars::PyDataFrame;

#[pyclass(extends=PyException)]
struct EpwError(epw::Error);

impl From<epw::Error> for EpwError {
    fn from(other: epw::Error) -> Self {
        Self(other)
    }
}

impl From<EpwError> for PyErr {
    fn from(other: EpwError) -> Self {
        PyErr::new::<EpwError, _>(format!("{}", other.0))
    }
}

#[pyfunction]
#[pyo3(signature = (bytes, /, max_lines=None))]
fn parse_into_dataframe(
    bytes: &[u8],
    max_lines: Option<usize>,
) -> Result<PyDataFrame, EpwError> {
    let mut reader = EpwReader::from_slice(bytes);

    if let Some(max_lines) = max_lines {
        reader = reader.set_max_lines(max_lines);
    }

    let df = reader.parse()?.into_dataframe()?;

    Ok(PyDataFrame(df))
}

#[pymodule(name = "epw")]
fn build_module(py: Python<'_>, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(parse_into_dataframe, m)?)?;
    m.add("EpwError", py.get_type::<EpwError>())?;

    Ok(())
}
