#!/usr/bin/env bash
# Create (or reuse) an AWS Organization, OU "inference", and member accounts A/B.
# Run with management-account credentials. Creating an Organization is one-way.
#
# Usage:
#   ./scripts/bootstrap-org.sh EMAIL_A EMAIL_B
#
# Env:
#   ACCOUNT_A_NAME   default mvp-bedrock-a
#   ACCOUNT_B_NAME   default mvp-bedrock-b
#   OU_NAME          default inference
#   ORG_ACCESS_ROLE  default OrganizationAccountAccessRole
set -euo pipefail

EMAIL_A="${1:-${EMAIL_A:-}}"
EMAIL_B="${2:-${EMAIL_B:-}}"
NAME_A="${ACCOUNT_A_NAME:-mvp-bedrock-a}"
NAME_B="${ACCOUNT_B_NAME:-mvp-bedrock-b}"
OU_NAME="${OU_NAME:-inference}"
ROLE_NAME="${ORG_ACCESS_ROLE:-OrganizationAccountAccessRole}"

die() { echo "error: $*" >&2; exit 1; }

[[ -n "${EMAIL_A}" && -n "${EMAIL_B}" ]] || die "usage: $0 EMAIL_A EMAIL_B"
[[ "${EMAIL_A}" != "${EMAIL_B}" ]] || die "EMAIL_A and EMAIL_B must be different unused addresses"
command -v aws >/dev/null || die "aws CLI required"

if aws organizations describe-organization >/dev/null 2>&1; then
  echo "Using existing organization"
else
  echo "Creating organization (ALL feature set)…"
  aws organizations create-organization --feature-set ALL >/dev/null
fi

ORG_ID="$(aws organizations describe-organization --query 'Organization.Id' --output text)"
MGMT_ID="$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)"
ROOT_ID="$(aws organizations list-roots --query 'Roots[0].Id' --output text)"
echo "Organization ${ORG_ID}  management ${MGMT_ID}  root ${ROOT_ID}"

OU_ID="$(aws organizations list-organizational-units-for-parent \
  --parent-id "${ROOT_ID}" \
  --query "OrganizationalUnits[?Name=='${OU_NAME}'].Id | [0]" \
  --output text)"
if [[ -z "${OU_ID}" || "${OU_ID}" == "None" ]]; then
  echo "Creating OU ${OU_NAME}…"
  OU_ID="$(aws organizations create-organizational-unit \
    --parent-id "${ROOT_ID}" \
    --name "${OU_NAME}" \
    --query 'OrganizationalUnit.Id' \
    --output text)"
fi
echo "OU ${OU_NAME}  ${OU_ID}"

find_account() {
  local name="$1" email="$2"
  local id
  id="$(aws organizations list-accounts \
    --query "Accounts[?Email=='${email}' && Status!='SUSPENDED'].Id | [0]" \
    --output text)"
  if [[ -n "${id}" && "${id}" != "None" ]]; then
    echo "${id}"
    return 0
  fi
  id="$(aws organizations list-accounts \
    --query "Accounts[?Name=='${name}' && Status=='ACTIVE'].Id | [0]" \
    --output text)"
  if [[ -n "${id}" && "${id}" != "None" ]]; then
    echo "${id}"
    return 0
  fi
  return 1
}

wait_create_account() {
  local request_id="$1" name="$2"
  local state reason account_id
  while true; do
    state="$(aws organizations describe-create-account-status \
      --create-account-request-id "${request_id}" \
      --query 'CreateAccountStatus.State' \
      --output text)"
    case "${state}" in
      SUCCEEDED)
        aws organizations describe-create-account-status \
          --create-account-request-id "${request_id}" \
          --query 'CreateAccountStatus.AccountId' \
          --output text
        return 0
        ;;
      FAILED)
        reason="$(aws organizations describe-create-account-status \
          --create-account-request-id "${request_id}" \
          --query 'CreateAccountStatus.FailureReason' \
          --output text)"
        die "create-account ${name} failed: ${reason}"
        ;;
      IN_PROGRESS)
        echo "  waiting for ${name}…"
        sleep 15
        ;;
      *)
        die "create-account ${name} unexpected state ${state}"
        ;;
    esac
  done
}

ensure_account() {
  local name="$1" email="$2"
  local id request_id
  if id="$(find_account "${name}" "${email}")"; then
    echo "Reusing account ${name}  ${id}" >&2
    echo "${id}"
    return 0
  fi
  echo "Creating account ${name} <${email}>…" >&2
  request_id="$(aws organizations create-account \
    --email "${email}" \
    --account-name "${name}" \
    --role-name "${ROLE_NAME}" \
    --query 'CreateAccountStatus.Id' \
    --output text)"
  wait_create_account "${request_id}" "${name}"
}

move_into_ou() {
  local account_id="$1"
  local parent
  parent="$(aws organizations list-parents \
    --child-id "${account_id}" \
    --query 'Parents[0].Id' \
    --output text)"
  if [[ "${parent}" == "${OU_ID}" ]]; then
    return 0
  fi
  echo "Moving ${account_id} → OU ${OU_NAME}…"
  aws organizations move-account \
    --account-id "${account_id}" \
    --source-parent-id "${parent}" \
    --destination-parent-id "${OU_ID}"
}

ACCOUNT_A_ID="$(ensure_account "${NAME_A}" "${EMAIL_A}")"
ACCOUNT_B_ID="$(ensure_account "${NAME_B}" "${EMAIL_B}")"
move_into_ou "${ACCOUNT_A_ID}"
move_into_ou "${ACCOUNT_B_ID}"

ROLE_A="arn:aws:iam::${ACCOUNT_A_ID}:role/${ROLE_NAME}"
ROLE_B="arn:aws:iam::${ACCOUNT_B_ID}:role/${ROLE_NAME}"

cat <<EOF

Done.

  Organization     ${ORG_ID}
  Management       ${MGMT_ID}
  OU ${OU_NAME}    ${OU_ID}
  Account A        ${ACCOUNT_A_ID}  ${NAME_A}  ${ROLE_A}
  Account B        ${ACCOUNT_B_ID}  ${NAME_B}  ${ROLE_B}

GitHub Actions variables (Settings → Secrets and variables → Actions):

  ACCOUNT_A_ID=${ACCOUNT_A_ID}
  ACCOUNT_B_ID=${ACCOUNT_B_ID}

Deploy the current stack into a member account:

  ./scripts/deploy-member.sh ${ACCOUNT_A_ID}
  ./scripts/deploy-member.sh ${ACCOUNT_B_ID}

Enable Bedrock model access in each member account (console) before calling the API.
EOF
