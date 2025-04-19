pub mod sparse_array;
pub mod transitions;

// separators for accessing values from byte/curr_state/next_state key in sparse array
pub global R: u32 = 257;
pub global R_SQUARED: u32 = R * R;