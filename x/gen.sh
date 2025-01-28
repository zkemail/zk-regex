#!/bin/bash
zk-regex decomposed -d x.json \
    --noir-file-path ./src/regex.nr \
    -t RegexDemo \
    -g true

zk-regex-old decomposed -d x.json \
    --noir-file-path ./src/regex_old.nr \
    -t RegexDemo \
    -g true