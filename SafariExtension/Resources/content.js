// Supertonic TTS — Safari MV2 content script
// Listens for messages from the popup and returns selected / page text.

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message && message.type === "getSelectedText") {
    const selected = window.getSelection().toString().trim();
    if (selected.length > 0) {
      sendResponse({ text: selected });
    } else {
      // Fall back to full visible body text (first 2000 chars)
      const bodyText = document.body.innerText.trim().slice(0, 2000);
      sendResponse({ text: bodyText });
    }
    return true;
  }
});
