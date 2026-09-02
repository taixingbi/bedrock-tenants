#!/usr/bin/env bash
# Smoke-test marketplace aliases (sync + stream).
#
#   ./scripts/smoke.sh
#   ./scripts/smoke.sh ministral-8b llama4
#   ACCOUNT=a ./scripts/smoke.sh ministral-8b
#   ACCOUNT=c ./scripts/smoke.sh
#   FUNCTION_URL='https://..../' ./scripts/smoke.sh ministral-8b
#
# ACCOUNT=a|b|c|d (bedrock-tenant-*) assumes OrganizationAccountAccessRole
# in a subshell to read the Function URL. Curl does not need AWS creds.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

MODELS=(
  qwen3-next-80b-a3b
  nova-pro
  nova-micro
  llama
  llama4
  llama4-maverick
  minilm-l12-h384
  gpt-oss
  gpt-oss-safeguard-20b
  gpt-oss-safeguard-120b
  deepseek
  ministral-3b
  ministral-8b
  ministral-14b
  gemma-3-4b
  gemma-3-12b
  gemma-3-27b
  qwen3-32b
)

member_url() {
  local want="$1" name email id
  case "${want}" in
    a|A)
      name="bedrock-tenant-a"
      email="tb_bedrock_a@gmail.com"
      ;;
    b|B)
      name="bedrock-tenant-b"
      email="tb_bedrock_b@gmail.com"
      ;;
    c|C)
      name="bedrock-tenant-c"
      email="tb_bedrock_c@gmail.com"
      ;;
    d|D)
      name="bedrock-tenant-d"
      email="tb_bedrock_d@gmail.com"
      ;;
    *)
      die "ACCOUNT must be a, b, c, or d"
      ;;
  esac
  command -v aws >/dev/null || die "aws CLI required for ACCOUNT=${want}"
  id="$(aws organizations list-accounts \
    --query "Accounts[?(Email=='${email}' || Name=='${name}') && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  [[ -n "${id}" && "${id}" != "None" ]] || die "member account ${want} not found"
  aws sts assume-role \
    --role-arn "arn:aws:iam::${id}:role/OrganizationAccountAccessRole" \
    --role-session-name "smoke-${want}" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text \
    | {
        read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        if ! aws lambda get-function-url-config \
          --region us-east-1 \
          --function-name bedrock-inference-mvp \
          --query FunctionUrl \
          --output text 2>/dev/null; then
          die "Lambda bedrock-inference-mvp is not deployed in ${name} (${id}). Run: ./scripts/deploy-member.sh ${id}"
        fi
      }
}

if [[ -n "${FUNCTION_URL:-}" ]]; then
  :
elif [[ -n "${ACCOUNT:-}" ]]; then
  if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
    die "ACCOUNT=${ACCOUNT} needs management-account AWS creds; unset AWS_SESSION_TOKEN first"
  fi
  FUNCTION_URL="$(member_url "${ACCOUNT}")"
else
  command -v aws >/dev/null || die "set FUNCTION_URL or ACCOUNT=a|b|c|d"
  FUNCTION_URL="$(aws lambda get-function-url-config \
    --region us-east-1 \
    --function-name bedrock-inference-mvp \
    --query FunctionUrl \
    --output text)"
fi

FUNCTION_URL="${FUNCTION_URL%/}/"
[[ -n "${FUNCTION_URL}" && "${FUNCTION_URL}" != "None/" && "${FUNCTION_URL}" != "/" ]] \
  || die "FUNCTION_URL is empty"
INFERENCE_API_KEY="${INFERENCE_API_KEY:-${API_KEY:-1234}}"

if [[ $# -gt 0 ]]; then
  MODELS=("$@")
fi

echo "URL  ${FUNCTION_URL}"
echo "key  ${INFERENCE_API_KEY:0:2}… (${#INFERENCE_API_KEY} chars)"
echo

chat() {
  local model="$1"
  local stream="${2:-false}"
  local extra="${3:-{}}"
  local body tmp code
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
  tmp="$(mktemp)"
  code="$(curl -sS -o "${tmp}" -w '%{http_code}' -X POST "${FUNCTION_URL}v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
    -d "${body}")"
  echo "HTTP ${code}"
  if [[ "${stream}" == "true" ]]; then
    cat "${tmp}"
  elif jq -e 'type == "object" and (.choices[0].message.content != null or .error != null or .errorType != null)' >/dev/null 2>&1 <"${tmp}"; then
    jq '{error, errorType, detail: (.detail // .errorMessage), message: .Message, model, answer: .choices[0].message.content, usage}' "${tmp}"
  else
    cat "${tmp}"
  fi
  rm -f "${tmp}"
  echo
}

for MODEL in "${MODELS[@]}"; do
  echo "=== ${MODEL} ==="
  chat "${MODEL}" false
  echo "=== ${MODEL} (stream) ==="
  chat "${MODEL}" true
done
