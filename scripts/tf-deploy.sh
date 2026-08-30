#!/usr/bin/env bash
# Package the Lambda and terraform apply (replaces sam deploy).
# Requires AWS credentials for the target account.
#
# Env: API_KEY or INFERENCE_API_KEY (required), MODEL_ID, MODEL_MAP,
#      AWS_REGION (default us-east-1), FUNCTION_NAME (default bedrock-inference-mvp)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_KEY="${API_KEY:-${INFERENCE_API_KEY:-}}"
[[ -n "${API_KEY}" ]] || { echo "error: API_KEY or INFERENCE_API_KEY is required" >&2; exit 1; }

command -v aws >/dev/null || { echo "error: aws CLI required" >&2; exit 1; }
command -v terraform >/dev/null || { echo "error: terraform required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 required" >&2; exit 1; }

MODEL_ID="${MODEL_ID:-amazon.nova-lite-v1:0}"
FUNCTION_NAME="${FUNCTION_NAME:-bedrock-inference-mvp}"
REGION="${AWS_REGION:-us-east-1}"
ZIP="${ROOT}/terraform/.build/lambda.zip"

echo "Packaging Lambda…"
"${ROOT}/scripts/package-lambda.sh" "${ZIP}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="bedrock-inference-tfstate-${ACCOUNT_ID}"

if ! aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Creating Terraform state bucket ${BUCKET}…"
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  aws s3api put-bucket-versioning --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled
  aws s3api put-public-access-block --bucket "${BUCKET}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption --bucket "${BUCKET}" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
fi

if aws cloudformation describe-stacks --stack-name "${FUNCTION_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Deleting SAM/CloudFormation stack ${FUNCTION_NAME} so Terraform owns the Lambda…"
  aws cloudformation delete-stack --stack-name "${FUNCTION_NAME}" --region "${REGION}"
  aws cloudformation wait stack-delete-complete --stack-name "${FUNCTION_NAME}" --region "${REGION}"
fi

cd "${ROOT}/terraform"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=${FUNCTION_NAME}.tfstate" \
  -backend-config="region=${REGION}"

export TF_VAR_aws_region="${REGION}"
export TF_VAR_function_name="${FUNCTION_NAME}"
export TF_VAR_lambda_zip="${ZIP}"
export TF_VAR_model_id="${MODEL_ID}"
export TF_VAR_model_map="${MODEL_MAP:-}"
export TF_VAR_api_key="${API_KEY}"
export TF_VAR_lambda_s3_bucket="${BUCKET}"
export TF_VAR_lambda_s3_key="${FUNCTION_NAME}/lambda.zip"

terraform apply -input=false -auto-approve

echo
echo "Function URL:"
terraform output -raw function_url
echo
