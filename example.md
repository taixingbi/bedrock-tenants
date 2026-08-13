FUNCTION_URL=$(aws cloudformation describe-stacks \
  --region us-east-1 \
  --stack-name bedrock-inference-mvp \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceFunctionUrl'].OutputValue" \
  --output text)
INFERENCE_API_KEY=1234

# Non-stream responses are JSON → pipe to jq.
# Stream responses are SSE (text/event-stream) → use curl -N, do NOT pipe to jq.

# Qwen (imported)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "top_p": 1.0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Qwen (imported, stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "top_p": 1.0,
    "stream": true
  }'
echo

# Qwen3 Next 80B A3B (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "qwen3-next-80b-a3b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Qwen3 Next 80B A3B (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "qwen3-next-80b-a3b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# Amazon Nova Pro (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "nova-pro",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Amazon Nova Pro (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "nova-pro",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# Meta Llama 3.3 (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "llama",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Meta Llama 3.3 (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "llama",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# OpenAI GPT-OSS (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gpt-oss",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# OpenAI GPT-OSS (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gpt-oss",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# OpenAI GPT-5.5 (marketplace, Mantle) — omit temperature / top_p
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gpt-5.5",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# OpenAI GPT-5.5 (stream — Mantle Responses SSE → chat chunks)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gpt-5.5",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "stream": true
  }'
echo

# Claude Sonnet 4 (marketplace) — needs Anthropic use-case form
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "claude-sonnet-4",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Claude Sonnet 4 (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "claude-sonnet-4",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# DeepSeek V3.2 (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "deepseek",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# DeepSeek V3.2 (stream)
curl -sS -N -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "deepseek",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0,
    "stream": true
  }'
echo

# Ministral 3 8B (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "ministral-8b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Gemma 3 12B IT (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "gemma-3-12b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Qwen3 32B (marketplace)
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "qwen3-32b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo

# Ministral 3 3B / 14B + Gemma 3 4B / 27B (marketplace)
for MODEL in ministral-3b ministral-14b gemma-3-4b gemma-3-27b; do
  echo "=== ${MODEL} ==="
  curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
    -d "{
      \"model\": \"${MODEL}\",
      \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in one short sentence.\"}],
      \"max_tokens\": 64,
      \"temperature\": 0
    }" | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
  echo
done

------------------------------------ not available yet--------------------------------------------------------

# Claude Sonnet 5 (marketplace) — needs Anthropic use-case form
curl -sS -X POST "${FUNCTION_URL}v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY}" \
  -d '{
    "model": "claude-sonnet-5",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 64,
    "temperature": 0
  }' | jq '{error, detail, model, answer: .choices[0].message.content, usage}'
echo