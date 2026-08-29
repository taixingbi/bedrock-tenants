# Multi-account org (central + A + B)

Org **central** is the current AWS account (management / payer): billing and Organizations only. **Account A** and **Account B** each run the same Bedrock inference stack as this repo (`bedrock-inference-mvp`). No central Guardrail.

```
Organization (this account)
└── OU inference
    ├── mvp-bedrock-a   same SAM app
    └── mvp-bedrock-b   same SAM app
```

Creating an Organization is one-way for the management account. You need **two unused email addresses**.

## 1. Bootstrap

From the management account:

```bash
./scripts/bootstrap-org.sh EMAIL_A EMAIL_B
```

The script creates the org if needed, OU `inference`, accounts `mvp-bedrock-a` / `mvp-bedrock-b`, and prints `ACCOUNT_A_ID` / `ACCOUNT_B_ID`.

Add those as GitHub Actions **variables** (Settings → Secrets and variables → Actions):

| Variable | Purpose |
| --- | --- |
| `ACCOUNT_A_ID` | Member account A |
| `ACCOUNT_B_ID` | Member account B |

Existing secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `INFERENCE_API_KEY`) stay on the management account. The default role `OrganizationAccountAccessRole` in A/B trusts the management account, so those keys can assume it.

## 2. Deploy the app into A and B

Local (management credentials, `API_KEY` set):

```bash
export API_KEY='your-shared-secret'
./scripts/deploy-member.sh ACCOUNT_A_ID
./scripts/deploy-member.sh ACCOUNT_B_ID
```

Or push to `main`. The **Deploy** workflow still deploys this account, then (when `ACCOUNT_A_ID` / `ACCOUNT_B_ID` are set) assumes into each member and `sam deploy`s the same stack.

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
