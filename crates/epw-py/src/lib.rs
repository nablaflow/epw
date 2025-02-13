use epw::{Epw, EpwReader, Error as EpwError};
use pyo3::{exceptions::PyValueError, prelude::*, types::PyDict, IntoPyObject};

struct PyEpw(Epw);

impl<'py> IntoPyObject<'py> for PyEpw {
    type Target = PyDict; // the Python type
    type Output = Bound<'py, Self::Target>; // in most cases this will be `Bound`
    type Error = PyErr;

    fn into_pyobject(self, py: Python<'py>) -> Result<Self::Output, Self::Error> {
        let dict = PyDict::new(py);

        dict.set_item("ts", self.0.ts)?;
        dict.set_item("wind_dir", self.0.wind_dir)?;
        dict.set_item("wind_speed", self.0.wind_speed)?;

        Ok(dict)
    }
}

#[pyfunction]
#[pyo3(signature = (bytes, /, max_lines=None))]
fn parse(bytes: &[u8], max_lines: Option<usize>) -> PyResult<PyEpw> {
    let mut reader = EpwReader::from_slice(bytes);

    if let Some(max_lines) = max_lines {
        reader = reader.set_max_lines(max_lines);
    }

    let epw = reader.parse().map_err(|err| to_value_error(&err))?;

    Ok(PyEpw(epw))
}

fn to_value_error(err: &EpwError) -> PyErr {
    PyValueError::new_err(format!("{err}"))
}

#[pymodule(name = "_epw")]
fn build_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(parse, m)?)?;

    Ok(())
}
