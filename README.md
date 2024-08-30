# zk-regex

A library to do regex verification in circom. It will also generate lookup tables compatible with [halo2-regex](https://github.com/zkemail/halo2-regex) soon.

<!-- We've forked [min-dfa into a UI here](https://mindfa.onrender.com/min_dfa) to create a UI that converts existing regexes with [] support, as well as escapes \_, and the character classes a-z, A-Z, and 0-9. It also shows the DFA states very clearly so you can choose accept states easily. This should make converting regexes into DFA form way cleaner. -->

## Introduction

This library provides circom circuits that enables you to prove that
- the input string satisfies regular expressions (regexes) specified in the chip.
- the substrings are correctly extracted from the input string according to substring definitions.

This is a Rust adaptation of the Python regex-to-circom work done by [sampriti](https://github.com/sampritipanda/) and [yush_g](https://twitter.com/yush_g), along with [sorasue](https://github.com/SoraSuegami/)'s decomposed specifications and [Sora + Bisht13](https://github.com/Bisht13)'s rewrite in Rust to support more characters. You can generate your own regexes via our no-code tool for the old Typescript version 1.X at [zkregex.com](https://www.zkregex.com). Note that zkregex.com does not support all syntax unlike version 2.1.1.

In addition to the original work, this library also supports the following features:
- CLI to dynamically generate regex circuit based on regex arguments
- Extended regex circuit template supporting most regex syntax (see Theory to understand excluded syntax)
  - a decomposed regex definition, which is the easiest way to define your regex's public and private parts

You can define a regex to be proved and its substring patterns to be revealed.
Specifically, there are two ways to define them:
1. (manual way) converting the regex into an equivalent determistic finite automaton (DFA), selecting state transitions for each substring pattern, and writing the transitions in a json file.
2. (automatic way) writing a decomposed version of the regex in a json file with specifying which part of the regex is revealed.
3. (no code way) put the regex into zkregex.com > tool, highlight your chosen part, and copy the generated circuit
While the manual way supports more kinds of regexes than the automatic way, the latter is easier and sufficient for most regexes.

### Theory

To understand the theory behind the regex circuit compiler, please checkout [our main explanation post](https://prove.email/blog/zkregex), or [this older blog post](https://katat.me/blog/ZK+Regex). To understand how it ties into the original zk email work, you can also read the brief [original zk-email blog post regex overview](https://blog.aayushg.com/posts/zkemail#regex-deterministic-finite-automata-in-zk).

The regular expressions supported by our compiler version 2.1.1 are **audited by zksecurity**, and have the following limitations:

1. Regular expressions where the results differ between greedy and lazy matching (e.g., .+, .+?) are not supported.
2. The beginning anchor ^ must either appear at the beginning of the regular expression or be in the format (|^). Additionally, the section containing this ^ must be non-public (is_public: false).
3. The end anchor $ must appear at the end of the regular expression.
4. Regular expressions that, when converted to DFA (Deterministic Finite Automaton), include transitions to the initial state are not supported (e.g., .*).
5. Regular expressions that, when converted to DFA, have multiple accepting states are not supported.
6. Decomposed regex defintions must alternate public and private states.

Note that all international characters are supported. 

If you want to use this circuit in practice, we strongly recommend using [AssertZero](https://github.com/zkemail/zk-email-verify/blob/29d5c873161c30ebb98a00efb3a145275d0f0833/packages/circuits/utils/array.circom#L144) on the bytes before and after your match. This is because you likely have shift viaan unconstrained index passed in as the witnesss to represent the start of the regex match. Since that value can be arbitrarily manipulated, you need to manually constrain that there are no extra matches that can be used to exploit the circuit. You can see how we do this in [zk-email here](https://github.com/zkemail/zk-email-verify/blob/29d5c873161c30ebb98a00efb3a145275d0f0833/packages/circuits/email-verifier.circom#L99).

## How to use

### Install

Install yarn v1, or run `yarn set version classic` to set the version.
Also make sure that [`circom`](https://docs.circom.io/getting-started/installation/) is installed.

Clone the repo and install the dependencies:

```
yarn install
```

### Compiler CLI

`zk-regex` is a CLI to compile a user-defined regex to the corresponding regex circuit.
It provides two commands: `raw` and `decomposed`

#### `zk-regex decomposed -d <DECOMPOSED_REGEX_PATH> -c <CIRCOM_FILE_PATH> -t <TEMPLATE_NAME> -g <GEN_SUBSTRS (true/false)>`
This command generates a regex circom from a decomposed regex definition.
For example, if you want to verify the regex of `email was meant for @(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)+.` and reveal alphabets after @, you can define the decomposed regex as follows.
```
{
     "parts":[
         {
             "is_public": false,
             "regex_def": "email was meant for @"
         },
         {
             "is_public": true,
             "regex_def": "[a-z]+"
         },
         {
             "is_public": false,
             "regex_def": "."
         }
     ]
}
```
Note that the `is_public` field in the second part is true since it is a substring to be revealed.
You can generate its regex circom as follows.
1. Make the above json file at `./simple_regex_decomposed.json`.
2. Run `zk-regex decomposed -d ./simple_regex_decomposed.json -c ./simple_regex.circom -t SimpleRegex -g true`. It outputs a circom file at `./simple_regex.circom` that has a `SimpleRegex` template.

#### `zk-regex raw -r <RAW_REGEX> -s <SUBSTRS_JSON_PATH> -c <CIRCOM_FILE_PATH> -t <TEMPLATE_NAME> -g <GEN_SUBSTRS (true/false)>`
This command generates a regex circom from a raw string of the regex definition and a json file that defines state transitions in DFA to be revealed.
For example, to verify the regex `1=(a|b) (2=(b|c)+ )+d` and reveal its alphabets,
1. Visualize DFA of the regex using [this website](https://zkregex.com).
2. Find state transitions matching with the substrings to be revealed. In this case, they are `2->3` for the alphabets after `1=`, `6->7` and `7->7` for those after `2=`, and `8->9` for `d`. 
3. Make a json file at `./simple_regex_substrs.json` that defines the state transitions. For example,
    ```
    {
        "transitions": [
            [
                [
                    2,
                    3
                ]
            ],
            [
                [
                    6,
                    7
                ],
                [
                    7,
                    7
                ]
            ],
            [
                [
                    8,
                    9
                ]
            ]
        ]
    }
    ```
4. Run `zk-regex raw -r "1=(a|b) (2=(b|c)+ )+d" -s ./simple_regex_substrs.json -c ./simple_regex.circom -t SimpleRegex -g true`. It outputs a circom file at `./simple_regex.circom` that has a `SimpleRegex` template.

<!-- 
The CLI will generate the circuit file in the folder `./build`. For example, the following command

```
yarn compile "abc (a|b|c)+" circuit_name
```

will generate the circuit file at `build/circuit_name.circom` -->

### Circuit Usage
The generated circuit has
- 1 template arguments:
  - `msg_bytes`: the number of characters for the input string.
- 1 input signals:
  - `msg[msg_bytes]`: the input message to match against
- 1 + (the number of substring patterns) output signals:
  - `out`: a bit flag to identify whether the substring of the input string matches with the defined regex.
  - `reveal(i)[msg_bytes]`: The masked version of `msg[msg_bytes]`. Each character in `msg[msg_bytes]` is turned to zero in `reveal(i)[msg_bytes]` if it does not belong to the i-th substring pattern.

For more examples in action, please checkout the test cases in the `./packages/circom/circuits/common` folder.

### Helper APIs
A package in `./packages/apis` provides nodejs/rust apis helpful to generate inputs of the regex circuits.

## Development
Welcome any questions, suggestions or PRs!

### Testing

```bash
yarn test
```

## Cite this Work

Use this bibtex citation.
```
@misc{zk-regex,
  author = {Gupta, Aayush and Panda, Sampriti and Suegami, Sora},
  title = {zk-regex},
  year = {2022},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/zkemail/zk-regex/}},
}
```

<!-- ### better align with regex grammar

- [ ] support character class regex grammar (so as to simplify the regular expressions)
- [ ] better compatibility with regex grammar (will need a set of different tests to assert the compatibility between circuit and regex in languages) -->
