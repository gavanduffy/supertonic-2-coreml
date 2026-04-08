// content.js — injected into every page
// Listens for requests from the background service worker.

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.action === "getPageText") {
    // Strip script/style tags and return visible text content
    const cloned = document.body.cloneNode(true);
    cloned.querySelectorAll("script, style, noscript").forEach(el => el.remove());
    const text = (cloned.innerText || cloned.textContent || "").trim();
    sendResponse({ text });
  }
  return true; // keep channel open for async response
});
