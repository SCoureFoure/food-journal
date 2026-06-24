import { CORS_HEADERS, jsonResponse, log } from './http.js';
import { handleParse, isKnownTask } from './gemini.js';
import { handleFoodSearch } from './fdc.js';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const startMs = Date.now();

    let body;
    try {
      body = await request.json();
    } catch {
      log('err', { task: null, reason: 'bad_json', durationMs: Date.now() - startMs });
      return jsonResponse({ error: 'Invalid JSON body' }, 400);
    }

    const { task } = body;

    if (task === 'food_search') {
      const query = typeof body.query === 'string' ? body.query.trim() : '';
      if (!query) {
        log('err', { task, reason: 'no_query', durationMs: Date.now() - startMs });
        return jsonResponse({ error: 'Provide a search query' }, 400);
      }
      return handleFoodSearch(query, env, startMs);
    }

    if (!isKnownTask(task)) {
      log('err', { task, reason: 'unknown_task', durationMs: Date.now() - startMs });
      return jsonResponse({ error: `Unknown task: ${task}` }, 400);
    }

    const authHeader = request.headers.get('Authorization');
    return handleParse(task, body, authHeader, env, startMs);
  },
};
