use sort::sort_advanced;

unconstrained fn __sort_field_as_u32(lhs: Field, rhs: Field) -> bool {
    //  lhs.lt(rhs)
    lhs as u32 <= rhs as u32
}
pub struct SparseArray<let N: u32, T> {
    pub keys: [Field; N + 2],
    pub values: [T; N + 3],
    pub  maximum: Field, // can be up to 2^32
}

fn assert_sorted(lhs: Field, rhs: Field) {
    let result = (rhs - lhs - 1);
    result.assert_max_bit_size::<32>();
}

/// Note: excisting SparseArray impl has a small bug, local impl until fixed
pub impl<let N: u32, T> SparseArray<N, T>
where
    T: std::default::Default,
{

    /**
     * @brief construct a SparseArray
     **/
    pub fn create(_keys: [Field; N], _values: [T; N], size: Field) -> Self {
        let _maximum = size - 1;
        let mut r: Self =
            SparseArray { keys: [0; N + 2], values: [T::default(); N + 3], maximum: _maximum };

        // for any valid index, we want to ensure the following is satified:
        // self.keys[X] <= index <= self.keys[X+1]
        // this requires us to sort hte keys, and insert a startpoint and endpoint
        let sorted_keys = sort_advanced(_keys, __sort_field_as_u32, assert_sorted);

        // insert start and endpoints
        r.keys[0] = 0;
        for i in 0..N {
            r.keys[i + 1] = sorted_keys.sorted[i];
        }
        r.keys[N + 1] = _maximum;

        // populate values based on the sorted keys
        // note: self.keys[i] maps to self.values[i+1]
        // self.values[0] does not map to any key. we use it to store the default empty value,
        // which is returned when `get(idx)` is called and `idx` does not exist in `self.keys`
        for i in 0..N {
            // if (sorted_keys.sorted[i] == 0x0d)
            // {
            //     let x = sorted_keys.sort_indices[i];
            //     let y = _values[sorted_keys.sort_indices[i]];
            //     println(f"i = {i}, sort indices = {x}, value? = {y}");
            //     assert(x == -1);
            // }
            // THIS IS THE BUG: the commented line was the original line
            r.values[sorted_keys.sort_indices[i] + 2] = _values[i];
        //    r.values[i + 2] = _values[sorted_keys.sort_indices[i]];
        }
        // insert values that map to our key start and endpoints
        // if _keys[0] = 0 then values[0] must equal _values[0], so some conditional logic is required
        // (same for _keys[N-1])
        let mut initial_value = T::default();
        if (_keys[0] == 0) {
            initial_value = _values[0];
        }
        let mut final_value = T::default();
        if (_keys[N - 1] == _maximum) {
            final_value = _values[N - 1];
        }
        r.values[1] = initial_value;
        r.values[N + 2] = final_value;

        // perform boundary checks!
        // the maximum size of the sparse array is 2^32
        // we need to check that every element in `self.keys` is less than 2^32
        // because `self.keys` is sorted, we can simply validate that
        // sorted_keys.sorted[0] < 2^32
        // sorted_keys.sorted[N-1] < maximum
        sorted_keys.sorted[0].assert_max_bit_size::<32>();
        _maximum.assert_max_bit_size::<32>();
        (_maximum - sorted_keys.sorted[N - 1]).assert_max_bit_size::<32>();
        r
    }

    /**
     * @brief determine whether `target` is present in `self.keys`
     * @details if `found == false`, `self.keys[found_index] < target < self.keys[found_index + 1]`
     **/
    unconstrained fn search_for_key(self, target: Field) -> (Field, Field) {
        let mut found = false;
        let mut found_index = 0;
        let mut previous_less_than_or_equal_to_target = false;
        for i in 0..N + 2 {
            // if target = 0xffffffff we need to be able to add 1 here, so use u64
            let current_less_than_or_equal_to_target = self.keys[i] as u64 <= target as u64;
            if (self.keys[i] == target) {
                found = true;
                found_index = i as Field;
                break;
            }
            if (previous_less_than_or_equal_to_target & !current_less_than_or_equal_to_target) {
                found_index = i as Field - 1;
                break;
            }
            previous_less_than_or_equal_to_target = current_less_than_or_equal_to_target;
        }
        (found as Field, found_index)
    }

    /**
     * @brief return element `idx` from the sparse array
     * @details cost is 14.5 gates per lookup
     **/
    pub fn get(self, idx: Field) -> T {
        let (found, found_index) = unsafe { self.search_for_key(idx) };
        // bool check. 0.25 gates cheaper than a raw `bool` type. need to fix at some point
        assert(found * found == found);

        // OK! So we have the following cases to check
        // 1. if `found` then `self.keys[found_index] == idx`
        // 2. if `!found` then `self.keys[found_index] < idx < self.keys[found_index + 1]
        // how do we simplify these checks?
        // case 1 can be converted to `self.keys[found_index] <= idx <= self.keys[found_index]
        // case 2 can be modified to  `self.keys[found_index] + 1 <= idx <= self.keys[found_index + 1] - 1
        // combine the two into the following single statement:
        // `self.keys[found_index] + 1 - found <= idx <= self.keys[found_index + 1 - found] - 1 + found
        let lhs = self.keys[found_index];
        let rhs = self.keys[found_index + 1 - found];
        let lhs_condition = idx - lhs - 1 + found;
        let rhs_condition = rhs - 1 + found - idx;
        lhs_condition.assert_max_bit_size::<32>();
        rhs_condition.assert_max_bit_size::<32>();

        // self.keys[i] maps to self.values[i+1]
        // however...if we did not find a non-sparse entry, we want to return self.values[0] (the default value)
        let value_index = (found_index + 1) * found;
        self.values[value_index]
    }
}