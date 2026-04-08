// popup.js

const textInput = document.getElementById("textInput");
const btnSelection = document.getElementById("btnSelection");
const btnPage = document.getElementById("btnPage");
const btnSpeak = document.getElementById("btnSpeak");
const btnCopy = document.getElementById("btnCopy");
const statusEl = document.getElementById("status");

function setStatus(msg, type = "") {
  statusEl.textContent = msg;
  statusEl.className = "status" + (type ? " " + type : "");
}

function buildURL(text) {
  return "supertonic://speak?text=" + encodeURIComponent(text.trim());
}

// --- Grab selected text from active tab ---
btnSelection.addEventListener("click", async () => {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => window.getSelection().toString()
    });
    const sel = result.result || "";
    if (sel) {
      textInput.value = sel;
      setStatus("Selection loaded (" + sel.length + " chars)");
    } else {
      setStatus("No text selected on page.", "err");
    }
  } catch (e) {
    setStatus("Could not read selection: " + e.message, "err");
  }
});

// --- Grab visible page text ---
btnPage.addEventListener("click", async () => {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => {
        const cloned = document.body.cloneNode(true);
        cloned.querySelectorAll("script,style,noscript").forEach(el => el.remove());
        return (cloned.innerText || cloned.textContent || "").trim();
      }
    });
    const text = result.result || "";
    if (text) {
      textInput.value = text;
      setStatus("Page text loaded (" + text.length + " chars)");
    } else {
      setStatus("No text found on page.", "err");
    }
  } catch (e) {
    setStatus("Could not read page: " + e.message, "err");
  }
});

// --- Open Supertonic deep-link ---
btnSpeak.addEventListener("click", async () => {
  const text = textInput.value.trim();
  if (!text) { setStatus("Enter some text first.", "err"); return; }
  const url = buildURL(text);
  await chrome.tabs.create({ url });
  setStatus("Opened in Supertonic!", "ok");
});

// --- Copy deep-link to clipboard ---
btnCopy.addEventListener("click", async () => {
  const text = textInput.value.trim();
  if (!text) { setStatus("Enter some text first.", "err"); return; }
  const url = buildURL(text);
  try {
    await navigator.clipboard.writeText(url);
    setStatus("Link copied!", "ok");
  } catch {
    setStatus("Clipboard unavailable.", "err");
  }
});

// --- Pre-fill with current selection on open ---
(async () => {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => window.getSelection().toString()
    });
    const sel = (result && result.result) || "";
    if (sel) {
      textInput.value = sel;
      setStatus("Selection pre-loaded (" + sel.length + " chars)");
    }
  } catch {
    // silently ignore (e.g. restricted pages)
  }
})();
