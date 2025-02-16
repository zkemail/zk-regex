use super::{utils::indent, BYTE_SIZE, TableRows};
use comptime::{FieldElement, SparseArray};

/**
 * Make lookup table for the DFA
 *
 * @param rows - the dfa transitions to add as rows to the table
 * @param size - the total size of the table
 * @param sparse_array - whether to use a sparse array or not
 * @returns the codegen for the DFA lookup table in Noir
 */
pub fn make_lookup_table(
    rows: &TableRows,
    size: usize,
    sparse_array: bool,
) -> String {
    match sparse_array {
        true => make_sparse_table(rows, size),
        false => make_simple_table(rows, size),
    }
}

/**
 * Make a simple lookup table for the DFA
 * @dev simple means just a normal ROM table vs sparse array
 *
 * @param rows - the dfa transitions to add as rows to the table
 * @param size - the total size of the table
 * @returns the codegen for the DFA lookup table in Noir
 */
fn make_simple_table(rows: &TableRows, size: usize) -> String {
    let mut body = String::new();
    for (curr_state_id, char_code, next_state_id) in rows {
        body +=
            &format!("table[{curr_state_id} * {BYTE_SIZE} + {char_code}] = {next_state_id};\n",);
    }
    body = indent(&body, 1);
    format!(
        r#"
global table: [Field; {size}] = comptime {{ make_lookup_table() }};

comptime fn make_lookup_table() -> [Field; {size}] {{
    let mut table = [0; {size}];
    {body}
    table
}}"#
    )
}

/**
 * Make a lookup table for the DFA using a sparse array
 *
 * @param rows - the dfa transitions to add as rows to the table
 * @param size - the total size of the table
 * @returns the codegen for the DFA lookup table in Noir
 */
fn make_sparse_table(rows: &TableRows, size: usize) -> String {
    let mut keys: Vec<FieldElement> = Vec::new();
    let mut values: Vec<FieldElement> = Vec::new();
    for (curr_state_id, char_code, next_state_id) in rows {
        keys.push(FieldElement::from(
            curr_state_id * BYTE_SIZE as usize + *char_code as usize,
        ));
        values.push(FieldElement::from(*next_state_id));
    }

    let sparse_array =
        SparseArray::create(&keys, &values, FieldElement::from(size)).to_noir_string(None);
    format!(r#"
global table: {sparse_array}
    "#)
}

/// Access table by array index or sparse API index
pub fn access_table(s: &str, sparse: bool) -> String {
    match sparse {
        true => format!("table.get({})", s),
        false => format!("table[{}]", s),
    }
}
