# Multi-account org (central + A + B)

Org **central** is the current AWS account (management / payer): billing and Organizations only. **Account A** and **Account B** each run the same Bedrock inference Lambda (`bedrock-inference-mvp`). No central Guardrail.

```
Organization (this account)
└── OU inference
    ├── tb_bedrock_a   same Terraform Lambda
    └── tb_bedrock_b   same Terraform Lambda
```

Creating an Organization is one-way for the management account.

Member-account emails are Terraform defaults in [`terraform/org/variables.tf`](../terraform/org/variables.tf):

- A: `tb_bedrock_a@gmail.com`
- B: `tb_bedrock_b@gmail.com`

Do not change those emails after the accounts exist (Terraform would try to replace the account). Override only before first create: `TF_VAR_email_a` / `TF_VAR_email_b`.

## 1. OIDC role, then push

GitHub assumes a management-account role over OIDC (no `AWS_ACCESS_KEY_ID`). One-time setup from this account:

```bash
./scripts/setup-gha-oidc-role.sh
```

Then set variable `AWS_ROLE_ARN` to the printed role. That role needs Organizations plus `sts:AssumeRole` on `OrganizationAccountAccessRole` in A and B.

Push to `main`. The **Deploy** workflow:

1. Deploys this account with Terraform
2. `terraform apply`s `terraform/org` (Organization, OU `inference`, accounts A and B)
3. Waits until `OrganizationAccountAccessRole` works in each member
4. Assumes that role and `terraform apply`s the same Lambda into A and B

To bootstrap locally:

```bash
./scripts/bootstrap-org.sh
```

## 2. Deploy locally (optional)

Management credentials, `API_KEY` or `INFERENCE_API_KEY` set:

```bash
export INFERENCE_API_KEY='your-shared-secret'
./scripts/deploy-member.sh ACCOUNT_A_ID
./scripts/deploy-member.sh ACCOUNT_B_ID
```

Each member gets its own Function URL. Bedrock **model access is per account** — enable the same marketplace models in A and in B (console) as you did here.

## 3. Test

```bash
export INFERENCE_API_KEY='1234'
FUNCTION_URL='https://...account-a.../' bash example.md
FUNCTION_URL='https://...account-b.../' bash example.md
```

To print a member URL after deploy:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_A_ID:role/OrganizationAccountAccessRole \
  --role-session-name print-url \
  --query 'Credentials' --output json
# export the three keys, then:
aws lambda get-function-url-config \
  --region us-east-1 \
  --function-name bedrock-inference-mvp \
  --query FunctionUrl \
  --output text
```
