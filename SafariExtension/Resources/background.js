// Supertonic TTS — Safari MV2 background (non-persistent event page)
// Uses browser.* API (Safari provides window.browser as the namespace)

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message && message.type === "ping") {
    sendResponse({ type: "pong" });
  }
  return true; // keep channel open for async response
});
