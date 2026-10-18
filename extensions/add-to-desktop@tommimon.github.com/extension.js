import * as ShortcutMaker from './shortcutMaker.js';
import * as AppDisplay from 'resource:///org/gnome/shell/ui/appDisplay.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class AddToDesktop extends Extension {
    enable () {
        // Save the original popupMenu only if it has not been wrapped already
        if (!AppDisplay.AppIcon.prototype._addToDesktopOrigPopupMenu) {
            AppDisplay.AppIcon.prototype._addToDesktopOrigPopupMenu =
                AppDisplay.AppIcon.prototype.popupMenu;
        }
        ShortcutMaker.editIconClass(AppDisplay.AppIcon.prototype._addToDesktopOrigPopupMenu);
    }

    disable () {
        AppDisplay.AppIcon.prototype.popupMenu =
            AppDisplay.AppIcon.prototype._addToDesktopOrigPopupMenu;
        delete AppDisplay.AppIcon.prototype._addToDesktopOrigPopupMenu;
    }
}
