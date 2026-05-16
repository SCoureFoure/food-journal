import prompts from './prompts.json';

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const { task, text, image, mealType } = await request.json();

    const authHeader = request.headers.get('Authorization');
    const isPaidRequest = env.TEST_AUTH_TOKEN && authHeader === `Bearer ${env.TEST_AUTH_TOKEN}`;
    const apiKey = isPaidRequest ? env.GEMINI_API_KEY_PAID : env.GEMINI_API_KEY;

    const promptEntry = prompts[task];
    if (!promptEntry) {
      return new Response(JSON.stringify({ error: `Unknown task: ${task}` }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const parts = [];
    if (image) parts.push({ inlineData: { data: image.data, mimeType: image.mimeType ?? 'image/jpeg' } });
    const userText = [mealType ? `Meal type: ${mealType}` : null, text].filter(Boolean).join('\n');
    if (userText) parts.push({ text: userText });

    if (parts.length === 0) {
      return new Response(JSON.stringify({ error: 'Provide text or image' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const res = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: promptEntry.systemPrompt }] },
        contents: [{ parts }],
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      return new Response(JSON.stringify({ error: err }), {
        status: res.status,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const data = await res.json();
    const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    const cleaned = rawText.replace(/```json\s*/g, '').replace(/\s*```/g, '').trim();

    return new Response(cleaned, {
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  },
};
