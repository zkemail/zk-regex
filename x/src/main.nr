// mod regex_sparse;
mod regex;
mod regex_old;

global MAX_INPUT_SIZE: u32 = 1024;

fn main(input: [u8; MAX_INPUT_SIZE]) {
    let x = regex::regex_match(input);
    // let x = regex_old::regex_match(input);
    // regex_simple::regex_match(input);
    // regex_sparse::regex_match(input);
    // let x = regex_sparse::table.get(1);
    // let x = regex_simple::table[1];
    // assert(x == 0);
}

#[test]
fn test_pass_1() {
    let input: [u8; 8] = "x12-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_2() {
    let input: [u8; 9] = "x99-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_3() {
    let input: [u8; 8] = "x00-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_4() {
    let input: [u8; 9] = "x45-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_5() {
    let input: [u8; 8] = "x01-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_6() {
    let input: [u8; 9] = "x78-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_7() {
    let input: [u8; 8] = "x34-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_8() {
    let input: [u8; 9] = "x89-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_9() {
    let input: [u8; 8] = "x23-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test]
fn test_pass_10() {
    let input: [u8; 9] = "x67-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_1() {
    let input: [u8; 10] = "x123-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_2() {
    let input: [u8; 7] = "x12-y_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_3() {
    let input: [u8; 7] = "x12-yyy".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_4() {
    let input: [u8; 8] = "x1-yyy_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_5() {
    let input: [u8; 9] = "x12-yy_zz".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_6() {
    let input: [u8; 9] = "x12-yyy_x".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_7() {
    let input: [u8; 7] = "x12yy_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_8() {
    let input: [u8; 7] = "12-yy_z".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_9() {
    let input: [u8; 9] = "x12-y_zzz".as_bytes();
    regex::regex_match(input);
}

#[test(should_fail)]
fn test_fail_10() {
    let input: [u8; 9] = "x12--yy_z".as_bytes();
    regex::regex_match(input);
}