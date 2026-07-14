// Geometry audit — run via: agent-browser --session {S} eval "$(cat geometry-audit.js)"
// Returns JSON of measurable layout defects. Numbers beat eyeballs for evenness;
// use the screenshot to judge whether a reported violation actually matters.
(() => {
  const sig = (e) => {
    let s = e.tagName.toLowerCase();
    if (e.id) s += '#' + e.id;
    else if (typeof e.className === 'string' && e.className.trim())
      s += '.' + e.className.trim().split(/\s+/).slice(0, 2).join('.');
    const t = (e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30);
    return t ? s + ' "' + t + '"' : s;
  };
  const vis = (e) => {
    const r = e.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    const cs = getComputedStyle(e);
    return cs.visibility !== 'hidden' && cs.display !== 'none';
  };
  const firstClass = (e) =>
    typeof e.className === 'string' ? (e.className.trim().split(/\s+/)[0] || '') : '';

  const out = {
    pageOverflowX: Math.max(0, document.documentElement.scrollWidth - window.innerWidth),
    unevenRows: [],      // similar siblings in one visual row with different shapes/gaps
    overflowSpills: [],  // content escaping its container
    wrappedControls: [], // short button/tab/chip labels forced onto 2+ lines
  };

  // 1. Sibling uniformity: flex-row/grid containers whose children are structurally
  //    similar (same tag + first class) should share height, width, gap, and top edge.
  for (const p of document.querySelectorAll('body *')) {
    const cs = getComputedStyle(p);
    const flexRow = cs.display.includes('flex') && cs.flexDirection.startsWith('row');
    const grid = cs.display.includes('grid');
    if (!flexRow && !grid) continue;
    const kids = [...p.children].filter(vis);
    if (kids.length < 2 || kids.length > 16) continue;
    if (!kids.every((k) => k.tagName === kids[0].tagName && firstClass(k) === firstClass(kids[0]))) continue;
    const rects = kids.map((k) => k.getBoundingClientRect());
    const topDrift = Math.max(...rects.map((r) => r.top)) - Math.min(...rects.map((r) => r.top));
    if (topDrift > 24) continue; // wrapped onto multiple rows — not one visual row
    const hs = rects.map((r) => Math.round(r.height));
    const ws = rects.map((r) => Math.round(r.width));
    const sorted = [...rects].sort((a, b) => a.left - b.left);
    const gaps = [];
    for (let i = 1; i < sorted.length; i++) gaps.push(Math.round(sorted[i].left - sorted[i - 1].right));
    const issue = {};
    if (Math.max(...hs) - Math.min(...hs) > 8) issue.heights = hs;
    if (flexRow && Math.max(...ws) - Math.min(...ws) > 8) issue.widths = ws;
    if (gaps.length > 1 && Math.max(...gaps) - Math.min(...gaps) > 4) issue.gaps = gaps;
    if (topDrift > 3) issue.topDriftPx = Math.round(topDrift);
    if (Object.keys(issue).length)
      out.unevenRows.push({ container: sig(p), children: kids.length, ...issue });
  }

  // 2. Overflow: element content wider than its box while overflow-x is visible.
  for (const e of document.querySelectorAll('body *')) {
    if (!vis(e) || e.clientWidth < 24) continue;
    if (!getComputedStyle(e).overflowX.includes('visible')) continue;
    if (e.scrollWidth > e.clientWidth + 4)
      out.overflowSpills.push({ el: sig(e), spillPx: e.scrollWidth - e.clientWidth });
  }

  // 3. Wrapped controls: a short label on a block-ish control taking 2+ lines
  //    means the container is too narrow or the label too long for the layout.
  for (const b of document.querySelectorAll('button, [role="button"], a, summary, [class*="tab"], [class*="chip"], [class*="badge"]')) {
    if (!vis(b)) continue;
    const cs = getComputedStyle(b);
    if (cs.display === 'inline') continue; // prose links legitimately wrap
    if (b.querySelector('br, svg, img')) continue;
    const label = (b.textContent || '').trim();
    if (!label || label.length > 40) continue;
    const lh = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.4;
    const contentH = b.clientHeight - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
    if (contentH > lh * 1.8) out.wrappedControls.push(sig(b));
  }

  for (const k of ['unevenRows', 'overflowSpills', 'wrappedControls']) {
    if (out[k].length > 12) { out[k] = out[k].slice(0, 12); out[k + 'Truncated'] = true; }
  }
  return JSON.stringify(out);
})();
