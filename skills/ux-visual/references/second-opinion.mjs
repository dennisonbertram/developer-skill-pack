#!/usr/bin/env node
// Second opinions from frontier models of different architectures (via OpenRouter):
//   Meta MUSE Wonder (meta/muse-wonder) and Google Gemini 4 Argon (google/gemini-4-argon),
// both at maximum reasoning effort ("full"). Sends screenshots + a text brief, returns each
// model's critique. Requires OPENROUTER_API_KEY in the environment (never printed).
//
// Usage:
//   node second-opinion.mjs --mode inspect --brief brief.md --out out.json shot1.png shot2.png ...
//   node second-opinion.mjs --mode judge   --brief decision-input.md --out out.json [mock.png ...]
// Options: --models meta/muse-wonder,google/gemini-4-argon  --effort high  --max-images 8
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args.splice(i, 2)[1] : d; };
const mode = opt('mode', 'inspect');
const briefPath = opt('brief');
const outPath = opt('out');
const models = opt('models', 'meta/muse-wonder,google/gemini-4-argon').split(',');
const effort = opt('effort', 'high'); // highest effort OpenRouter exposes for these models = "full" reasoning
const maxImages = Number(opt('max-images', '8'));
const images = args.filter((a) => /\.(png|jpe?g|webp)$/i.test(a)).slice(0, maxImages);
const key = process.env.OPENROUTER_API_KEY;
if (!key) { console.error('OPENROUTER_API_KEY is not set'); process.exit(2); }
if (!briefPath) { console.error('--brief is required'); process.exit(2); }
const brief = fs.readFileSync(briefPath, 'utf8');

const SYSTEM = {
  inspect: `You are a world-class product designer reviewing screenshots of a web app with zero tolerance for anything less than excellent UI/UX. Evaluate recursively: each component, each group of components, the page, and the overall layout. Judge logic, industry standards and category conventions, usability for a first-time user, functionality implied by the UI, ease of use, clarity, visual hierarchy, density and whitespace, alignment and spacing consistency, and whether app surfaces fit on one screen. Cite the screenshot (by its file name) and the exact element for every finding. If something is excellent, say so. Do not invent elements you cannot see. Return JSON: {"verdict": string, "findings": [{"level": "component|group|page|layout", "element": string, "problem": string, "norm": string, "severity": "P0|P1|P2|P3", "screenshot": string, "fix": string}], "excellent": [string]}`,
  judge: `You are a world-class product designer acting as an independent judge. You receive a design problem with acceptance criteria and several proposed solutions (and possibly mock screenshots). Score each proposal 1-5 on: meets acceptance criteria, simplicity, consistency, usability, visual quality, effort/risk. Pick the best, suggest at most one graft from a runner-up, and defend the choice concretely against each alternative. Return JSON: {"scores": {"<option>": {"criteria": number, "simplicity": number, "consistency": number, "usability": number, "visual": number, "effort": number}}, "winner": string, "graft": string|null, "defense": string}`,
};

const content = [{ type: 'text', text: brief + (images.length ? `\n\nScreenshots attached in order: ${images.map((p) => path.basename(p)).join(', ')}` : '') }];
for (const p of images) {
  const ext = path.extname(p).slice(1).toLowerCase().replace('jpg', 'jpeg');
  content.push({ type: 'image_url', image_url: { url: `data:image/${ext};base64,${fs.readFileSync(p).toString('base64')}` } });
}

async function ask(model) {
  const t0 = Date.now();
  const body = {
    model,
    messages: [{ role: 'system', content: SYSTEM[mode] }, { role: 'user', content }],
    reasoning: { effort },
    max_tokens: 16000,
    response_format: { type: 'json_object' },
  };
  for (let attempt = 1; attempt <= 3; attempt++) {
    const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', 'X-Title': 'ux-visual second opinion' },
      body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j.choices?.[0]?.message?.content) {
      const text = j.choices[0].message.content;
      let parsed = null;
      try { parsed = JSON.parse(text.replace(/^```(json)?\s*|\s*```$/g, '')); } catch {}
      return { model, ok: true, seconds: Math.round((Date.now() - t0) / 1000), costUsd: j.usage?.cost ?? null, result: parsed ?? text };
    }
    if (attempt === 3 || (r.status && r.status < 500 && r.status !== 429)) {
      return { model, ok: false, status: r.status, error: j.error?.message ?? 'empty response' };
    }
    await new Promise((s) => setTimeout(s, 2000 * attempt));
  }
}

const results = await Promise.all(models.map(ask));
const out = { mode, images: images.map((p) => path.basename(p)), results };
if (outPath) fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
console.log(JSON.stringify(results.map((r) => ({ model: r.model, ok: r.ok, seconds: r.seconds, costUsd: r.costUsd, findings: r.result?.findings?.length, winner: r.result?.winner, error: r.error }))));
