#!/usr/bin/env bash
# Terraform-apply the Organization, OU bedrock-inference-dev, and accounts A–D.
# Emails live in terraform/org/variables.tf (override with TF_VAR_email_*).
# Run with management-account credentials. Creating an Organization is one-way.
#
# Usage:
#   ./scripts/bootstrap-org.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORG_DIR="${ROOT}/terraform/org"
REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="${ORG_ACCESS_ROLE:-OrganizationAccountAccessRole}"

die() { echo "error: $*" >&2; exit 1; }
command -v aws >/dev/null || die "aws CLI required"
command -v terraform >/dev/null || die "terraform required"

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

cd "${ORG_DIR}"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=org.tfstate" \
  -backend-config="region=${REGION}"

import_if_missing() {
  local addr="$1" id="${2:-}"
  [[ -n "${id}" && "${id}" != "None" && "${id}" != "null" ]] || return 0
  if terraform state show "${addr}" >/dev/null 2>&1; then
    return 0
  fi
  echo "Importing ${addr} ${id}…"
  terraform import -input=false "${addr}" "${id}"
}

if aws organizations describe-organization >/dev/null 2>&1; then
  ORG_ID="$(aws organizations describe-organization --query 'Organization.Id' --output text)"
  ROOT_ID="$(aws organizations list-roots --query 'Roots[0].Id' --output text)"
  import_if_missing aws_organizations_organization.this "${ORG_ID}"

  OU_NAME="${TF_VAR_ou_name:-bedrock-inference-dev}"
  OU_ID="$(aws organizations list-organizational-units-for-parent \
    --parent-id "${ROOT_ID}" \
    --query "OrganizationalUnits[?Name=='${OU_NAME}'].Id | [0]" \
    --output text)"
  import_if_missing aws_organizations_organizational_unit.inference "${OU_ID}"

  EMAIL_A="${TF_VAR_email_a:-tb_bedrock_a@gmail.com}"
  EMAIL_B="${TF_VAR_email_b:-tb_bedrock_b@gmail.com}"
  EMAIL_C="${TF_VAR_email_c:-tb_bedrock_c@gmail.com}"
  EMAIL_D="${TF_VAR_email_d:-tb_bedrock_d@gmail.com}"
  ID_A="$(aws organizations list-accounts \
    --query "Accounts[?Email=='${EMAIL_A}' && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  ID_B="$(aws organizations list-accounts \
    --query "Accounts[?Email=='${EMAIL_B}' && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  ID_C="$(aws organizations list-accounts \
    --query "Accounts[?Email=='${EMAIL_C}' && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  ID_D="$(aws organizations list-accounts \
    --query "Accounts[?Email=='${EMAIL_D}' && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  import_if_missing aws_organizations_account.a "${ID_A}"
  import_if_missing aws_organizations_account.b "${ID_B}"
  import_if_missing aws_organizations_account.c "${ID_C}"
  import_if_missing aws_organizations_account.d "${ID_D}"
fi

export TF_VAR_aws_region="${REGION}"
export TF_VAR_role_name="${ROLE_NAME}"
terraform apply -input=false -auto-approve

ACCOUNT_A_ID="$(terraform output -raw account_a_id)"
ACCOUNT_B_ID="$(terraform output -raw account_b_id)"
ACCOUNT_C_ID="$(terraform output -raw account_c_id)"
ACCOUNT_D_ID="$(terraform output -raw account_d_id)"
ORG_ID="$(terraform output -raw organization_id)"
MGMT_ID="$(terraform output -raw management_account_id)"
OU_ID="$(terraform output -raw ou_id)"

wait_role() {
  local account_id="$1"
  local role_arn="arn:aws:iam::${account_id}:role/${ROLE_NAME}"
  local i
  for i in $(seq 1 40); do
    if aws sts assume-role \
      --role-arn "${role_arn}" \
      --role-session-name "wait-${account_id}" \
      --duration-seconds 900 \
      --query 'Credentials.AccessKeyId' \
      --output text >/dev/null 2>&1; then
      echo "Role ready  ${role_arn}"
      return 0
    fi
    echo "  waiting for ${role_arn}…"
    sleep 15
  done
  die "timed out waiting for ${role_arn}"
}

wait_role "${ACCOUNT_A_ID}"
wait_role "${ACCOUNT_B_ID}"
wait_role "${ACCOUNT_C_ID}"
wait_role "${ACCOUNT_D_ID}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "ACCOUNT_A_ID=${ACCOUNT_A_ID}"
    echo "ACCOUNT_B_ID=${ACCOUNT_B_ID}"
    echo "ACCOUNT_C_ID=${ACCOUNT_C_ID}"
    echo "ACCOUNT_D_ID=${ACCOUNT_D_ID}"
  } >> "${GITHUB_OUTPUT}"
fi

cat <<EOF

Done.

  Organization     ${ORG_ID}
  Management       ${MGMT_ID}
  OU               ${OU_ID}
  Account A        ${ACCOUNT_A_ID}
  Account B        ${ACCOUNT_B_ID}
  Account C        ${ACCOUNT_C_ID}
  Account D        ${ACCOUNT_D_ID}

Emails are in terraform/org/variables.tf. Push deploys the Lambda into each account.
Or deploy locally:

  ./scripts/deploy-member.sh ${ACCOUNT_A_ID}
  ./scripts/deploy-member.sh ${ACCOUNT_B_ID}
  ./scripts/deploy-member.sh ${ACCOUNT_C_ID}
  ./scripts/deploy-member.sh ${ACCOUNT_D_ID}

Enable Bedrock model access in each member account (console) before calling the API.
EOF
