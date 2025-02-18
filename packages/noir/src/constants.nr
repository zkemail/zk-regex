/// EMAIL ADDR REGEX ///
// https://www.rfc-editor.org/errata/eid1690#:~:text=Section%203%20says%3A,total%20length%20of%20320%20characters.
pub global ADDR_REGEX_MAX_CAPTURE_LEN: u32 = 320;
global CRLF_POSTFIX: u32 = 2;

/// TO_ALL REGEX ///
// (\r\n|^)to: 
global TO_ALL_MAX_PREFIX: u32 = 5;
// \r\n
pub global TO_ALL_MAX_LEN: u32 = TO_ALL_MAX_PREFIX + ADDR_REGEX_MAX_CAPTURE_LEN + CRLF_POSTFIX;

// FROM ALL REGEX///
// (\r\n|^)from: 
global FROM_ALL_MAX_PREFIX: u32 = 7;
pub global FROM_ALL_MAX_LEN: u32 = FROM_ALL_MAX_PREFIX + ADDR_REGEX_MAX_CAPTURE_LEN + CRLF_POSTFIX;