// Layout & density audit — run via: agent-browser --session {S} eval "$(cat layout-audit.js)"
// (or Playwright: page.evaluate(fs.readFileSync(path,'utf8'))). Returns JSON.
// Measures what eyes misjudge: viewport fit, scroll containers, dead space,
// spacing-scale drift, alignment, type scale, small targets, low contrast.
(() => {
  const vw = innerWidth, vh = innerHeight;
  const vis = (e) => {
    const r = e.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    const cs = getComputedStyle(e);
    return cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity !== 0;
  };
  const sig = (e) => {
    let s = e.tagName.toLowerCase();
    if (e.id) s += '#' + e.id;
    else if (typeof e.className === 'string' && e.className.trim())
      s += '.' + e.className.trim().split(/\s+/).slice(0, 2).join('.');
    const t = (e.getAttribute('aria-label') || e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30);
    return t ? `${s} "${t}"` : s;
  };
  const all = [...document.querySelectorAll('body *')].filter(vis);
  const se = document.scrollingElement || document.documentElement;

  // 1. Viewport fit (L1/L2/L6)
  const viewport = {
    width: vw, height: vh,
    pageScrollY: Math.max(0, se.scrollHeight - vh),
    pageScrollX: Math.max(0, se.scrollWidth - vw),
  };

  // Primary actions outside the viewport (L2): high-emphasis buttons, submit buttons
  const primaries = all.filter((e) =>
    (e.matches('button[type=submit], [data-primary], .hc-button--primary, [class*="--primary"]') && e.matches('button, a, [role=button]')));
  const offscreenPrimary = primaries
    .map((e) => ({ el: sig(e), r: e.getBoundingClientRect() }))
    .filter(({ r }) => r.bottom > vh + 1 || r.right > vw + 1 || r.top < 0)
    .map(({ el, r }) => ({ el, top: Math.round(r.top), bottom: Math.round(r.bottom) }));

  // 2. Scroll containers (L1/L3): which regions scroll and how much
  const scrollers = all
    .filter((e) => {
      const cs = getComputedStyle(e);
      return /(auto|scroll)/.test(cs.overflowY) && e.scrollHeight > e.clientHeight + 1;
    })
    .slice(0, 20)
    .map((e) => ({ el: sig(e), clientH: e.clientHeight, scrollH: e.scrollHeight }));

  // 3. Dead space (D2): large visible blocks whose area is mostly empty
  const deadSpace = [];
  for (const e of all) {
    const r = e.getBoundingClientRect();
    const area = r.width * r.height;
    if (area < vw * vh * 0.08 || r.width < 200 || r.height < 120) continue;
    const kids = [...e.querySelectorAll('*')].filter(vis);
    if (kids.length > 400) continue;
    // union area of leaf content boxes (text/media/controls), clipped to e
    let covered = 0;
    for (const k of kids) {
      if (k.children.length && !k.matches('button, a, input, textarea, select, img, svg, video, canvas, iframe')) continue;
      const kr = k.getBoundingClientRect();
      const w = Math.max(0, Math.min(kr.right, r.right) - Math.max(kr.left, r.left));
      const h = Math.max(0, Math.min(kr.bottom, r.bottom) - Math.max(kr.top, r.top));
      covered += w * h;
    }
    const fill = Math.min(1, covered / area);
    if (fill < 0.12) deadSpace.push({ el: sig(e), w: Math.round(r.width), h: Math.round(r.height), fillPct: Math.round(fill * 100), pctOfViewport: Math.round((area / (vw * vh)) * 100) });
  }
  deadSpace.sort((a, b) => b.pctOfViewport - a.pctOfViewport);

  // 4. Spacing scale drift (D3): gaps/paddings/margins observed
  const spacing = {};
  for (const e of all.slice(0, 3000)) {
    const cs = getComputedStyle(e);
    for (const p of ['paddingTop', 'paddingLeft', 'marginTop', 'rowGap', 'columnGap']) {
      const v = parseFloat(cs[p]);
      if (v > 0 && v < 200) spacing[Math.round(v)] = (spacing[Math.round(v)] || 0) + 1;
    }
  }
  const values = Object.keys(spacing).map(Number).sort((a, b) => a - b);
  const offScale = values.filter((v) => v % 4 !== 0 && v > 2);
  const nearDupes = values.filter((v, i) => i && v - values[i - 1] <= 2 && v > 4).map((v, i) => [values[values.indexOf(v) - 1], v]);

  // 5. Type scale (H3)
  const sizes = {};
  for (const e of all) {
    if (![...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
    const cs = getComputedStyle(e);
    const key = `${Math.round(parseFloat(cs.fontSize))}px/${cs.fontWeight}`;
    sizes[key] = (sizes[key] || 0) + 1;
  }
  const distinctFontSizes = [...new Set(Object.keys(sizes).map((k) => k.split('/')[0]))];

  // 6. Left-edge alignment within regions (L4/H6): near-miss left edges
  const edges = all.filter((e) => e.matches('h1,h2,h3,h4,p,label,button,input,section,article,header')).map((e) => Math.round(e.getBoundingClientRect().left));
  const edgeCounts = {}; edges.forEach((x) => (edgeCounts[x] = (edgeCounts[x] || 0) + 1));
  const edgeVals = Object.keys(edgeCounts).map(Number).sort((a, b) => a - b);
  const nearMissEdges = edgeVals.filter((x, i) => i && x - edgeVals[i - 1] > 0 && x - edgeVals[i - 1] <= 3).map((x) => [edgeVals[edgeVals.indexOf(x) - 1], x]);

  // 7. Small targets (I4)
  const smallTargets = all
    .filter((e) => e.matches('button, a[href], [role=button], input:not([type=hidden]), select, [tabindex]:not([tabindex="-1"])'))
    .map((e) => ({ el: sig(e), r: e.getBoundingClientRect() }))
    .filter(({ r }) => r.width < 24 || r.height < 24)
    .slice(0, 30)
    .map(({ el, r }) => ({ el, w: Math.round(r.width), h: Math.round(r.height) }));

  // 8. Low contrast text (A1), approximate: walk up to the first opaque background
  const rgb = (s) => (s.match(/[\d.]+/g) || []).map(Number);
  const lum = ([r, g, b]) => { const f = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
  const bgOf = (e) => { for (let n = e; n; n = n.parentElement) { const c = rgb(getComputedStyle(n).backgroundColor); if (c.length >= 3 && (c[3] === undefined || c[3] > 0.9)) return c; } return [255, 255, 255]; };
  const lowContrast = [];
  for (const e of all) {
    if (![...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
    const cs = getComputedStyle(e);
    const fg = rgb(cs.color); if (fg.length < 3) continue;
    const L1 = lum(fg), L2 = lum(bgOf(e));
    const ratio = (Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05);
    const large = parseFloat(cs.fontSize) >= 24 || (parseFloat(cs.fontSize) >= 18.66 && +cs.fontWeight >= 700);
    if (ratio < (large ? 3 : 4.5)) lowContrast.push({ el: sig(e), ratio: +ratio.toFixed(2) });
    if (lowContrast.length >= 30) break;
  }

  // 9. Overlaps between interactive elements (I1/L5)
  const inter = all.filter((e) => e.matches('button, a[href], input, textarea, select, [role=button]')).slice(0, 300).map((e) => ({ e, r: e.getBoundingClientRect() }));
  const overlaps = [];
  for (let i = 0; i < inter.length && overlaps.length < 20; i++)
    for (let j = i + 1; j < inter.length; j++) {
      const a = inter[i], b = inter[j];
      if (a.e.contains(b.e) || b.e.contains(a.e)) continue;
      const w = Math.min(a.r.right, b.r.right) - Math.max(a.r.left, b.r.left);
      const h = Math.min(a.r.bottom, b.r.bottom) - Math.max(a.r.top, b.r.top);
      if (w > 4 && h > 4) { overlaps.push({ a: sig(a.e), b: sig(b.e), w: Math.round(w), h: Math.round(h) }); break; }
    }

  // 10. Fixed/sticky overlays that may cover content (e.g. third-party badges)
  const fixedOverlays = all.filter((e) => /fixed|sticky/.test(getComputedStyle(e).position)).slice(0, 15).map((e) => { const r = e.getBoundingClientRect(); return { el: sig(e), x: Math.round(r.left), y: Math.round(r.top), w: Math.round(r.width), h: Math.round(r.height) }; });

  return JSON.stringify({
    viewport, offscreenPrimary, scrollers, deadSpace: deadSpace.slice(0, 10),
    spacing: { observed: values, offScale, nearDupes: nearDupes.slice(0, 10) },
    type: { distinctFontSizes, sizes },
    alignment: { nearMissEdges: nearMissEdges.slice(0, 15) },
    smallTargets, lowContrast, overlaps, fixedOverlays,
  }, null, 1);
})();
