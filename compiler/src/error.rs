#[derive(Debug)]
pub enum Error {
    BuildError(String),
    CircomCodegenError(String),
    SerializeError(String),
    DeserializeError(String),
}
