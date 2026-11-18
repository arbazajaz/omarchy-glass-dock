const assert = require("node:assert/strict")
const model = require("../DockModel.js")

const entries = [
  { id: "WhatsApp", startupClass: "chrome-web.whatsapp.com__-Default" },
  { id: "YouTube", startupClass: "chrome-youtube.com__-Default" },
]
assert.equal(model.webAppEntryId("chrome-web.whatsapp.com__-Profile_2", entries), "WhatsApp")
assert.equal(model.webAppEntryId("chrome-youtube.com__-Profile_3", entries), "YouTube")
assert.equal(model.webAppEntryId("chrome-youtube.com_other_-Profile_3", entries), "")
assert.equal(model.webAppEntryId("google-chrome", entries), "")
assert.equal(model.webAppEntryId("chrome-youtube.com__-Profile_3", [
  ...entries,
  { id: "YouTubeSecondProfile", startupClass: "chrome-youtube.com__-Profile_2" },
]), "")
assert.equal(model.webAppEntryId("chrome-youtube.com__-Profile_2", [
  ...entries,
  { id: "YouTubeSecondProfile", startupClass: "chrome-youtube.com__-Profile_2" },
]), "YouTubeSecondProfile")

const minimized = model.buildItems([], [{ key: "window:123", minimized: true }])
assert.equal(minimized.length, 1)
assert.equal(model.iconNameForEntry(undefined, minimized[0]), "application-x-executable")
assert.equal(model.iconNameForEntry({ icon: "file:///usr/share/icons/app.png" }), "file:///usr/share/icons/app.png")
