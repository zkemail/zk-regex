mod regex;

global MAX_INPUT_SIZE: u32 = 1024;

fn main(input: [u8; MAX_INPUT_SIZE]) {
    let x = regex::regex_match(input);
}

// #[test]
fn test_out() {
    let input: [u8; 8] = "abcdabcd".as_bytes();
    let mut full_input = [0; MAX_INPUT_SIZE];
    for i in 8..16 {
        full_input[i] = input[i - 8];
    }
    println(full_input);
    let x = regex::regex_match(input);
    println(x);
}

#[test]
fn test_pass_1() {
    // let input: [u8; 8] = "x12-yy_z".as_bytes();
    let input = "x12-yy_     x12-yy_z      ".as_bytes();

    let out = regex::regex_match(input);
    println(f"out: {out}");
    // for i in 0..2 {
    //     if i < out.len() {
    //         println(out.get(i));
    //     }
    // }
    // println(out);
}

// #[test]
fn test_2() {
    let input2 = "\r\nsubject:this is a test.\r\n            ".as_bytes();
    let input = "subject:これはテストです。\r\n".as_bytes();
    let mut x = [0; 38];
    for i in 0..37 {
        x[i + 1] = input[i];
    }
    // x[0] = 0xFF;
    println(x);
    // let (out, _, _) = regex::__regex_match(input);
    let out = regex::regex_match(input2);
    for i in 0..10 {
        if i < out.len() {
            println(out.get(i));
        }
    }
}

// #[test]
fn test_3() {
    let input = "1=a 2=b 2=bc 2=c d".as_bytes();
    let out = regex::regex_match(input);
    for i in 0..3 {
        if i < out.len() {
            println(out.get(i));
        }
    }
    
}

#[test]
fn test_4() {
    let input = "aa".as_bytes();
    let out = regex::regex_match(input);
    println(out.get(0));
}

#[test]
fn test_5() {
    let input = "Latin-Extension=Ʃƣƙ Greek=ϕω Cyrillic=иЩ Arabic=أبت Devanagari=आदित्य Hiragana&Katakana=なツ".as_bytes();
    let out = regex::regex_match(input);
    for i in 0..3 {
        if i < out.len() {
            println(out.get(i));
        } else {
            println(f"No element at {i}");
        }
    }
}

// #[test]
// fn test_pass_3() {
//     let input: [u8; 8] = "x00-yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_4() {
//     let input: [u8; 9] = "x45-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_5() {
//     let input: [u8; 8] = "x01-yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_6() {
//     let input: [u8; 9] = "x78-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_7() {
//     let input: [u8; 8] = "x34-yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_8() {
//     let input: [u8; 9] = "x89-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_9() {
//     let input: [u8; 8] = "x23-yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test]
// fn test_pass_10() {
//     let input: [u8; 9] = "x67-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_1() {
//     let input: [u8; 10] = "x123-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_2() {
//     let input: [u8; 7] = "x12-y_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_3() {
//     let input: [u8; 7] = "x12-yyy".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_4() {
//     let input: [u8; 8] = "x1-yyy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_5() {
//     let input: [u8; 9] = "x12-yy_zz".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_6() {
//     let input: [u8; 9] = "x12-yyy_x".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_7() {
//     let input: [u8; 7] = "x12yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_8() {
//     let input: [u8; 7] = "12-yy_z".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_9() {
//     let input: [u8; 9] = "x12-y_zzz".as_bytes();
//     regex::regex_match(input);
// }

// #[test(should_fail)]
// fn test_fail_10() {
//     let input: [u8; 9] = "x12--yy_z".as_bytes();
//     regex::regex_match(input);
// }
