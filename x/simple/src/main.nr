mod regex;
mod regex_common;

global MAX_INPUT_SIZE: u32 = 1024;

fn main(input: [u8; MAX_INPUT_SIZE]) {
    let matches = regex::regex_match(input);
    let substring =
        regex_common::extract_substring::<MAX_INPUT_SIZE, MAX_INPUT_SIZE>(matches.get(0), input);
    // let q = substrings.get_unchecked(0);
    for i in 0..MAX_INPUT_SIZE {
        let r = substring.get_unchecked(i);
        assert(r != 0);
    }
}

#[test]
fn test_out() {
    let input = "xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab"
        .as_bytes();
    let matches = regex::regex_match(input);
    let substring = regex_common::extract_substring::<846, 846>(matches.get(0), input);
    println(f"substring: {substring}");
}

// #[test]
// fn test_pass_1() {
//     // let input: [u8; 8] = "x12-yy_z".as_bytes();
//     let input = "x12-yy_     x12-yy_z      ".as_bytes();

//     let out = regex::regex_match(input);
//     println(f"out: {out}");
//     // for i in 0..2 {
//     //     if i < out.len() {
//     //         println(out.get(i));
//     //     }
//     // }
//     // println(out);
// }

// #[test]
fn test_2() {
    let input2 = "\r\nsubject:this is a test.\r\n            ".as_bytes();
    let input = "subject:これはテストです。\r\n".as_bytes();
    // let mut x = [0; 38];
    // for i in 0..37 {
    //     x[i + 1] = input[i];
    // }
    // // x[0] = 0xFF;
    // println(x);
    // // let (out, _, _) = regex::__regex_match(input);
    // let out = regex::regex_match(input2);
    // for i in 0..10 {
    //     if i < out.len() {
    //         println(out.get(i));
    //     }
    // }
}

// #[test]
// fn test_3() {
//     let input = "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=".as_bytes();
//     let out = regex::regex_match(input);
//     for i in 0..1 {
//         if i < out.len() {
//             println(out.get(i));
//         }
//     }

// }

// #[test]
// fn test_4() {
//     let input = "aa".as_bytes();
//     let out = regex::regex_match(input);
//     println(out.get(0));
// }

#[test]
fn test_5() {
    let input2 = "Latin-Extension=Ʃƣƙ Greek=ϕω Cyrillic=иЩ Arabic=أبت Devanagari=आदित्य Hiragana&Katakana=なツ"
        .as_bytes();
    let input = [76, 97, 116, 105, 110, 45, 69, 120, 116, 101, 110, 115, 105, 111, 110, 61, 195, 154, 197, 178, 196, 165, 196, 168, 198, 164, 195, 174, 196, 185, 197, 187, 32, 71, 114, 101, 101, 107, 61, 207, 186, 207, 167, 32, 67, 121, 114, 105, 108, 108, 105, 99, 61, 209, 138, 211, 171, 209, 132, 209, 178, 209, 151, 211, 160, 209, 167, 208, 175];
    let out = regex::regex_match(input);
    for i in 0..3 {
        if i < out.len() {
            let substring = regex_common::extract_substring::<_, 4000>(out.get(i), input);
            println(f"substring: {substring}");
        } else {
            println(f"No element at {i}");
        }
    }
}

#[test]
fn test_pass_3() {
    let input = "ab".as_bytes();
    let matches = regex::regex_match(input);
    let substring = regex_common::extract_substring::<_, 2>(matches.get(0), input);
    println(f"substring: {substring}");
}

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
