#!/usr/bin/env bash
# Assume OrganizationAccountAccessRole in a member account and sam deploy.
#
# Usage:
#   ./scripts/deploy-member.sh <account-id>
#
# Env:
#   API_KEY or INFERENCE_API_KEY  required
#   ORG_ACCESS_ROLE  default OrganizationAccountAccessRole
#   AWS_REGION       default us-east-1
#   MODEL_ID, MODEL_MAP, GUARDRAIL_ID, GUARDRAIL_VERSION
set -euo pipefail

ACCOUNT_ID="${1:-}"
ROLE_NAME="${ORG_ACCESS_ROLE:-OrganizationAccountAccessRole}"
REGION="${AWS_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "error: $*" >&2; exit 1; }

API_KEY="${API_KEY:-${INFERENCE_API_KEY:-}}"
export API_KEY

[[ -n "${ACCOUNT_ID}" ]] || die "usage: $0 <account-id>"
[[ -n "${API_KEY}" ]] || die "API_KEY or INFERENCE_API_KEY is required"
command -v aws >/dev/null || die "aws CLI required"
command -v sam >/dev/null || die "SAM CLI required"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "Assuming ${ROLE_ARN}…"
creds="$(aws sts assume-role \
  --role-arn "${ROLE_ARN}" \
  --role-session-name "deploy-${ACCOUNT_ID}" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)"
read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<<"${creds}"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_REGION="${REGION}"

echo "Building…"
(
  cd "${ROOT}"
  sam build
  echo "Deploying bedrock-inference-mvp to ${ACCOUNT_ID} (${REGION})…"
  "${ROOT}/scripts/sam-deploy.sh"
)

FUNCTION_URL="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text)"
FUNCTION_URL="${FUNCTION_URL%/}/"
echo
echo "Account ${ACCOUNT_ID} Function URL:"
echo "  ${FUNCTION_URL}"
echo
echo "Enable Bedrock model access in this account, then:"
echo "  FUNCTION_URL=${FUNCTION_URL} bash example.md"
