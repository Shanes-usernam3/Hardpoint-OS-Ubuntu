/*
 * Zorin Screen Keyboard Panel Button: Show a button to open the Screen
 * Keyboard in the panel.
 *
 * Copyright (C) 2019-2025 Zorin OS Technologies Ltd.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as Keyboard from 'resource:///org/gnome/shell/ui/keyboard.js';

export const ScreenKeyboardButton = GObject.registerClass({
}, class ScreenKeyboardButton extends PanelMenu.Button {
    _init() {
        super._init(null, 'Screen Keyboard Button')

        let hbox = new St.BoxLayout({ style_class: 'panel-status-menu-box' });
        let icon = new St.Icon({ icon_name: 'input-keyboard-symbolic',
                                 style_class: 'system-status-icon' });

        hbox.add_child(icon);
        this.add_child(hbox);

        this.connect('touch-event', (actor, event) => {
            if (event.type() == Clutter.EventType.TOUCH_BEGIN) {
	            this._toggleKeyboard();
            }
        });

        this.connect('button-press-event', this._toggleKeyboard);
    }

    _toggleKeyboard() {
        if (Main.keyboard.visible) {
            Main.keyboard.close();
        } else {
            Main.keyboard.open(Main.layoutManager.primaryIndex);
        }
    }
});

export default class ZorinHideActivitiesMoveClockExtension extends Extension {
    enable() {
        this.currentSeat = Clutter.get_default_backend().get_default_seat();
        this.backup_touchMode = this.currentSeat.get_touch_mode;
        this.currentSeat.get_touch_mode = () => true;

        this._injectionManager = new InjectionManager();
        this._injectionManager.overrideMethod(
            Keyboard.KeyboardManager.prototype, '_lastDeviceIsTouchscreen',
            originalMethod => {
                return function () {
                    return true;
                }
            }
        );

        Main.keyboard._syncEnabled();
      
        this._screenKeyboardButton = new ScreenKeyboardButton();
        Main.panel.addToStatusArea('screen-keyboard-button', this._screenKeyboardButton, 0);
    }

    disable() {
        this._screenKeyboardButton.destroy();
        delete this._screenKeyboardButton;
     
        this._injectionManager.clear();
        this._injectionManager = null;

        this.currentSeat.get_touch_mode = this.backup_touchMode;
        delete this.currentSeat;
        delete this.backup_touchMode;

        Main.keyboard._syncEnabled();
    }
}
