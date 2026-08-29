#!/usr/bin/env bash
# sam deploy with the same parameter-overrides as GitHub Actions.
# Requires: sam build already run, AWS credentials for the target account.
#
# Env: API_KEY or INFERENCE_API_KEY (required), MODEL_ID, MODEL_MAP, GUARDRAIL_ID, GUARDRAIL_VERSION,
#      AWS_REGION (default us-east-1), STACK_NAME (default bedrock-inference-mvp)
set -euo pipefail

API_KEY="${API_KEY:-${INFERENCE_API_KEY:-}}"
[[ -n "${API_KEY}" ]] || { echo "error: API_KEY or INFERENCE_API_KEY is required" >&2; exit 1; }

MODEL_ID="${MODEL_ID:-amazon.nova-lite-v1:0}"
STACK_NAME="${STACK_NAME:-bedrock-inference-mvp}"
REGION="${AWS_REGION:-us-east-1}"

PARAMS=(
  "ModelId=${MODEL_ID}"
  "ApiKey=${API_KEY}"
)
if [[ -n "${MODEL_MAP:-}" ]]; then
  PARAMS+=("ModelMap=${MODEL_MAP}")
fi
if [[ -n "${GUARDRAIL_ID:-}" ]]; then
  PARAMS+=("GuardrailId=${GUARDRAIL_ID}")
fi
if [[ -n "${GUARDRAIL_VERSION:-}" ]]; then
  PARAMS+=("GuardrailVersion=${GUARDRAIL_VERSION}")
fi

sam deploy \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --resolve-s3 \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides "${PARAMS[@]}"
