import prompts from './prompts.json';
import { JSON_HEADERS, fetchWithRetry, jsonResponse, log } from './http.js';

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

export function isKnownTask(task) {
  return Boolean(prompts[task]);
}

export async function handleParse(task, body, authHeader, env, startMs) {
  const { text, image, mealType } = body;

  const isPaidRequest = env.TEST_AUTH_TOKEN && authHeader === `Bearer ${env.TEST_AUTH_TOKEN}`;
  const apiKey = isPaidRequest ? env.GEMINI_API_KEY_PAID : env.GEMINI_API_KEY;

  log('req', {
    task,
    hasText: Boolean(text),
    textLen: text?.length ?? 0,
    hasImage: Boolean(image),
    mealType: mealType ?? null,
    paid: isPaidRequest,
  });

  const parts = [];
  if (image) parts.push({ inlineData: { data: image.data, mimeType: image.mimeType ?? 'image/jpeg' } });
  const userText = [mealType ? `Meal type: ${mealType}` : null, text].filter(Boolean).join('\n');
  if (userText) parts.push({ text: userText });

  if (parts.length === 0) {
    log('err', { task, reason: 'no_input', durationMs: Date.now() - startMs });
    return jsonResponse({ error: 'Provide text or image' }, 400);
  }

  const res = await fetchWithRetry(GEMINI_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: prompts[task].systemPrompt }] },
      contents: [{ parts }],
      // Force valid, deterministic JSON. Without this Gemini intermittently wraps
      // output in prose ("Here's the JSON:") or markdown fences, which the app then
      // fails to parse — the main source of parse flakiness on the free tier.
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0,
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    log('err', { task, reason: 'gemini_error', geminiStatus: res.status, durationMs: Date.now() - startMs });
    return jsonResponse({ error: err }, res.status);
  }

  const data = await res.json();
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
  // Defensive: responseMimeType should yield bare JSON, but keep fence-stripping
  // for older deployments / edge responses.
  const cleaned = rawText.replace(/```json\s*/g, '').replace(/\s*```/g, '').trim();

  log('res', { task, outputLen: cleaned.length, durationMs: Date.now() - startMs });

  return new Response(cleaned, { headers: JSON_HEADERS });
}
