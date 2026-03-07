/**
 * content.js — shared/content.js
 * Injected into every page. Listens for messages from the popup / background
 * service worker and returns extracted article text.
 */

'use strict';

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.action === 'extractText') {
    try {
      if (typeof SupertonicReader === 'undefined') {
        sendResponse({ error: 'Reader not loaded.' });
        return true;
      }
      const result = SupertonicReader.extractArticle();
      sendResponse({ ok: true, ...result });
    } catch (err) {
      sendResponse({ error: err.message });
    }
    return true; // keep channel open for async sendResponse
  }

  if (message.action === 'speak') {
    const { text, voice, rate, pitch } = message;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    if (voice) {
      const voices = window.speechSynthesis.getVoices();
      const match = voices.find(v => v.name === voice);
      if (match) utterance.voice = match;
    }
    utterance.rate  = typeof rate  === 'number' ? rate  : 1.0;
    utterance.pitch = typeof pitch === 'number' ? pitch : 1.0;
    utterance.onend = () => chrome.runtime.sendMessage({ action: 'speakEnded' });
    window.speechSynthesis.speak(utterance);
    sendResponse({ ok: true });
    return true;
  }

  if (message.action === 'stopSpeak') {
    window.speechSynthesis.cancel();
    sendResponse({ ok: true });
    return true;
  }
});
