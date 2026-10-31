// Visual annotations for walkthrough recordings (Playwright).
// Draws a highlight ring around the element the narration is about, with a short caption,
// so viewers can see exactly what is being discussed. The overlay is plain DOM injected
// into the page, so it is captured by recordVideo and by screenshots.
//
//   import { annotate, clearAnnotations } from "./annotate.mjs";
//   await annotate(page, page.getByText("Payroll (paused)").locator(".."), "No warning");
//   await page.waitForTimeout(2500);   // hold so it can be read
//   await clearAnnotations(page);
//
// Options: { color: "#f43f5e", position: "top" | "bottom" | "left" | "right", pad: 8 }

const ID = "ux-annotations";

export async function annotate(page, locator, caption = "", options = {}) {
  const box = await locator.first().boundingBox();
  if (!box) return false;
  await page.evaluate(
    ({ box, caption, color, position, pad, id }) => {
      let layer = document.getElementById(id);
      if (!layer) {
        layer = document.createElement("div");
        layer.id = id;
        Object.assign(layer.style, {
          position: "fixed", inset: "0", pointerEvents: "none", zIndex: "2147483647",
        });
        document.body.appendChild(layer);
      }
      const ring = document.createElement("div");
      Object.assign(ring.style, {
        position: "fixed",
        left: `${box.x - pad}px`, top: `${box.y - pad}px`,
        width: `${box.width + pad * 2}px`, height: `${box.height + pad * 2}px`,
        border: `4px solid ${color}`, borderRadius: "12px",
        boxShadow: `0 0 0 9999px rgba(0,0,0,0.35)`,
        transition: "opacity 200ms", opacity: "0",
      });
      layer.appendChild(ring);
      if (caption) {
        const tag = document.createElement("div");
        tag.textContent = caption;
        Object.assign(tag.style, {
          position: "fixed", background: color, color: "#fff",
          font: "600 22px/1.25 -apple-system, system-ui, sans-serif",
          padding: "8px 14px", borderRadius: "10px", maxWidth: "420px",
          boxShadow: "0 6px 20px rgba(0,0,0,0.3)", opacity: "0", transition: "opacity 200ms",
        });
        layer.appendChild(tag);
        const r = tag.getBoundingClientRect();
        const gap = pad + 12;
        const spots = {
          top: [box.x, box.y - gap - r.height],
          bottom: [box.x, box.y + box.height + gap],
          left: [box.x - gap - r.width, box.y],
          right: [box.x + box.width + gap, box.y],
        };
        let [x, y] = spots[position] ?? spots.top;
        if (y < 8) [x, y] = spots.bottom; // no room above: go below
        x = Math.max(8, Math.min(x, innerWidth - r.width - 8));
        y = Math.max(8, Math.min(y, innerHeight - r.height - 8));
        Object.assign(tag.style, { left: `${x}px`, top: `${y}px` });
        requestAnimationFrame(() => (tag.style.opacity = "1"));
      }
      requestAnimationFrame(() => (ring.style.opacity = "1"));
    },
    {
      box, caption, id: ID,
      color: options.color ?? "#f43f5e",
      position: options.position ?? "top",
      pad: options.pad ?? 8,
    },
  );
  return true;
}

export async function clearAnnotations(page) {
  await page.evaluate((id) => document.getElementById(id)?.remove(), ID);
}
