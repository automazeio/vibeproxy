# commandcode-proxy

Rust translation shim that bridges Command Code's proprietary API to OpenAI-compatible endpoints.

## Building

```bash
cd commandcode-proxy
cargo build --release
```

Output: target/release/commandcode-proxy (~3.3MB with optimizations)

## Features

- SSE streaming with OpenAI-compatible format
- Model alias mapping (CC: prefix to actual model names)
- Retry on 429/5xx with exponential backoff
- Connection pooling and request timeout

## Source

https://github.com/themuuln/commandcode-proxy
