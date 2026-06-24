import { fetchWithRetry, jsonResponse, log } from './http.js';

const FDC_SEARCH_URL = 'https://api.nal.usda.gov/fdc/v1/foods/search';

const FDC_NUTRIENT_IDS = { calories: 1008, protein: 1003, carbs: 1005, fat: 1004 };

function fdcNutrient(foodNutrients, id) {
  const n = (foodNutrients ?? []).find((x) => x.nutrientId === id);
  return n && typeof n.value === 'number' ? n.value : null;
}

// FDC search returns nutrient amounts per 100 g/mL. For Branded foods with a gram
// or mL serving size we scale to one serving so the prefilled macros match the
// portion shown; otherwise we report the per-100 g basis.
export function mapFdcFood(food) {
  const fn = food.foodNutrients;
  let calories = fdcNutrient(fn, FDC_NUTRIENT_IDS.calories);
  let protein = fdcNutrient(fn, FDC_NUTRIENT_IDS.protein);
  let carbs = fdcNutrient(fn, FDC_NUTRIENT_IDS.carbs);
  let fat = fdcNutrient(fn, FDC_NUTRIENT_IDS.fat);

  let portion = '100 g';
  const unit = food.servingSizeUnit ? String(food.servingSizeUnit).toLowerCase() : null;
  if (food.dataType === 'Branded' && food.servingSize && (unit === 'g' || unit === 'ml')) {
    const factor = food.servingSize / 100;
    const scale = (v) => (v == null ? null : Math.round(v * factor));
    calories = scale(calories);
    protein = scale(protein);
    carbs = scale(carbs);
    fat = scale(fat);
    portion = `${food.servingSize} ${food.servingSizeUnit}`;
  } else {
    const round = (v) => (v == null ? null : Math.round(v));
    calories = round(calories);
    protein = round(protein);
    carbs = round(carbs);
    fat = round(fat);
  }

  const brand = food.brandName || food.brandOwner;
  const description = (food.description ?? '').trim();
  const name = brand ? `${description} (${brand})` : description;

  return { name, portion, calories, protein, carbs, fat };
}

// FDC's default search is OR-token matching, so "tuna sushi" surfaces "tuna
// salad" and "tuna sub" (they contain "tuna"). Prefixing each token with `+`
// invokes FDC's require-all-words operator, dropping partial matches. Tokens are
// sanitized so user punctuation can't inject stray operators.
export function buildFdcQuery(raw) {
  const tokens = raw
    .split(/\s+/)
    .map((t) => t.replace(/[+"-]/g, '').trim())
    .filter(Boolean);
  if (tokens.length === 0) return raw.trim();
  return tokens.map((t) => `+${t}`).join(' ');
}

// Re-rank the FDC page so the cleanest, most on-target names float to the top:
// exact-phrase hits first, then full token coverage, then shorter (less noisy)
// descriptions. FDC's own relevance is a reasonable final tiebreak (stable sort).
export function rankFoods(foods, raw) {
  const phrase = raw.trim().toLowerCase();
  const tokens = phrase.split(/\s+/).filter(Boolean);
  const score = (f) => {
    const name = f.name.toLowerCase();
    const coverage = tokens.filter((t) => name.includes(t)).length;
    const hasPhrase = tokens.length > 1 && name.includes(phrase) ? 1 : 0;
    return { hasPhrase, coverage };
  };
  return foods
    .map((f, i) => ({ f, i, s: score(f) }))
    .sort((a, b) => {
      if (a.s.hasPhrase !== b.s.hasPhrase) return b.s.hasPhrase - a.s.hasPhrase;
      if (a.s.coverage !== b.s.coverage) return b.s.coverage - a.s.coverage;
      if (a.f.name.length !== b.f.name.length) return a.f.name.length - b.f.name.length;
      return a.i - b.i;
    })
    .map((x) => x.f);
}

export async function handleFoodSearch(query, env, startMs) {
  if (!env.FDC_API_KEY) {
    log('err', { task: 'food_search', reason: 'no_fdc_key', durationMs: Date.now() - startMs });
    return jsonResponse({ error: 'Food database not configured' }, 500);
  }

  const res = await fetchWithRetry(`${FDC_SEARCH_URL}?api_key=${env.FDC_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: buildFdcQuery(query),
      pageSize: 25,
      dataType: ['Foundation', 'SR Legacy', 'Branded'],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    log('err', {
      task: 'food_search',
      reason: 'fdc_error',
      fdcStatus: res.status,
      durationMs: Date.now() - startMs,
    });
    return jsonResponse({ error: err }, res.status);
  }

  const data = await res.json();
  // Drop entries with a name but no calorie data — some branded FDC rows omit the
  // energy nutrient in the search payload and are useless as a one-tap prefill.
  const foods = rankFoods(
    (data.foods ?? []).map(mapFdcFood).filter((f) => f.name && f.calories != null),
    query,
  );

  log('res', { task: 'food_search', outputLen: foods.length, durationMs: Date.now() - startMs });
  return jsonResponse({ foods });
}
