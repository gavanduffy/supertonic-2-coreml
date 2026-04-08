// background.js — MV3 service worker
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "supertonic-speak-selection",
    title: "Speak with Supertonic",
    contexts: ["selection"]
  });
  chrome.contextMenus.create({
    id: "supertonic-speak-page",
    title: "Speak page with Supertonic",
    contexts: ["page"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "supertonic-speak-selection" && info.selectionText) {
    openSupertonic(info.selectionText);
  } else if (info.menuItemId === "supertonic-speak-page") {
    // Ask content script for page text
    chrome.tabs.sendMessage(tab.id, { action: "getPageText" }, (response) => {
      if (response && response.text) {
        openSupertonic(response.text);
      }
    });
  }
});

function openSupertonic(text) {
  const encoded = encodeURIComponent(text);
  // Deep-link into the iOS app via custom URL scheme
  // On desktop, this will show the iOS app URL for copying; on mobile Safari it opens the app.
  const url = `supertonic://speak?text=${encoded}`;
  chrome.tabs.create({ url });
}
