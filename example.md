# Smoke test

The runner is [`scripts/smoke.sh`](scripts/smoke.sh), not this file.

```bash
# This account (whatever aws CLI is logged in as):
./scripts/smoke.sh ministral-8b

# Tenant A–D in OU bedrock-inference-dev (management-account AWS creds; no leftover AWS_SESSION_TOKEN):
ACCOUNT=a ./scripts/smoke.sh ministral-8b
ACCOUNT=b ./scripts/smoke.sh
ACCOUNT=c ./scripts/smoke.sh
ACCOUNT=d ./scripts/smoke.sh

# Explicit URL (no aws needed):
FUNCTION_URL='https://..../' INFERENCE_API_KEY='1234' ./scripts/smoke.sh llama4
```

Omit the model name to hit every marketplace alias (sync + stream). Curl uses the API key only; `ACCOUNT=a|b|c|d` assumes the tenant role in a subshell just to read the Function URL.
