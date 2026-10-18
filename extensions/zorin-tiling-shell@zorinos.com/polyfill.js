import { Extension } from "resource:///org/gnome/shell/extensions/extension.js";

function openPrefs() {
  if (Extension.openPrefs) {
    Extension.openPrefs();
  } else {
    Extension.lookupByUUID(
      "zorin-tiling-shell@zorinos.com"
    )?.openPreferences();
  }
}
export {
  Extension,
  openPrefs
};
