/**
 * background.js — Chrome MV3 service worker.
 * Relays messages between the popup and content scripts.
 */

'use strict';

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'speakEnded') {
    // Broadcast to popup if open.
    chrome.runtime.sendMessage({ action: 'speakEnded' }).catch(() => {});
  }
  return false;
});

// Install / update handler.
chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === 'install') {
    console.log('Supertonic TTS extension installed.');
  }
});
