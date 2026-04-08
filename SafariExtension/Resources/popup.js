// Supertonic TTS — Safari MV2 popup
// Uses browser.* API (MV2-style tabs.executeScript, not chrome.scripting)

const textInput = document.getElementById("textInput");
const btnSpeak  = document.getElementById("btnSpeak");
const btnStop   = document.getElementById("btnStop");
const statusEl  = document.getElementById("status");

let currentUtterance = null;

function setStatus(msg) {
  statusEl.textContent = msg;
}

// On popup open, try to grab selected/page text automatically
document.addEventListener("DOMContentLoaded", () => {
  browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
    if (!tab) return;
    browser.tabs.sendMessage(tab.id, { type: "getSelectedText" })
      .then((response) => {
        if (response && response.text && textInput.value.trim() === "") {
          textInput.value = response.text;
        }
      })
      .catch(() => {
        // Content script may not be injected on restricted pages — ignore
      });
  });
});

btnSpeak.addEventListener("click", () => {
  const text = textInput.value.trim();
  if (!text) {
    setStatus("No text to speak.");
    return;
  }

  // Use Web Speech API for playback (available in Safari)
  if (!window.speechSynthesis) {
    setStatus("Speech synthesis not supported.");
    return;
  }

  stopSpeech();

  currentUtterance = new SpeechSynthesisUtterance(text);
  currentUtterance.onstart  = () => setStatus("Speaking…");
  currentUtterance.onend    = () => setStatus("Done.");
  currentUtterance.onerror  = (e) => setStatus("Error: " + e.error);

  window.speechSynthesis.speak(currentUtterance);
});

btnStop.addEventListener("click", () => {
  stopSpeech();
  setStatus("Stopped.");
});

function stopSpeech() {
  if (window.speechSynthesis) {
    window.speechSynthesis.cancel();
  }
  currentUtterance = null;
}
