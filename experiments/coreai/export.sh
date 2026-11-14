#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
if [[ $# -lt 2 ]]; then
  echo "Usage: bash export.sh RUN_NAME MODEL_DIRECTORY [coreai.llm.export options...]" >&2
  exit 2
fi
name="$1"
model="$(cd "$2" && pwd)"
shift 2
case "$name" in
  ""|"."|".."|*/*) echo "RUN_NAME must be a single directory name." >&2; exit 2 ;;
esac
mkdir -p "$root/runs"
output="$root/runs/$name"
mkdir "$output"

export USE_OS_COREAI=1 PYTHONUNBUFFERED=1
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
command=("$root/coreai-models/.venv/bin/python" -m coreai_models.llm.export
  "$model" --experimental --output-dir "$output" --output-name model "$@")
printf 'cd %q\n' "$PWD" > "$output/command.sh"
printf '%q ' "${command[@]}" >> "$output/command.sh"
printf '\n' >> "$output/command.sh"
git -C "$root/coreai-models" rev-parse HEAD > "$output/upstream-revision.txt"
"${command[@]}" 2>&1 | tee "$output/export.log"
