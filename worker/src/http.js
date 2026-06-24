export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export const JSON_HEADERS = { 'Content-Type': 'application/json', ...CORS_HEADERS };

// Transient upstream failures. Gemini free tier returns 429 (rate limit) and 503
// (overloaded) frequently; retrying in the Worker means the app rarely sees them.
const RETRYABLE = new Set([429, 500, 502, 503, 504]);

export async function fetchWithRetry(url, init, { retries = 2, baseDelayMs = 200 } = {}) {
  let attempt = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const res = await fetch(url, init);
    if (res.ok || !RETRYABLE.has(res.status) || attempt >= retries) return res;
    attempt += 1;
    // Stryker disable next-line all
    await new Promise((resolve) => setTimeout(resolve, baseDelayMs * attempt));
  }
}

export function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: JSON_HEADERS });
}

export function log(event, fields) {
  // Stryker disable next-line all
  console.log(JSON.stringify({ event, ts: new Date().toISOString(), ...fields }));
}
