#!/usr/bin/env bash

set -euo pipefail

log() { echo "[entrypoint] $*"; }

case "${ANANSI_LOADER:-default}" in
  default) BINARY=/usr/local/bin/llama-server ;;
  pipelined) BINARY=/usr/local/bin/llama-server-pipelined ;;
  *)
    log "ERROR: Unknown loader: '${ANANSI_LOADER}'; must be 'default' or 'pipelined'"
    exit 64
    ;;
esac

if [[ "${ANANSI_LOADER:-default}" == "pipelined" ]]; then
  log "NOTE: Using pipelined loader; M3 stub. Same as default loader."
fi

shopt -s nullglob
candidates=(/mnt/models/*.gguf)
shopt -u nullglob

if [[ -n "${MODEL_PATH:-}" ]]; then
  [[ -s "$MODEL_PATH" ]] || { log "ERROR: Model file not found: '${MODEL_PATH}'"; exit 66; }
  MODEL_FILE="$MODEL_PATH"
elif (( ${#candidates[@]} == 1 )); then
  [[ -s "${candidates[0]}" ]] || { log "ERROR: Model file not found: '${candidates[0]}' Storage initialiser probably failed"; exit 65; }
  MODEL_FILE="${candidates[0]}"
elif (( ${#candidates[@]} == 0 )); then
  log "ERROR: No model file found; must specify MODEL_PATH or place a single .gguf file in /mnt/models"
  exit 65
else
  log "ERROR: Multiple model files found; must specify MODEL_PATH or place a single .gguf file in /mnt/models"
  log "Candidates: %s\n" "${candidates[@]}"
  exit 65
fi

log "model: ${MODEL_FILE} ($(stat -c%s "$MODEL_FILE") bytes)"

read -ra LOADER_ARGS_ARR <<< "${ANANSI_LOADER_ARGS:-}"

ARGS=(
  --host 0.0.0.0
  --port "${LLAMA_PORT:-8080}"
  --model "$MODEL_FILE"
  --n-gpu-layers "all"
  --ctx-size 2048
  "${LOADER_ARGS_ARR[@]}"
)

log "exec: ${BINARY} ${ARGS[*]}"
exec "${BINARY}" "${ARGS[@]}"
