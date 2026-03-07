/**
 * popup.js — Chrome extension popup script.
 * Extracts article text from the active tab and reads it aloud via
 * Web Speech API, or sends the URL to the Supertonic iOS app.
 */

'use strict';

// ── DOM refs ──────────────────────────────────────────────────────────────────
const elLoading    = document.getElementById('loading');
const elArticle    = document.getElementById('article-info');
const elTitle      = document.getElementById('page-title');
const elMeta       = document.getElementById('page-meta');
const elControls   = document.getElementById('controls');
const elActions    = document.getElementById('actions');
const elVoice      = document.getElementById('voice-select');
const elRate       = document.getElementById('rate-range');
const elRateLabel  = document.getElementById('rate-label');
const elPitch      = document.getElementById('pitch-range');
const elPitchLabel = document.getElementById('pitch-label');
const elPlay       = document.getElementById('btn-play');
const elStop       = document.getElementById('btn-stop');
const elSend       = document.getElementById('btn-send');
const elError      = document.getElementById('error-msg');

let articleText = '';
let currentTabUrl = '';
let isSpeaking = false;

// ── Prefs (persisted) ─────────────────────────────────────────────────────────
async function loadPrefs() {
  const prefs = await chrome.storage.sync.get({ rate: 1.0, pitch: 1.0, voice: '' });
  elRate.value  = prefs.rate;
  elPitch.value = prefs.pitch;
  updateLabels();
  return prefs;
}

async function savePrefs() {
  await chrome.storage.sync.set({
    rate:  parseFloat(elRate.value),
    pitch: parseFloat(elPitch.value),
    voice: elVoice.value,
  });
}

function updateLabels() {
  elRateLabel.textContent  = `${parseFloat(elRate.value).toFixed(1)}×`;
  elPitchLabel.textContent = parseFloat(elPitch.value).toFixed(1);
}

// ── Voices ────────────────────────────────────────────────────────────────────
function populateVoices(preferred) {
  const voices = window.speechSynthesis.getVoices();
  elVoice.innerHTML = '';
  for (const v of voices) {
    const opt = document.createElement('option');
    opt.value = v.name;
    opt.textContent = `${v.name} (${v.lang})`;
    if (v.name === preferred) opt.selected = true;
    elVoice.appendChild(opt);
  }
}

// ── Initialise ────────────────────────────────────────────────────────────────
(async function init() {
  const prefs = await loadPrefs();
  if (window.speechSynthesis.getVoices().length > 0) {
    populateVoices(prefs.voice);
  } else {
    window.speechSynthesis.onvoiceschanged = () => populateVoices(prefs.voice);
  }

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) {
    showError('Could not access the current tab.');
    return;
  }
  currentTabUrl = tab.url || '';

  try {
    // Inject shared scripts if not already present.
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      files: ['../shared/reader.js', '../shared/content.js'],
    }).catch((err) => {
      // Script may already be injected — only log non-trivial errors.
      if (!err.message?.includes('Cannot access') && !err.message?.includes('already been declared')) {
        console.warn('Supertonic TTS: script injection warning:', err.message);
      }
    });

    const response = await chrome.tabs.sendMessage(tab.id, { action: 'extractText' });
    if (response?.error) throw new Error(response.error);

    articleText = response.text || '';
    elTitle.textContent = response.title || tab.title || '';
    elMeta.textContent  = `~${response.readingTimeMinutes} min read · ${response.wordCount} words`;

    elLoading.classList.add('hidden');
    elArticle.classList.remove('hidden');
    elControls.classList.remove('hidden');
    elActions.classList.remove('hidden');
  } catch (err) {
    showError(`Could not extract article: ${err.message}`);
  }
})();

// ── Playback ──────────────────────────────────────────────────────────────────
elPlay.addEventListener('click', async () => {
  if (!articleText) return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) return;

  await chrome.tabs.sendMessage(tab.id, {
    action: 'speak',
    text:   articleText,
    voice:  elVoice.value,
    rate:   parseFloat(elRate.value),
    pitch:  parseFloat(elPitch.value),
  });

  isSpeaking = true;
  elPlay.classList.add('hidden');
  elStop.classList.remove('hidden');
  savePrefs();
});

elStop.addEventListener('click', async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab?.id) {
    await chrome.tabs.sendMessage(tab.id, { action: 'stopSpeak' }).catch(() => {});
  }
  setStopped();
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.action === 'speakEnded') setStopped();
});

function setStopped() {
  isSpeaking = false;
  elStop.classList.add('hidden');
  elPlay.classList.remove('hidden');
}

// ── Send to iOS ───────────────────────────────────────────────────────────────
elSend.addEventListener('click', async () => {
  if (!currentTabUrl) return;
  const encoded = encodeURIComponent(currentTabUrl);
  // Try to open the iOS custom URL scheme (works on macOS too).
  const scheme = `supertonic-tts://speak?url=${encoded}`;
  window.open(scheme, '_self');
  // Also copy to clipboard as a fallback.
  await navigator.clipboard.writeText(currentTabUrl).catch(() => {});
  elSend.textContent = '✅ URL copied / app launched';
  setTimeout(() => { elSend.textContent = '📱 Send to iPhone'; }, 3000);
});

// ── Controls ──────────────────────────────────────────────────────────────────
elRate.addEventListener('input',  updateLabels);
elPitch.addEventListener('input', updateLabels);
[elRate, elPitch, elVoice].forEach(el => el.addEventListener('change', savePrefs));

// ── Helpers ───────────────────────────────────────────────────────────────────
function showError(msg) {
  elLoading.classList.add('hidden');
  elError.textContent = msg;
  elError.classList.remove('hidden');
}
