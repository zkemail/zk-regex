#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../.."

HAYSTACK=$(echo -e "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=;\x00")

echo "Generating input using haystack: $HAYSTACK"

cargo run \
    --bin zk-regex generate-circuit-input \
    --graph-path ./noir/timestamp/templates/timestamp_graph.json \
    --input "$HAYSTACK" \
    --max-haystack-len 300 \
    --max-match-len 300 \
    --output ./noir/timestamp/Prover.toml \
    --noir true

# echo "Simulating witness for timestamp regex match"
# cd ./noir/timestamp
# nargo execute

