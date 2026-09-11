#!/usr/bin/env bash
# Tear down inference Lambdas, then close member accounts A–D and destroy the
# OU / Organization. Run with management-account credentials.
#
# Usage:
#   ./scripts/tf-destroy.sh
#
# Env: AWS_REGION (default us-east-1), FUNCTION_NAME (default bedrock-inference-mvp)
#      API_KEY / INFERENCE_API_KEY only needed if terraform still evaluates them
#      (defaults to 1234).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORG_DIR="${ROOT}/terraform/org"
TF_DIR="${ROOT}/terraform"
REGION="${AWS_REGION:-us-east-1}"
FUNCTION_NAME="${FUNCTION_NAME:-bedrock-inference-mvp}"
ROLE_NAME="${ORG_ACCESS_ROLE:-OrganizationAccountAccessRole}"
ZIP="${ROOT}/terraform/.build/lambda.zip"
API_KEY="${API_KEY:-${INFERENCE_API_KEY:-1234}}"

die() { echo "error: $*" >&2; exit 1; }
command -v aws >/dev/null || die "aws CLI required"
command -v terraform >/dev/null || die "terraform required"
command -v python3 >/dev/null || die "python3 required"

if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
  die "needs management-account AWS creds; unset AWS_SESSION_TOKEN first"
fi

MGMT_ID="$(aws sts get-caller-identity --query Account --output text)"
MGMT_BUCKET="bedrock-inference-tfstate-${MGMT_ID}"

ensure_zip() {
  if [[ -f "${ZIP}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${ZIP}")"
  python3 - "${ZIP}" <<'PY'
import pathlib, sys, zipfile
path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(path, "w") as zf:
    zf.writestr("dummy", "")
PY
}

export_lambda_vars() {
  local bucket="$1"
  export TF_VAR_aws_region="${REGION}"
  export TF_VAR_function_name="${FUNCTION_NAME}"
  export TF_VAR_lambda_zip="${ZIP}"
  export TF_VAR_model_id="${MODEL_ID:-amazon.nova-lite-v1:0}"
  export TF_VAR_model_map="${MODEL_MAP:-}"
  export TF_VAR_api_key="${API_KEY}"
  export TF_VAR_lambda_s3_bucket="${bucket}"
  export TF_VAR_lambda_s3_key="${FUNCTION_NAME}/lambda.zip"
}

destroy_lambda() {
  local label="$1"
  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text)"
  local bucket="bedrock-inference-tfstate-${account_id}"
  echo
  echo "======== Destroy ${FUNCTION_NAME} in ${label} (${account_id}) ========"
  if ! aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
    echo "No state bucket ${bucket}; skip."
    return 0
  fi
  export_lambda_vars "${bucket}"
  cd "${TF_DIR}"
  terraform init -input=false -reconfigure \
    -backend-config="bucket=${bucket}" \
    -backend-config="key=${FUNCTION_NAME}.tfstate" \
    -backend-config="region=${REGION}"
  terraform destroy -input=false -auto-approve
}

assume_member() {
  local account_id="$1"
  local creds
  creds="$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/${ROLE_NAME}" \
    --role-session-name "tf-destroy-${account_id}" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)" || return 1
  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<<"${creds}"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_REGION="${REGION}"
}

clear_assumed() {
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
}

member_id() {
  local email="$1" name="$2"
  aws organizations list-accounts \
    --query "Accounts[?(Email=='${email}' || Name=='${name}') && Status!='SUSPENDED'].Id | [0]" \
    --output text
}

ensure_zip

echo "Initializing org state and applying close_on_deletion=true…"
cd "${ORG_DIR}"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${MGMT_BUCKET}" \
  -backend-config="key=org.tfstate" \
  -backend-config="region=${REGION}"
export TF_VAR_aws_region="${REGION}"
export TF_VAR_role_name="${ROLE_NAME}"
terraform apply -input=false -auto-approve

EMAIL_A="${TF_VAR_email_a:-tb_bedrock_a@gmail.com}"
EMAIL_B="${TF_VAR_email_b:-tb_bedrock_b@gmail.com}"
EMAIL_C="${TF_VAR_email_c:-tb_bedrock_c@gmail.com}"
EMAIL_D="${TF_VAR_email_d:-tb_bedrock_d@gmail.com}"

ID_A="$(terraform output -raw account_a_id 2>/dev/null || true)"
ID_B="$(terraform output -raw account_b_id 2>/dev/null || true)"
ID_C="$(terraform output -raw account_c_id 2>/dev/null || true)"
ID_D="$(terraform output -raw account_d_id 2>/dev/null || true)"
[[ -n "${ID_A}" && "${ID_A}" != "None" ]] || ID_A="$(member_id "${EMAIL_A}" "bedrock-tenant-a")"
[[ -n "${ID_B}" && "${ID_B}" != "None" ]] || ID_B="$(member_id "${EMAIL_B}" "bedrock-tenant-b")"
[[ -n "${ID_C}" && "${ID_C}" != "None" ]] || ID_C="$(member_id "${EMAIL_C}" "bedrock-tenant-c")"
[[ -n "${ID_D}" && "${ID_D}" != "None" ]] || ID_D="$(member_id "${EMAIL_D}" "bedrock-tenant-d")"

clear_assumed
for pair in "a:${ID_A}" "b:${ID_B}" "c:${ID_C}" "d:${ID_D}"; do
  label="${pair%%:*}"
  id="${pair##*:}"
  [[ -n "${id}" && "${id}" != "None" && "${id}" != "null" ]] || {
    echo "No member account ${label}; skip Lambda destroy."
    continue
  }
  clear_assumed
  if ! assume_member "${id}"; then
    echo "Cannot assume ${ROLE_NAME} in ${label} (${id}); skip Lambda destroy."
    continue
  fi
  destroy_lambda "tenant-${label}"
done

clear_assumed
destroy_lambda "management"

echo
echo "======== Destroy Organization, OU, and member accounts ========"
echo "Closing A–D (close_on_deletion=true). Recreate needs unused root emails."
clear_assumed
cd "${ORG_DIR}"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${MGMT_BUCKET}" \
  -backend-config="key=org.tfstate" \
  -backend-config="region=${REGION}"
export TF_VAR_aws_region="${REGION}"
export TF_VAR_role_name="${ROLE_NAME}"

# Close members first so the OU is empty enough to delete when AWS allows it.
terraform destroy -input=false -auto-approve \
  -target=aws_organizations_account.a \
  -target=aws_organizations_account.b \
  -target=aws_organizations_account.c \
  -target=aws_organizations_account.d

if ! terraform destroy -input=false -auto-approve; then
  echo >&2
  echo "error: OU/Organization destroy failed. Closed member accounts stay in the org as PENDING_CLOSURE (~90 days); AWS will not delete a non-empty OU or Organization until then." >&2
  exit 1
fi

echo
echo "Destroy complete (Lambdas, accounts A–D, OU, Organization)."
