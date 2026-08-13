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
      max_tokens: 256,
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

# Marketplace models (Converse, us-east-1). Alias → Bedrock ID:
#   qwen3-next-80b-a3b       Qwen3 Next 80B A3B (MoE)              qwen.qwen3-next-80b-a3b
#   nova-pro                 Amazon Nova Pro                        amazon.nova-pro-v1:0
#   llama                    Meta Llama 3.3 70B Instruct            us.meta.llama3-3-70b-instruct-v1:0  (US geo)
#   gpt-oss                  OpenAI GPT-OSS 120B                    openai.gpt-oss-120b-1:0
#   gpt-oss-safeguard-20b    OpenAI GPT-OSS Safeguard 20B (safety)  openai.gpt-oss-safeguard-20b
#   gpt-oss-safeguard-120b   OpenAI GPT-OSS Safeguard 120B (safety) openai.gpt-oss-safeguard-120b
#   (Safeguard/GPT-OSS emit reasoning first — use max_tokens >= 256 for a final answer.)
#   deepseek                 DeepSeek V3.2                          deepseek.v3.2
#   ministral-3b             Ministral 3 3B     ⭐⭐⭐⭐              mistral.ministral-3-3b-instruct
#   ministral-8b             Ministral 3 8B     ⭐⭐⭐⭐⭐            mistral.ministral-3-8b-instruct
#   ministral-14b            Ministral 3 14B    ⭐⭐⭐⭐⭐            mistral.ministral-3-14b-instruct
#   gemma-3-4b               Gemma 3 4B IT      ⭐⭐⭐                google.gemma-3-4b-it
#   gemma-3-12b              Gemma 3 12B IT     ⭐⭐⭐⭐              google.gemma-3-12b-it
#   gemma-3-27b              Gemma 3 27B IT     ⭐⭐⭐                google.gemma-3-27b-it
#   qwen3-32b                Qwen3 32B dense    ⭐⭐⭐⭐⭐            qwen.qwen3-32b-v1:0

for MODEL in \
  qwen3-next-80b-a3b \
  nova-pro \
  llama \
  gpt-oss \
  gpt-oss-safeguard-20b \
  gpt-oss-safeguard-120b \
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
