# Bedrock MVP Inference API

Python Lambda with a Function URL that sends prompts to Amazon Bedrock via the boto3 **Converse** API.

## Prerequisites

1. AWS account with permission to create Lambda, IAM roles, and call Bedrock
2. [Model access enabled](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) for marketplace models (default: `amazon.nova-lite-v1:0`), **or** a successfully [imported custom model](https://docs.aws.amazon.com/bedrock/latest/userguide/model-customization-import-model.html)
3. [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) for local builds
4. GitHub repository secrets (Settings → Secrets and variables → Actions):

| Secret | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Deploy credentials |
| `AWS_SECRET_ACCESS_KEY` | Deploy credentials |
| `INFERENCE_API_KEY` | Shared secret clients must send as `x-api-key` |

Optional repository variables:

| Variable | Purpose |
| --- | --- |
| `AWS_REGION` | Region for deploy and Bedrock (defaults to `us-east-1`) |
| `MODEL_ID` | Default Bedrock model ID or **imported model ARN** when the request omits `model` (defaults to `amazon.nova-lite-v1:0`) |
| `MODEL_MAP` | Optional JSON object of request alias → Bedrock ID/ARN (merges with built-in aliases) |

The Lambda talks to Bedrock with its **execution role**, not with the deploy access keys. Bedrock is managed inference — you do not choose a GPU.

## Models

The request `model` field selects which Bedrock backend to call. Built-in aliases:

| Request `model` | Bedrock ID | API |
| --- | --- | --- |
| `nova-pro` / `amazon.nova-pro-v1:0` | `amazon.nova-pro-v1:0` | Converse |
| `us.amazon.nova-pro-v1:0` | US geo inference profile | Converse |
| `nova-lite` / `amazon.nova-lite-v1:0` | `amazon.nova-lite-v1:0` | Converse |
| `llama` / `llama3.3` / `llama-3.3-70b` | `us.meta.llama3-3-70b-instruct-v1:0` | Converse |
| `llama4` / `llama4-maverick` | `us.meta.llama4-maverick-17b-instruct-v1:0` | Converse |
| `llama4-scout` | `us.meta.llama4-scout-17b-instruct-v1:0` | Converse |
| `gpt-oss` / `gpt-oss-120b` | `openai.gpt-oss-120b-1:0` | Converse |
| `gpt-oss-20b` | `openai.gpt-oss-20b-1:0` | Converse |
| `deepseek` / `deepseek.v3.2` | `deepseek.v3.2` | Converse |
| `deepseek-r1` | `us.deepseek.r1-v1:0` | Converse |
| `qwen3-next-80b-a3b` / `qwen.qwen3-next-80b-a3b` | `qwen.qwen3-next-80b-a3b` | Converse |
| `ministral-3b` / `ministral-3-3b` | `mistral.ministral-3-3b-instruct` | Converse |
| `ministral-8b` / `ministral-3-8b` | `mistral.ministral-3-8b-instruct` | Converse |
| `ministral-14b` / `ministral-3-14b` | `mistral.ministral-3-14b-instruct` | Converse |
| `gemma-3-4b` / `gemma-3-4b-it` | `google.gemma-3-4b-it` | Converse |
| `gemma-3-12b` / `gemma-3-12b-it` | `google.gemma-3-12b-it` | Converse |
| `gemma-3-27b` / `gemma-3-27b-it` | `google.gemma-3-27b-it` | Converse |
| `qwen3-32b` / `Qwen/Qwen3-32B` | `qwen.qwen3-32b-v1:0` | Converse |

Raw Bedrock IDs and imported-model ARNs are also accepted. Unknown names return `400`.

Recommended open models (us-east-1, Bedrock Runtime):

| Model | 参数量 | Alias | Bedrock ID | us-east-1 | Bedrock Runtime | 推荐度 |
| --- | --- | --- | --- | --- | --- | --- |
| Ministral 3 3B | 3B | `ministral-3b` | `mistral.ministral-3-3b-instruct` | ✅ | ✅ | ⭐⭐⭐⭐ |
| Gemma 3 4B IT | 4B | `gemma-3-4b` | `google.gemma-3-4b-it` | ✅ | ✅ | ⭐⭐⭐ |
| Ministral 3 8B | 8B | `ministral-8b` | `mistral.ministral-3-8b-instruct` | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| Gemma 3 12B IT | 12B | `gemma-3-12b` | `google.gemma-3-12b-it` | ✅ | ✅ | ⭐⭐⭐⭐ |
| Ministral 3 14B | 14B | `ministral-14b` | `mistral.ministral-3-14b-instruct` | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| Gemma 3 27B | 27B | `gemma-3-27b` | `google.gemma-3-27b-it` | ✅ | ✅ | ⭐⭐⭐ |
| Qwen3 32B | 32B | `qwen3-32b` | `qwen.qwen3-32b-v1:0` | ✅ | ✅ | ⭐⭐⭐⭐⭐ |

Override or add aliases with the `MODEL_MAP` env / repo variable, e.g.:

```json
{"my-model":"amazon.nova-pro-v1:0"}
```

### Default (marketplace)

`amazon.nova-lite-v1:0` — enable access in the Bedrock console for `us-east-1`, then deploy (or set repo variable `MODEL_ID`).

### Amazon Nova Pro (marketplace)

Enable model access in the Bedrock console, then call:

```json
{"model": "nova-pro", "messages": [{"role": "user", "content": "Hello"}]}
```

Optional catalog manifest:

```bash
./scripts/upload-model-to-s3.sh nova-pro
# → s3://bedrock-models-646821141010/amazon/nova-pro-v1/model-manifest.json
```

| Mode | Bedrock ID |
| --- | --- |
| In-region (`us-east-1`) | `amazon.nova-pro-v1:0` |
| US geo cross-region | `us.amazon.nova-pro-v1:0` |

### Meta Llama (marketplace)

Enable Meta model access in the Bedrock console. Friendly aliases default to the **US geo inference profile** (required for on-demand on many Llama IDs):

```json
{"model": "llama", "messages": [{"role": "user", "content": "Hello"}]}
```

| Alias | Bedrock ID |
| --- | --- |
| `llama` / `llama3.3` | `us.meta.llama3-3-70b-instruct-v1:0` |
| `llama4` / `llama4-maverick` | `us.meta.llama4-maverick-17b-instruct-v1:0` |
| `llama4-scout` | `us.meta.llama4-scout-17b-instruct-v1:0` |

```bash
./scripts/upload-model-to-s3.sh llama
# → s3://bedrock-models-646821141010/meta/llama3-3-70b-instruct/model-manifest.json
```

### OpenAI GPT-OSS (marketplace)

Bedrock-hosted OpenAI open-weight models (not ChatGPT API keys). Enable access, then:

```json
{"model": "gpt-oss", "messages": [{"role": "user", "content": "Hello"}]}
```

| Alias | Bedrock ID |
| --- | --- |
| `gpt-oss` / `gpt-oss-120b` | `openai.gpt-oss-120b-1:0` |
| `gpt-oss-20b` | `openai.gpt-oss-20b-1:0` |

```bash
./scripts/upload-model-to-s3.sh gpt-oss
# → s3://bedrock-models-646821141010/openai/gpt-oss-120b/model-manifest.json
```

### DeepSeek (marketplace)

Enable DeepSeek access, then:

```json
{"model": "deepseek", "messages": [{"role": "user", "content": "Hello"}]}
```

| Alias | Bedrock ID |
| --- | --- |
| `deepseek` / `deepseek-v3.2` | `deepseek.v3.2` |
| `deepseek-r1` | `us.deepseek.r1-v1:0` |

```bash
./scripts/upload-model-to-s3.sh deepseek
# → s3://bedrock-models-646821141010/deepseek/deepseek-v3.2/model-manifest.json
```

### Qwen3 Next 80B A3B (marketplace)

Fully managed open-weight model on Bedrock (Converse). Enable access, then:

```json
{"model": "qwen3-next-80b-a3b", "messages": [{"role": "user", "content": "Hello"}]}
```

| Alias | Bedrock ID |
| --- | --- |
| `qwen3-next-80b-a3b` | `qwen.qwen3-next-80b-a3b` |
| `Qwen/Qwen3-Next-80B-A3B-Instruct` | `qwen.qwen3-next-80b-a3b` |

No geo inference profiles (in-region only).

```bash
./scripts/upload-model-to-s3.sh qwen3-next-80b-a3b
# → s3://bedrock-models-646821141010/qwen/qwen3-next-80b-a3b/model-manifest.json
```

### Ministral 3 / Gemma 3 / Qwen3 32B (marketplace)

Fully managed open-weight models on Bedrock (Converse). Enable access in `us-east-1`, then call:

```json
{"model": "ministral-8b", "messages": [{"role": "user", "content": "Hello"}]}
{"model": "gemma-3-12b", "messages": [{"role": "user", "content": "Hello"}]}
{"model": "qwen3-32b", "messages": [{"role": "user", "content": "Hello"}]}
```

| Alias | Bedrock ID |
| --- | --- |
| `ministral-3b` | `mistral.ministral-3-3b-instruct` |
| `ministral-8b` | `mistral.ministral-3-8b-instruct` |
| `ministral-14b` | `mistral.ministral-3-14b-instruct` |
| `gemma-3-4b` | `google.gemma-3-4b-it` |
| `gemma-3-12b` | `google.gemma-3-12b-it` |
| `gemma-3-27b` | `google.gemma-3-27b-it` |
| `qwen3-32b` | `qwen.qwen3-32b-v1:0` |

No geo inference profiles (in-region only).

```bash
./scripts/upload-model-to-s3.sh ministral-3b
./scripts/upload-model-to-s3.sh ministral-8b
./scripts/upload-model-to-s3.sh ministral-14b
./scripts/upload-model-to-s3.sh gemma-3-4b
./scripts/upload-model-to-s3.sh gemma-3-12b
./scripts/upload-model-to-s3.sh gemma-3-27b
./scripts/upload-model-to-s3.sh qwen3-32b
```

Shared models bucket (`us-east-1`) holds optional marketplace manifests (no HF weights) under `amazon/`, `meta/`, `openai/`, `deepseek/`, `qwen/`, `mistral/`, `google/`.

The handler picks the Bedrock API per resolved model:

- Marketplace models (Nova, Llama, GPT-OSS, DeepSeek, Qwen3, Ministral, Gemma, …) → **Converse**
- Raw imported-model ARNs (`:imported-model/…`) → **InvokeModel** (no built-in friendly aliases; `Qwen/Qwen2.5-7B-Instruct` is disabled)

## API

### OpenAI-compatible (preferred)

`POST` `/v1/chat/completions`

```json
{
  "model": "ministral-8b",
  "messages": [
    {"role": "system", "content": "optional system prompt"},
    {"role": "user", "content": "Hello"}
  ],
  "max_tokens": 512,
  "temperature": 0,
  "top_p": 1.0
}
```

Headers (either works):

- `Authorization: Bearer <INFERENCE_API_KEY>`
- `x-api-key: <INFERENCE_API_KEY>`

Success (OpenAI chat.completion shape):

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 0,
  "model": "ministral-8b",
  "choices": [
    {
      "index": 0,
      "message": {"role": "assistant", "content": "..."},
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0
  }
}
```

The `model` field selects the Bedrock backend (see [Models](#models)); the same name is echoed in the response.

Set `"stream": true` to receive OpenAI SSE (`text/event-stream`) chunks (`chat.completion.chunk` then `data: [DONE]`). Streaming uses Lambda Function URL `RESPONSE_STREAM` plus Bedrock `InvokeModelWithResponseStream` / `ConverseStream`.

## Deploy

Push to `main` or run the **Deploy** workflow manually. Stack name: `bedrock-inference-mvp` (region defaults to `us-east-1`).

After deploy, get the Function URL (include `--region` if `aws configure` has no default):

```bash
aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text
```

Or in the AWS Console: CloudFormation → stack `bedrock-inference-mvp` → **Outputs** → `InferenceFunctionUrl` (or Lambda → `bedrock-inference-mvp` → **Configuration** → **Function URL**).

### Manual deploy

```bash
sam build
sam deploy \
  --region us-east-1 \
  --parameter-overrides \
    ModelId=amazon.nova-lite-v1:0 \
    ApiKey='your-shared-secret'
```

## Call the API

Example (`ministral-8b`):

```bash
FUNCTION_URL=$(aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text)
INFERENCE_API_KEY='1234'

curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "ministral-8b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
```

See `example.md` (`bash example.md`) for a full sync+stream smoke test of all marketplace aliases.

Amazon Nova Pro (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "nova-pro",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

Meta Llama 3.3 (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "llama",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

OpenAI GPT-OSS (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gpt-oss",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

DeepSeek V3.2 (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "deepseek",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

Qwen3 Next 80B A3B (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "qwen3-next-80b-a3b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

Ministral 3 8B (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "ministral-8b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

Gemma 3 12B IT (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gemma-3-12b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

Qwen3 32B (marketplace):

```bash
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "qwen3-32b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{model, answer: .choices[0].message.content, usage}'
```

## Local invoke

Run the FastAPI app locally (uses your AWS credentials for Bedrock):

```bash
export API_KEY=local-dev-key
export MODEL_ID=amazon.nova-lite-v1:0
pip install -r src/requirements.txt
uvicorn app:app --app-dir src --host 127.0.0.1 --port 8080
```

Then:

```bash
curl -sS -N -X POST "http://127.0.0.1:8080/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer local-dev-key" \
  -d '{
    "model": "ministral-8b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
```