#!/usr/bin/env bash
# Smoke-test all wired models (sync + stream).
# Usage: bash example.md
set -euo pipefail

FUNCTION_URL=$(aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text)
INFERENCE_API_KEY="${INFERENCE_API_KEY:-1234}"

# Non-stream → JSON (pipe to jq). Stream → SSE (curl -N, do not pipe to jq).
# Imported Qwen2.5 may return "Model is not ready" on cold start — retry after a short wait.

chat() {
  local model="$1"
  local stream="${2:-false}"
  local extra="${3:-"{}"}"
  local body
  body="$(jq -nc \
    --arg model "${model}" \
    --argjson stream "${stream}" \
    --argjson extra "${extra}" \
    '{
      model: $model,
      messages: [{role: "user", content: "Say hello in one short sentence."}],
      max_tokens: 64,
      temperature: 0,
      stream: $stream
    } + $extra')"
  if [[ "${stream}" == "true" ]]; then
    curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
      -d "${body}"
  else
    curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
      -d "${body}" \
      | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
  fi
  echo
}

# ---------------------------------------------------------------------------
# Custom Model Import (InvokeModel)
# ---------------------------------------------------------------------------

echo "=== Qwen/Qwen2.5-7B-Instruct ==="
chat "Qwen/Qwen2.5-7B-Instruct" false '{"top_p":1.0}'

echo "=== Qwen/Qwen2.5-7B-Instruct (stream) ==="
chat "Qwen/Qwen2.5-7B-Instruct" true '{"top_p":1.0}'

# ---------------------------------------------------------------------------
# Marketplace (Converse) — sync then stream per model
# ---------------------------------------------------------------------------

for MODEL in \
  qwen3-next-80b-a3b \
  nova-pro \
  llama \
  gpt-oss \
  deepseek \
  ministral-3b ministral-8b ministral-14b \
  gemma-3-4b gemma-3-12b gemma-3-27b \
  qwen3-32b
do
  echo "=== ${MODEL} ==="
  chat "${MODEL}" false

  echo "=== ${MODEL} (stream) ==="
  chat "${MODEL}" true
done
