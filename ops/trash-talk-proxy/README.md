# Trash-talk local LLM proxy

`generate-trash-talk` (Supabase Edge Function) calls out to a model running
locally via Ollama, reached through this proxy over a Tailscale Funnel.
Ollama's raw API is never exposed directly — only this proxy, which accepts
just `POST /api/chat` with a valid bearer token, forwarding to Ollama's
native `/api/chat` on localhost. Everything else (model management, pulls,
deletes) stays unreachable from the internet.

## Model

`huihui_ai/qwen3.5-abliterated:9b`, called with `"think": false`. This
model reasons at length by default and, in testing, sometimes never
converges to an answer — `think: false` (only supported on Ollama's native
`/api/chat`, not the OpenAI-compatible path) is required to get a fast,
complete response.

## Setup on a new machine

```bash
brew install ollama
ollama pull huihui_ai/qwen3.5-abliterated:9b

# Generate a fresh token — don't reuse one from another machine
openssl rand -hex 32 > ops/trash-talk-proxy/.token
chmod 600 ops/trash-talk-proxy/.token
chmod +x ops/trash-talk-proxy/start.sh

# Install the LaunchAgent so the proxy survives reboots/logouts
cp ops/trash-talk-proxy/com.ironline.trash-talk-proxy.plist ~/Library/LaunchAgents/
# (edit the plist first if this repo isn't at /Users/johnathonlaux/ironline)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ironline.trash-talk-proxy.plist

# Expose it publicly (Supabase's cloud can't reach your tailnet directly)
tailscale funnel --bg 8787

# Point generate-trash-talk at it
supabase secrets set LLM_API_BASE_URL="https://<your-machine>.<your-tailnet>.ts.net"
supabase secrets set LLM_MODEL="huihui_ai/qwen3.5-abliterated:9b"
supabase secrets set LLM_API_KEY="$(cat ops/trash-talk-proxy/.token)"
```

## Notes

- Cosmetic feature only — if this machine is off or the tunnel is down,
  `generate-trash-talk` returns `{ skipped: true }` rather than failing
  anything duel-related.
- To check what's running: `ollama ps`, `launchctl print gui/$(id -u)/com.ironline.trash-talk-proxy`, `tailscale funnel status`.
- To stop exposing it: `tailscale funnel --https=443 off`.
