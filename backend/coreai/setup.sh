#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

revision=acbce1b41f95955ab56597d11d94b447b16a80bd
if [[ ! -d coreai-models ]]; then
  git clone https://github.com/apple/coreai-models.git coreai-models
  git -C coreai-models checkout --detach "$revision"
fi
if [[ "$(git -C coreai-models rev-parse HEAD)" != "$revision" ]]; then
  echo "Expected coreai-models revision $revision; switch the checkout explicitly." >&2
  exit 1
fi
(cd coreai-models && uv sync --locked --no-dev --python 3.12.15 --package coreai-models)
mkdir -p views runs
