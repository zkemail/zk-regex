#!/bin/bash
nargo compile --force --silence-warnings
bb gates -b target/from_addr.json | grep "circuit"