#!/bin/bash

echo "============[Sparse Array Regex]============"
cd sparse
nargo compile --force --silence-warnings
nargo info
bb gates -b target/sparse_regex.json | grep "circuit"
cd ..

# echo "============[Simple Array Regex]============"
# cd simple
# nargo compile --force --silence-warnings
# nargo info
# bb gates -b target/simple_regex.json | grep "circuit"
# cd ..