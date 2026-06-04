#!/usr/bin/env node
// .claude/hooks/test-health.js
//
// SessionStart hook — emits current test health into context so the agent
// starts informed instead of blind. Reads the latest entry per layer from
// reports/history.jsonl and prints a compact pass-rate + violation summary.
//
// Read-only. Never blocks. Silent if no history exists.

const fs = require('fs');
const path = require('path');

const HISTORY = path.join(__dirname, '..', '..', 'reports', 'history.jsonl');

let lines;
try {
  lines = fs.readFileSync(HISTORY, 'utf8').split(/\r?\n/);
} catch {
  process.exit(0); // no history yet — say nothing
}

// Keep the last entry seen per layer (file is append-ordered).
const latest = {};
for (const line of lines) {
  if (!line.trim()) continue;
  let e;
  try { e = JSON.parse(line); } catch { continue; }
  if (e && e.layer) latest[e.layer] = e;
}

const layers = Object.keys(latest);
if (layers.length === 0) process.exit(0);

const order = ['unit', 'ai', 'integration', 'e2e'];
layers.sort((a, b) => {
  const ia = order.indexOf(a), ib = order.indexOf(b);
  return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
});

const rows = [];
let anyRed = false;

for (const l of layers) {
  const e = latest[l];
  const s = e.summary || {};
  const rate = typeof e.passRate === 'number' ? e.passRate : (s.passRate || 0);
  const pct = (rate * 100).toFixed(0);

  // Sum violations across generative metric buckets.
  let viol = 0;
  const gm = e.generativeMetrics || {};
  for (const k of Object.keys(gm)) {
    if (gm[k] && typeof gm[k].violations === 'number') viol += gm[k].violations;
  }

  const failed = s.failed || 0;
  const flag = (rate < 1 || viol > 0) ? ' ⚠' : '';
  if (flag) anyRed = true;

  const when = e.timestamp ? e.timestamp.slice(0, 10) : '?';
  rows.push(
    `  ${l.padEnd(11)} ${pct}%  ${s.passed || 0}/${s.total || 0}` +
    (failed ? `  ${failed} failed` : '') +
    (viol ? `  ${viol} violations` : '') +
    `  (${when})${flag}`
  );
}

const header = anyRed
  ? '[test-health] Last recorded test run — NEEDS ATTENTION:'
  : '[test-health] Last recorded test run — all green:';

process.stdout.write(header + '\n' + rows.join('\n') + '\n');
process.exit(0);
