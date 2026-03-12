'use strict';

/**
 * Lightweight mock HTTP server for Groq and OpenAI API endpoints.
 *
 * Used by Playwright E2E tests so the Phoenix backend calls a local server
 * instead of the real Groq/OpenAI APIs.  Start it before the Phoenix server:
 *
 *   node e2e/support/mock-api-server.cjs
 *   PORT=4444 node e2e/support/mock-api-server.cjs  # explicit port
 *
 * Endpoints:
 *   GET  /health                          → 200 "OK"  (Playwright ready-check)
 *   POST /openai/v1/chat/completions      → SSE stream mimicking the Groq API
 *   POST /v1/embeddings                   → JSON embedding mimicking OpenAI
 */

const http = require('http');

const PORT = parseInt(process.env.PORT ?? '4444', 10);

/** Canned assistant text returned by the mock Groq endpoint. */
const MOCK_CHAT_RESPONSE =
  'Great question! Kove offers an exciting lineup for every type of rider. ' +
  'The 800X Rally is our flagship adventure bike with a 799cc parallel twin. ' +
  'The 450 Rally Pro excels off-road, while the MX450 and MX250 are ' +
  'purpose-built competition motocross machines. What would you like to know more about?';

/** 768-dimensional fake embedding vector (values follow a simple sine pattern). */
const FAKE_EMBEDDING = Array.from({ length: 768 }, (_, i) =>
  parseFloat((Math.sin(i * 0.1) * 0.01).toFixed(6))
);

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/** Resolves after `ms` milliseconds — used to pace SSE token delivery. */
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * POST /openai/v1/chat/completions
 *
 * Streams MOCK_CHAT_RESPONSE word-by-word using the same SSE format that the
 * Groq API uses.  The Phoenix Groq module's SSE parser expects:
 *
 *   data: {"choices":[{"delta":{"content":"word"},"finish_reason":null,...}]}\n\n
 *   data: [DONE]\n\n
 *
 * Each token is delayed by TOKEN_DELAY_MS so that `chat_loading = true` on the
 * LiveView is observable long enough for Playwright's polling to catch it.
 */
const TOKEN_DELAY_MS = 15;      // ~35 words × 15 ms ≈ 525 ms of streaming
const INITIAL_DELAY_MS = 3000; // silence before first token — 3 s window for Playwright to observe disabled state

async function handleChatCompletions(res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
    'Transfer-Encoding': 'chunked',
  });

  // Hold the stream open for a moment before the first token.  This gives
  // Phoenix LiveView time to flush the chat_loading=true diff to the browser
  // (making the input disabled) before any {:kovy_chunk} messages arrive.
  await delay(INITIAL_DELAY_MS);

  const words = MOCK_CHAT_RESPONSE.split(' ');
  const created = Math.floor(Date.now() / 1000);
  const model = 'llama-3.3-70b-versatile';

  for (const [idx, word] of words.entries()) {
    const content = idx === 0 ? word : ` ${word}`;
    const payload = JSON.stringify({
      id: 'chatcmpl-e2etest001',
      object: 'chat.completion.chunk',
      created,
      model,
      choices: [{ index: 0, delta: { content }, finish_reason: null }],
    });
    res.write(`data: ${payload}\n\n`);
    await delay(TOKEN_DELAY_MS);
  }

  // Final chunk signals end-of-stream
  const stopPayload = JSON.stringify({
    id: 'chatcmpl-e2etest001',
    object: 'chat.completion.chunk',
    created,
    model,
    choices: [{ index: 0, delta: {}, finish_reason: 'stop' }],
  });
  res.write(`data: ${stopPayload}\n\n`);
  res.write('data: [DONE]\n\n');
  res.end();
}

/**
 * POST /v1/embeddings
 *
 * Returns a fake 768-dim embedding so the OpenAI embeddings path does not
 * error out and the app can fall back gracefully.
 */
function handleEmbeddings(res) {
  const body = JSON.stringify({
    object: 'list',
    data: [{ object: 'embedding', index: 0, embedding: FAKE_EMBEDDING }],
    model: 'text-embedding-3-small',
    usage: { prompt_tokens: 10, total_tokens: 10 },
  });
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const server = http.createServer((req, res) => {
  // Consume the request body before responding (required for POST requests)
  let _body = '';
  req.on('data', (chunk) => {
    _body += chunk;
  });
  req.on('end', async () => {
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('OK');
    } else if (req.method === 'POST' && req.url === '/openai/v1/chat/completions') {
      await handleChatCompletions(res);
    } else if (req.method === 'POST' && req.url === '/v1/embeddings') {
      handleEmbeddings(res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end(`Not found: ${req.method} ${req.url}\n`);
    }
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[mock-api-server] Ready on http://localhost:${PORT}`);
  console.log(`  Groq   → POST /openai/v1/chat/completions`);
  console.log(`  OpenAI → POST /v1/embeddings`);
  console.log(`  Health → GET  /health`);
});

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    server.close(() => {
      console.log('[mock-api-server] Stopped');
      process.exit(0);
    });
  });
}
