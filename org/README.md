# Multi-account org (central + A + B)

Org **central** is the current AWS account (management / payer): billing and Organizations only. **Account A** and **Account B** each run the same Bedrock inference stack as this repo (`bedrock-inference-mvp`). No central Guardrail.

```
Organization (this account)
└── OU inference
    ├── mvp-bedrock-a   same SAM app
    └── mvp-bedrock-b   same SAM app
```

Creating an Organization is one-way for the management account. You need **two unused email addresses**.

## 1. Set emails, then push

Add repository **variables** (or secrets) `EMAIL_A` and `EMAIL_B`. Management-account keys stay in `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` and need Organizations plus `sts:AssumeRole`.

Push to `main`. The **Deploy** workflow:

1. Deploys this account (existing stack)
2. Creates the Organization if needed, OU `inference`, and accounts `mvp-bedrock-a` / `mvp-bedrock-b` (idempotent — reuses them on later pushes)
3. Waits until `OrganizationAccountAccessRole` works in each member
4. Assumes that role and `sam deploy`s the same stack into A and B

To bootstrap locally instead of waiting for CI:

```bash
./scripts/bootstrap-org.sh EMAIL_A EMAIL_B
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
aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text
```
