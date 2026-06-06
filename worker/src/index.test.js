import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import worker from './index.js';

// ── helpers ────────────────────────────────────────────────────────────────

function makeRequest(method, body = null, headers = {}) {
  const init = {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
  };
  if (body !== null) {
    init.body = JSON.stringify(body);
  }
  return new Request('https://worker.example.com/', init);
}

const ENV = {
  GEMINI_API_KEY: 'free-key',
  GEMINI_API_KEY_PAID: 'paid-key',
  TEST_AUTH_TOKEN: 'secret-token',
};

const ENV_NO_AUTH = {
  GEMINI_API_KEY: 'free-key',
  GEMINI_API_KEY_PAID: 'paid-key',
  TEST_AUTH_TOKEN: undefined,
};

function stubGeminiFetch(responseText, ok = true, status = 200) {
  return vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok,
      status,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: responseText }] } }],
      }),
      text: async () => responseText,
    }),
  );
}

// ── CORS preflight ─────────────────────────────────────────────────────────

describe('[DIR] CORS preflight', () => {
  test('OPTIONS returns 200 with CORS headers', async () => {
    const res = await worker.fetch(makeRequest('OPTIONS'), ENV);
    expect(res.status).toBe(200);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(res.headers.get('Access-Control-Allow-Methods')).toBe('POST');
  });

  test('OPTIONS does not call Gemini', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    await worker.fetch(makeRequest('OPTIONS'), ENV);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

// ── Method guard ───────────────────────────────────────────────────────────

describe('[BVA] Method guard', () => {
  test('GET returns 405 with body', async () => {
    const res = await worker.fetch(makeRequest('GET'), ENV);
    expect(res.status).toBe(405);
    expect(await res.text()).toBe('Method not allowed');
  });

  test('PUT returns 405', async () => {
    const res = await worker.fetch(makeRequest('PUT', {}), ENV);
    expect(res.status).toBe(405);
  });

  test('POST is allowed (does not return 405)', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).not.toBe(405);
  });
});

// ── Unknown task guard ─────────────────────────────────────────────────────

describe('[BVA] Unknown task guard', () => {
  test('unknown task returns 400', async () => {
    const res = await worker.fetch(
      makeRequest('POST', { task: 'nonexistent_task', text: 'eggs' }),
      ENV,
    );
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toMatch(/Unknown task/);
    expect(body.error).toContain('nonexistent_task');
  });

  test('missing task field also returns 400', async () => {
    const res = await worker.fetch(
      makeRequest('POST', { text: 'eggs' }),
      ENV,
    );
    expect(res.status).toBe(400);
  });

  test('known task parse_meal does not return 400 for unknown-task reason', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).not.toBe(400);
  });
});

// ── No-input guard ─────────────────────────────────────────────────────────

describe('[BVA] No-input guard', () => {
  test('no text and no image returns 400', async () => {
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal' }),
      ENV,
    );
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toMatch(/text or image/i);
  });

  test('empty string text (falsy) treated as no input → 400', async () => {
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: '' }),
      ENV,
    );
    expect(res.status).toBe(400);
  });

  test('text present passes input guard', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).not.toBe(400);
  });

  test('image present passes input guard even without text', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', {
        task: 'parse_meal',
        image: { data: 'base64data', mimeType: 'image/jpeg' },
      }),
      ENV,
    );
    expect(res.status).not.toBe(400);
  });
});

// ── Gemini error passthrough ───────────────────────────────────────────────

describe('[INV] Gemini error passthrough', () => {
  test('Gemini 500 → response status 500', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        text: async () => 'Internal server error',
      }),
    );
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).toBe(500);
  });

  test('Gemini 429 → response status 429', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 429,
        text: async () => 'Rate limited',
      }),
    );
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).toBe(429);
  });

  test('Gemini error response includes CORS header', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 503,
        text: async () => 'unavailable',
      }),
    );
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('*');
  });

  test('Gemini ok=true does not return error status', async () => {
    stubGeminiFetch('{"title":"test","foods":[]}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.status).toBe(200);
  });
});

// ── Happy path ─────────────────────────────────────────────────────────────

describe('[DIR] Happy path', () => {
  test('parse_meal returns 200 with JSON body', async () => {
    stubGeminiFetch('{"title":"Eggs","foods":[]}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'scrambled eggs' }),
      ENV,
    );
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toBe('{"title":"Eggs","foods":[]}');
  });

  test('parse_medication returns 200', async () => {
    stubGeminiFetch('{"name":"Aspirin","dose":100}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_medication', text: 'aspirin 100mg' }),
      ENV,
    );
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toBe('{"name":"Aspirin","dose":100}');
  });

  test('response includes CORS header on success', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('*');
  });

  test('content-type is application/json on success', async () => {
    stubGeminiFetch('{}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });
});

// ── Markdown fence stripping ───────────────────────────────────────────────

describe('[EQUIV] Markdown fence stripping', () => {
  test('strips ```json and ``` from Gemini response', async () => {
    stubGeminiFetch('```json\n{"title":"test"}\n```');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    const text = await res.text();
    expect(text).toBe('{"title":"test"}');
  });

  test('strips bare ``` fences', async () => {
    stubGeminiFetch('```\n{"title":"test"}\n```');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    const text = await res.text();
    expect(text).toBe('{"title":"test"}');
  });

  test('plain JSON passthrough unchanged', async () => {
    stubGeminiFetch('{"title":"plain"}');
    const res = await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );
    const text = await res.text();
    expect(text).toBe('{"title":"plain"}');
  });
});

// ── Auth / API key selection ───────────────────────────────────────────────

describe('[DIR] API key selection', () => {
  test('no auth header uses free key', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );

    const calledHeaders = fetchSpy.mock.calls[0][1].headers;
    expect(calledHeaders['x-goog-api-key']).toBe('free-key');
  });

  test('valid bearer token uses paid key', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }, { Authorization: 'Bearer secret-token' }),
      ENV,
    );

    const calledHeaders = fetchSpy.mock.calls[0][1].headers;
    expect(calledHeaders['x-goog-api-key']).toBe('paid-key');
  });

  test('wrong bearer token uses free key', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }, { Authorization: 'Bearer wrong-token' }),
      ENV,
    );

    const calledHeaders = fetchSpy.mock.calls[0][1].headers;
    expect(calledHeaders['x-goog-api-key']).toBe('free-key');
  });

  test('no TEST_AUTH_TOKEN in env → always uses free key even with header', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }, { Authorization: 'Bearer secret-token' }),
      ENV_NO_AUTH,
    );

    const calledHeaders = fetchSpy.mock.calls[0][1].headers;
    expect(calledHeaders['x-goog-api-key']).toBe('free-key');
  });
});

// ── mealType injection ─────────────────────────────────────────────────────

describe('[DIR] mealType injection', () => {
  test('mealType prepended to text in Gemini request', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs', mealType: 'Breakfast' }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const textPart = body.contents[0].parts.find((p) => p.text !== undefined);
    expect(textPart.text).toBe('Meal type: Breakfast\neggs');
  });

  test('no mealType → text sent without prefix', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const textPart = body.contents[0].parts.find((p) => p.text !== undefined);
    expect(textPart.text).toBe('eggs');
  });

  test('mealType with no text still sends mealType line', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', {
        task: 'parse_meal',
        mealType: 'Dinner',
        image: { data: 'abc', mimeType: 'image/jpeg' },
      }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const textPart = body.contents[0].parts.find((p) => p.text !== undefined);
    expect(textPart.text).toBe('Meal type: Dinner');
  });
});

// ── Image part construction ────────────────────────────────────────────────

describe('[DIR] Image part construction', () => {
  test('image added as first part with inlineData', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', {
        task: 'parse_meal',
        text: 'eggs',
        image: { data: 'base64abc', mimeType: 'image/png' },
      }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const parts = body.contents[0].parts;
    expect(parts[0]).toEqual({ inlineData: { data: 'base64abc', mimeType: 'image/png' } });
  });

  test('image without mimeType defaults to image/jpeg', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', {
        task: 'parse_meal',
        text: 'eggs',
        image: { data: 'base64abc' },
      }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const imagePart = body.contents[0].parts[0];
    expect(imagePart.inlineData.mimeType).toBe('image/jpeg');
  });

  test('no image → no inlineData part in Gemini request', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    const parts = body.contents[0].parts;
    const hasInlineData = parts.some((p) => p.inlineData !== undefined);
    expect(hasInlineData).toBe(false);
  });
});

// ── System prompt forwarding ───────────────────────────────────────────────

describe('[INV] System prompt forwarding', () => {
  test('parse_meal system prompt sent to Gemini', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_meal', text: 'eggs' }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    expect(body.system_instruction.parts[0].text).toContain('meal-logging assistant');
  });

  test('parse_medication system prompt differs from parse_meal', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
    vi.stubGlobal('fetch', fetchSpy);

    await worker.fetch(
      makeRequest('POST', { task: 'parse_medication', text: 'aspirin' }),
      ENV,
    );

    const body = JSON.parse(fetchSpy.mock.calls[0][1].body);
    expect(body.system_instruction.parts[0].text).toContain('medication-logging assistant');
    expect(body.system_instruction.parts[0].text).not.toContain('meal-logging assistant');
  });
});

// ── Gemini request shape ───────────────────────────────────────────────────

describe('[INV] Gemini request shape', () => {
  function geminiSpy() {
    return vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
    });
  }

  test('calls the correct Gemini URL', async () => {
    const spy = geminiSpy();
    vi.stubGlobal('fetch', spy);
    await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(spy.mock.calls[0][0]).toContain('generativelanguage.googleapis.com');
    expect(spy.mock.calls[0][0]).toContain('gemini-flash-latest');
  });

  test('calls Gemini with method POST', async () => {
    const spy = geminiSpy();
    vi.stubGlobal('fetch', spy);
    await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(spy.mock.calls[0][1].method).toBe('POST');
  });

  test('sends Content-Type: application/json to Gemini', async () => {
    const spy = geminiSpy();
    vi.stubGlobal('fetch', spy);
    await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(spy.mock.calls[0][1].headers['Content-Type']).toBe('application/json');
  });
});

// ── CORS Allow-Headers ─────────────────────────────────────────────────────

describe('[INV] CORS Allow-Headers', () => {
  test('OPTIONS returns Access-Control-Allow-Headers: Content-Type', async () => {
    const res = await worker.fetch(makeRequest('OPTIONS'), ENV);
    expect(res.headers.get('Access-Control-Allow-Headers')).toBe('Content-Type');
  });
});

// ── Error response bodies ──────────────────────────────────────────────────

describe('[INV] Error response bodies', () => {
  test('unknown task 400 body has error field', async () => {
    const res = await worker.fetch(makeRequest('POST', { task: 'nope', text: 'x' }), ENV);
    const body = await res.json();
    expect(body.error).toBeDefined();
    expect(body.error).toContain('nope');
  });

  test('unknown task 400 has Content-Type: application/json', async () => {
    const res = await worker.fetch(makeRequest('POST', { task: 'nope', text: 'x' }), ENV);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  test('no-input 400 has Content-Type: application/json', async () => {
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal' }), ENV);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  test('Gemini error body forwarded in error field', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: false, status: 500, text: async () => 'Gemini exploded' }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    const body = await res.json();
    expect(body.error).toBe('Gemini exploded');
  });

  test('Gemini error response has Content-Type: application/json', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: false, status: 500, text: async () => 'err' }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });
});

// ── Optional-chaining fallback (missing candidates) ────────────────────────

describe('[BVA] Optional-chaining fallback', () => {
  test('empty candidates array → empty response body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [] }) }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });

  test('missing candidates key → empty response body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({}) }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });

  test('candidate with no content → empty response body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{}] }) }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });

  test('candidate with empty parts array → empty response body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ candidates: [{ content: { parts: [] } }] }),
      }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });

  test('candidate with undefined parts → empty response body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ candidates: [{ content: {} }] }),
      }),
    );
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });
});

// ── Regex edge cases ───────────────────────────────────────────────────────

describe('[EQUIV] Regex edge cases', () => {
  test('strips ```json with multiple trailing spaces/newlines', async () => {
    stubGeminiFetch('```json   \n{"x":1}\n```');
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(await res.text()).toBe('{"x":1}');
  });

  test('strips leading whitespace before closing ```', async () => {
    stubGeminiFetch('```json\n{"x":1}\n   ```');
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(await res.text()).toBe('{"x":1}');
  });

  test('strips both fences with no whitespace between tag and content', async () => {
    stubGeminiFetch('```json{"x":1}```');
    const res = await worker.fetch(makeRequest('POST', { task: 'parse_meal', text: 'eggs' }), ENV);
    expect(await res.text()).toBe('{"x":1}');
  });
});

// ── teardown ───────────────────────────────────────────────────────────────

afterEach(() => {
  vi.unstubAllGlobals();
});
