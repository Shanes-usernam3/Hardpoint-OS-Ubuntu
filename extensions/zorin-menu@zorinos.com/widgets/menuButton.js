import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Constants from '../constants.js';
import { EXTENSION_PATH, SETTINGS } from '../extension.js'

export const MenuButton = GObject.registerClass({
}, class MenuButton extends St.BoxLayout {
    _init(panelParent) {
        super._init({
            style_class: 'panel-status-menu-box'
        });

        this._panelParent = panelParent;
        this._iconSize = 32;
        this._icon = new St.Icon({
            icon_size: this._iconSize,
            style_class: 'popup-menu-icon'
        });
        this._setIcon();
        this.add_child(this._icon);

        SETTINGS.connectObject('changed::logo-icon', () => this._setIcon(), this);

        this._panelParent.connectObject(
            'notify::height', () => this._adjustIconSize(),
            'notify::width', () => this._adjustIconSize(),
            this);

        // Re-check icon size after the panel is mapped, as the initial
        // size may not yet be correct during shell startup.
        this._mappedId = null;
        if (!this._panelParent.mapped) {
            this._mappedId = this._panelParent.connect('notify::mapped', () => {
                this._adjustIconSize();
                if (this._mappedId) {
                    this._panelParent?.disconnect(this._mappedId);
                    this._mappedId = null;
                }
            });
        }

        this.connect('destroy', this._onDestroy.bind(this));
        this._adjustIconSize();
    }

    _getPanelSize() {
            const scaleFactor = St.ThemeContext.get_for_stage(global.stage).scale_factor;

            // Calculate panel size depending on whether it is horizontal or vertical
            const panelSize = Math.min(this._panelParent.get_height(), this._panelParent.get_width());

            // If the panel hasn't been allocated yet, fall back to the default size
            if (panelSize <= 0)
                return Constants.MENU_BUTTON_DEFAULT_PANEL_SIZE;

            return panelSize / scaleFactor;
    }

    _setIcon() {
        const menu_icon = EXTENSION_PATH + (
            SETTINGS.get_boolean('logo-icon') ?
            '/zorin-icon-symbolic.svg' :
            '/app-grid-symbolic.svg'
        );
        this._icon.set_gicon(Gio.icon_new_for_string(menu_icon));
    }

    _adjustIconSize() {
        let availSize = this._getPanelSize() - (Constants.MENU_BUTTON_MINIMUM_PADDING * 2);

        let newIconSize = Constants.MenuButtonIconSizes[0];
        for (let i = 0; i < Constants.MenuButtonIconSizes.length ; i++) {
            if (Constants.MenuButtonIconSizes[i] < availSize) {
                newIconSize = Constants.MenuButtonIconSizes[i];
            }
        }

        if (newIconSize == this._iconSize)
            return;

        this._iconSize = newIconSize;
        this._icon.set_icon_size(this._iconSize);
    }

    _onDestroy() {
        SETTINGS?.disconnectObject(this);
        this._panelParent?.disconnectObject(this);

        if (this._mappedId) {
            this._panelParent?.disconnect(this._mappedId);
            this._mappedId = null;
        }

        this._panelParent = null;

        this._icon?.destroy();
        this._icon = null;
        this._iconSize = null;
    }
});
