# zk-regex

A library to do regex verification in circom, adapted from the original zk-email. Hopefully will add halo2 soon as well.

## introduction
The compilation command generates a circom file at build/compiled.circom. This code is a JS adaptation of the Python regex-to-circom work done at https://github.com/zk-email-verify/zk-email-verify/tree/main/regex_to_circom.

In addition to the original work, this library also supports the following features:
 - CLI to dynamically generate regex circuit based on regex argument
 - Extended regex circuit template to support:
    - differentiate the match counts between the entire regex and the matched groups of alternate character sets
    - allow specifying which alternate group for data points
    - allow specifying which group match to reveal 

### theory
To understand the theory behind the regex circuit compiler, please checkout [this blog post](https://katat.me/blog/ZK+Regex).

## how to use
### install
Clone the repo and install the dependencies:
```
yarn install
```

### CLI

There is a CLI to generate the regex circuit based on the regex argument. The CLI will generate the circuit file in the folder `./build`. For example, the following command
```
yarn compile "abc (a|b|c)+" circuit_name
```
will generate the circuit file at `build/circuit_name.circom`

### circuit usage
The generated circuit has 
- 3 template arguments: 
    - msg_bytes: the number of characters for the input message to match against
    - reveal_bytes: the number of characters to reveal from the matched group
    - group_idx: the index of the group to reveal
- 2 input signals:
    - msg[msg_bytes]: the input message to match against
    - match_idx: the index of the group to reveal
- 4 output signals:
    - entire_count: the number of matches in the entire regex
    - group_match_count: the number of matches for the alternate group
    - start_idx: the start position index of the matched for the alternate group
    - reveal_shifted: revealed values from the matched group

Take the regex `1=(a|b) (2=(b|c)+ )+d` for example. The match against the input message `1=a 2=c 2=bc 2=cb d` will have the following template argument values: 
 - msg_bytes: 20 (the length of the input message, and it can be greater than the actual length of the message)
 - reveal_bytes: 2 (the expected maximum length of the revealed string)
 - group_idx: 1 (targets 2nd alternate group, as it is zero-indexed)

and input signals:
 - msg: `1=a 2=c 2=bc 2=cb d`
 - match_idx: 1 (targets 2nd matched for the alternate group, as it is zero-indexed)

then it should generate output signals:
 - entire_count: 1 
 - group_match_count: 3
 - start_idx: 10 
 - reveal_shifted: `bc` 

For more examples in action, please checkout the test cases in the `test` folder.

## development
Welcome any questions, suggestions or PRs!

### testing
For ease of testing and debugging, for now this repo uses a custom version of `circom_tester`, a pending PR to the original repo is here: https://github.com/iden3/circom_tester/pull/15

Run this the following command to run the tests:
```bash
yarn test
```


## future work
### better align with regex grammar
 - [ ] support character class regex grammar (so as to simplify the regular expressions)
 - [ ] better compatibility with regex grammar (will need a set of different tests to assert the compatibility between circuit and regex in languages)
