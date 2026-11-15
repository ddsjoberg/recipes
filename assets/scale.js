/*
  Recipe scaling: the ½× / 1× / 2× / 3× picker that _filters/recipe.lua adds
  at the top of the Ingredients section. Rewrites the amounts in the ingredient
  list in place; recipes need no special syntax.

  What gets scaled, per ingredient:
  * The leading amount: "2", "0.5", "1/8", "1 1/2", "1 ½", "4-6", "6 to 8",
    "26oz." (number glued to a unit).
  * Amounts in parentheses that restate the total, e.g. "1 pound (450g)" or
    "6 slices (about 6 ounces; 170g)". Parentheses that give a package size
    are left alone: right after the number ("1 (14 oz) can") or after a
    container/size word ("1 can (6oz)", "1 medium (8-ounce) onion").
  Lines without a leading amount ("Salt", "Juice of one lime") are unchanged.
  Directions are never rescaled.

  The chosen scale is kept in the URL (?scale=2) so it survives a reload and
  can be shared.
*/
(() => {
  const FRACTIONS = { "½": 1 / 2, "⅓": 1 / 3, "⅔": 2 / 3, "¼": 1 / 4, "¾": 3 / 4, "⅛": 1 / 8, "⅜": 3 / 8, "⅝": 5 / 8, "⅞": 7 / 8 };
  const UNI = "[½⅓⅔¼¾⅛⅜⅝⅞]";
  // One amount: mixed ("1 1/2", "1 ½", "1½"), fraction, decimal/integer, or a
  // lone Unicode fraction. Not preceded by a letter, digit or decimal point.
  const NUM = `(?:\\d+\\s+\\d+\\/\\d+|\\d+\\/\\d+|\\d+(?:\\.\\d+)?(?:\\s*${UNI})?|${UNI})`;
  const RANGE = `(${NUM})(?:(\\s*(?:-|–|to)\\s*)(${NUM}))?`;
  const LEADING = new RegExp(`^(\\s*)${RANGE}`);
  const ANY = new RegExp(`(?<![\\p{L}\\d.])${RANGE}`, "gu");
  const PAREN = /\(([^()]*)\)/g;

  // A parenthetical after one of these words is a package size, not a total.
  const PACKAGE_WORDS = /\b(?:cans?|box(?:es)?|jars?|packages?|pkgs?|bags?|bottles?|cartons?|containers?|small|medium|large)\s*$/i;
  // Units that read better rounded to whole numbers once they reach 10.
  const WHOLE_UNITS = /^\s*(?:g|grams?|kg|ml|mL|l|oz\.?|ounces?)\b/;
  // Unit words that should agree with the new amount (1 cup / 2 cups).
  const UNIT_WORD = /^(\s+)(cup|tablespoon|teaspoon|pound|ounce|clove|slice|stick|can|box|bunch|pint|quart|bag|jar|package|bottle|head|sprig)(s|es)?\b/i;

  const SNAP = [0, 1 / 8, 1 / 4, 1 / 3, 3 / 8, 1 / 2, 5 / 8, 2 / 3, 3 / 4, 7 / 8, 1];
  const GLYPH = { 0.125: "⅛", 0.25: "¼", 0.333: "⅓", 0.375: "⅜", 0.5: "½", 0.625: "⅝", 0.667: "⅔", 0.75: "¾", 0.875: "⅞" };

  const parse = (s) => {
    s = s.trim();
    let m;
    if ((m = s.match(/^(\d+)\s+(\d+)\/(\d+)$/))) return +m[1] + m[2] / m[3];
    if ((m = s.match(/^(\d+)\/(\d+)$/))) return m[1] / m[2];
    if ((m = s.match(new RegExp(`^(\\d+(?:\\.\\d+)?)?\\s*(${UNI})?$`)))) {
      return (m[1] ? +m[1] : 0) + (m[2] ? FRACTIONS[m[2]] : 0);
    }
    return NaN;
  };

  const trimDecimal = (v) => String(+v.toFixed(3));

  // Format a scaled amount in the style of the original.
  const format = (v, original, after) => {
    if (v >= 10 && WHOLE_UNITS.test(after)) return String(Math.round(v));
    if (/\./.test(original)) return trimDecimal(v);
    let whole = Math.floor(v);
    const rest = v - whole;
    let best = 0;
    for (const f of SNAP) if (Math.abs(f - rest) < Math.abs(best - rest)) best = f;
    if (Math.abs(best - rest) > 0.02) return trimDecimal(v);
    if (best === 1) { whole += 1; best = 0; }
    const glyph = best ? GLYPH[+best.toFixed(3)] : "";
    if (!whole) return glyph || "0";
    return glyph ? `${whole} ${glyph}` : String(whole);
  };

  // Scaled replacements for one RANGE match at `index` in `text`.
  const scaleMatch = (m, index, text, factor, out) => {
    const end = index + m[0].length;
    const after = text.slice(end);
    const lo = parse(m[1]) * factor;
    const hi = m[3] ? parse(m[3]) * factor : lo;
    if (!isFinite(lo) || !isFinite(hi)) return;
    const loText = format(lo, m[1], m[3] ? after : text.slice(index + m[1].length));
    let replacement = loText;
    if (m[3]) replacement += m[2] + format(hi, m[3], after);
    out.push({ start: index, end, text: replacement, mark: true });

    // Make a following unit word agree: "1 cup" -> "2 cups", "1 ½ cups" -> "¾ cup".
    const unit = after.match(UNIT_WORD);
    if (unit) {
      const base = unit[2];
      const plural = hi > 1;
      const word = plural ? base + (/(ch|x)$/i.test(base) ? "es" : "s") : base;
      if (word !== base + (unit[3] || "")) {
        const s = end + unit[1].length;
        out.push({ start: s, end: s + base.length + (unit[3] || "").length, text: word });
      }
    }
  };

  // All replacements for an ingredient's full text, or [] if it has no
  // leading amount.
  const replacementsFor = (text, factor) => {
    const out = [];
    const lead = text.match(LEADING);
    if (!lead) return out;
    const leadStart = lead[1].length;
    const leadEnd = lead[0].length;
    scaleMatch([lead[0].slice(leadStart), lead[2], lead[3], lead[4]], leadStart, text, factor, out);

    for (const p of text.matchAll(PAREN)) {
      if (p.index < leadEnd) continue;
      const before = text.slice(0, p.index);
      if (before.trimEnd().length === leadEnd || PACKAGE_WORDS.test(before)) continue;
      const innerStart = p.index + 1;
      for (const n of p[1].matchAll(ANY)) {
        scaleMatch(n, innerStart + n.index, text, factor, out);
      }
    }
    return out;
  };

  const originals = new WeakMap();

  const textNodes = (el) => {
    const nodes = [];
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) nodes.push(walker.currentNode);
    return nodes;
  };

  const rescale = (span, factor) => {
    if (!originals.has(span)) originals.set(span, span.cloneNode(true));
    span.replaceChildren(...originals.get(span).cloneNode(true).childNodes);
    if (factor === 1) return;

    const nodes = textNodes(span);
    const text = nodes.map((n) => n.data).join("");
    const reps = replacementsFor(text, factor).sort((a, b) => a.start - b.start);
    if (!reps.length) return;

    // Apply each replacement inside the text node that holds it (keeps links
    // and formatting intact); skip any that straddle two nodes.
    let offset = 0;
    for (const node of nodes) {
      const start = offset;
      const end = offset + node.data.length;
      offset = end;
      const mine = reps.filter((r) => r.start >= start && r.end <= end);
      if (!mine.length) continue;
      const frag = document.createDocumentFragment();
      let pos = start;
      for (const r of mine) {
        if (r.start < pos) continue;
        frag.append(text.slice(pos, r.start));
        if (r.mark) {
          const q = document.createElement("span");
          q.className = "qty-scaled";
          q.textContent = r.text;
          frag.append(q);
        } else {
          frag.append(r.text);
        }
        pos = r.end;
      }
      frag.append(text.slice(pos, end));
      node.replaceWith(frag);
    }
  };

  const init = () => {
    const picker = document.querySelector(".recipe-scale");
    if (!picker) return;
    const section = picker.closest("section") || document;
    const items = [...section.querySelectorAll(".ingredient > span")];
    if (!items.length) return;
    picker.hidden = false;

    const radios = [...picker.querySelectorAll("input[type=radio]")];
    const apply = (radio, updateUrl) => {
      const factor = +radio.value;
      radio.checked = true;
      for (const span of items) rescale(span, factor);
      section.classList.toggle("is-scaled", factor !== 1);
      // Shown after the heading when printing (the picker itself is hidden).
      section.querySelector("h2")?.setAttribute("data-scale-label",
        radio.nextElementSibling?.textContent || `${factor}×`);
      if (updateUrl) {
        const url = new URL(location.href);
        if (factor === 1) url.searchParams.delete("scale");
        else url.searchParams.set("scale", radio.value);
        history.replaceState(history.state, "", url);
      }
    };

    for (const radio of radios) {
      radio.addEventListener("change", () => radio.checked && apply(radio, true));
    }

    const wanted = new URLSearchParams(location.search).get("scale");
    const initial = radios.find((r) => r.value === wanted);
    if (initial && initial.value !== "1") apply(initial, false);
  };

  if (document.readyState === "loading") addEventListener("DOMContentLoaded", init);
  else init();
})();
