/**
 * reader.js — shared/reader.js
 * Lightweight article text extractor (no external dependencies).
 * Works in Chrome content scripts and Safari Web Extensions.
 *
 * Usage:
 *   const { title, text, wordCount, readingTimeMinutes } = extractArticle();
 */

(function (global) {
  'use strict';

  /** Tags whose entire subtree should be ignored. */
  const SKIP_TAGS = new Set([
    'script', 'style', 'noscript', 'nav', 'header', 'footer',
    'aside', 'form', 'figure', 'figcaption', 'button', 'select',
    'textarea', 'iframe', 'object', 'embed', 'canvas', 'svg',
    'advertisement', 'ad',
  ]);

  /** CSS class / id fragments that strongly suggest non-content. */
  const NOISE_PATTERNS = [
    /\b(nav|menu|sidebar|footer|header|banner|ad(vert)?|promo|social|share|comment|related|recommend|cookie|popup|modal)\b/i,
  ];

  function isNoisy(el) {
    const cls = (el.className || '').toString();
    const id  = (el.id || '').toString();
    return NOISE_PATTERNS.some(re => re.test(cls) || re.test(id));
  }

  /**
   * Score a block element: higher = more likely to be article body.
   * Heuristics: paragraph density, text length, link density.
   */
  function scoreElement(el) {
    const text = el.innerText || el.textContent || '';
    const linkText = Array.from(el.querySelectorAll('a'))
      .reduce((acc, a) => acc + (a.textContent || '').length, 0);
    const totalLen = text.length;
    if (totalLen < 80) return 0;
    const linkDensity = linkText / Math.max(totalLen, 1);
    if (linkDensity > 0.5) return 0;
    const paraCount = el.querySelectorAll('p').length;
    return totalLen * (1 - linkDensity) + paraCount * 20;
  }

  /**
   * Extract plain text from a DOM element, inserting line breaks at blocks.
   */
  function extractText(el) {
    const BLOCK = new Set([
      'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'td', 'th', 'blockquote', 'article', 'section', 'pre',
    ]);
    let out = '';

    function walk(node) {
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.textContent;
        return;
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      const tag = node.tagName.toLowerCase();
      if (SKIP_TAGS.has(tag)) return;
      if (isNoisy(node)) return;
      const isBlock = BLOCK.has(tag);
      if (isBlock) out += '\n';
      for (const child of node.childNodes) walk(child);
      if (isBlock) out += '\n';
    }

    walk(el);
    // Normalise whitespace.
    return out
      .replace(/\r\n/g, '\n')
      .replace(/[ \t]+/g, ' ')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  function extractArticle() {
    const title = document.title || '';

    // Try <article> first.
    const articles = Array.from(document.querySelectorAll('article'));
    if (articles.length > 0) {
      const best = articles.reduce((a, b) =>
        (a.textContent || '').length >= (b.textContent || '').length ? a : b);
      const text = extractText(best);
      if (text.length > 200) {
        return buildResult(title, text);
      }
    }

    // Try scoring block elements.
    const candidates = Array.from(
      document.querySelectorAll('div, section, main, [role="main"]')
    );
    let bestEl = null;
    let bestScore = 0;
    for (const el of candidates) {
      if (isNoisy(el)) continue;
      const score = scoreElement(el);
      if (score > bestScore) {
        bestScore = score;
        bestEl = el;
      }
    }
    if (bestEl && bestScore > 300) {
      const text = extractText(bestEl);
      if (text.length > 200) {
        return buildResult(title, text);
      }
    }

    // Fallback: document body.
    return buildResult(title, extractText(document.body));
  }

  function buildResult(title, text) {
    const words = text.split(/\s+/).filter(Boolean);
    const wordCount = words.length;
    const readingTimeMinutes = Math.max(1, Math.round(wordCount / 200));
    return { title, text, wordCount, readingTimeMinutes };
  }

  // Export for use as a module or injected script.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { extractArticle };
  } else {
    global.SupertonicReader = { extractArticle };
  }
})(typeof globalThis !== 'undefined' ? globalThis : window);
