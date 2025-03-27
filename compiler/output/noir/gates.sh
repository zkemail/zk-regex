#!/bin/bash
nargo compile --force --silence-warnings
bb gates -b ./target/regex_v2.json | grep "size" 