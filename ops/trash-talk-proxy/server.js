// Minimal authenticated proxy in front of local Ollama. Exposed publicly
// via Tailscale Funnel (generate-trash-talk in Supabase needs to reach a
// machine outside the tailnet), so this deliberately does NOT forward to
// Ollama's raw API — only POST /api/chat, and only with a valid bearer
// token. Everything else (model management, pulls, deletes) stays
// unreachable from the internet.
//
// Uses Ollama's native /api/chat rather than the OpenAI-compatible path
// because only the native endpoint supports "think": false — required to
// stop this model's reasoning mode, which otherwise never converges.
const http = require("node:http");

const PORT = process.env.PROXY_PORT || 8787;
const TOKEN = process.env.PROXY_TOKEN;
const OLLAMA_URL = "http://127.0.0.1:11434/api/chat";

if (!TOKEN) {
  console.error("PROXY_TOKEN is required");
  process.exit(1);
}

const server = http.createServer(async (req, res) => {
  if (req.method !== "POST" || req.url !== "/api/chat") {
    res.writeHead(404).end();
    return;
  }

  const auth = req.headers["authorization"];
  if (auth !== `Bearer ${TOKEN}`) {
    res.writeHead(401).end();
    return;
  }

  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);

  try {
    const upstream = await fetch(OLLAMA_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(30000),
    });
    const text = await upstream.text();
    res.writeHead(upstream.status, { "Content-Type": "application/json" });
    res.end(text);
  } catch (err) {
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "upstream unreachable" }));
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`trash-talk-proxy listening on 127.0.0.1:${PORT}`);
});
