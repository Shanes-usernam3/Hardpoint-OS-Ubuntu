# This file is part of the Zorin Appearance program.
#
# Copyright 2016-2024 Zorin OS Technologies Ltd.
# Based on code from gnome-tweak-tool by John Stowers, Copyright 2011.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

import gi
import gettext
import os.path

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

from zorin_appearance import listbox
from zorin_appearance import widgets
from zorin_appearance import environment

t = gettext.translation('zorin-appearance', '/usr/share/locale', fallback=True)
_ = t.gettext

installed_extensions = environment._shell.list_extensions()

MUTTER_SCHEMA = 'org.gnome.mutter'
WM_SCHEMA = 'org.gnome.desktop.wm.preferences'
BUTTONS_LEFT = 'close,minimize,maximize:appmenu'
BUTTONS_RIGHT = 'appmenu:minimize,maximize,close'
BUTTONS_EXCEPTION = 'close:maximize' # For the elementary-like layout
ZORIN_TILING_EXTENSION = 'zorin-tiling-shell@zorinos.com'


class Titlebars(Gtk.Box):

    def __init__(self):
        Gtk.Box.__init__(
            self,
            orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            margin_bottom=16
            )

        self.selection_frame = Gtk.Frame()
        self.selection_box = Gtk.ListBox()
        self.selection_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.selection_box.set_header_func(listbox.list_box_update_header_func,
                None)

        self.selection_box.add(widgets.LeftRightButton(_('Titlebar Buttons'),
                               WM_SCHEMA,
                               'button-layout',
                               BUTTONS_LEFT,
                               BUTTONS_RIGHT,
                               BUTTONS_EXCEPTION))

        self.selection_box.add(widgets.GSettingsCombo(_("Double-Click"),
                               None,
                               WM_SCHEMA,
                               'action-double-click-titlebar',
                               [("none", _("None")), ("toggle-maximize", _("Toggle Maximize")), ("minimize", _("Minimize")), ("menu", _("Menu"))]))

        self.selection_box.add(widgets.GSettingsCombo(_("Middle-Click"),
                               None,
                               WM_SCHEMA,
                               'action-middle-click-titlebar',
                               [("none", _("None")), ("toggle-maximize", _("Toggle Maximize")), ("minimize", _("Minimize")), ("menu", _("Menu"))]))

        self.selection_box.add(widgets.GSettingsCombo(_("Secondary-Click"),
                               None,
                               WM_SCHEMA,
                               'action-right-click-titlebar',
                               [("none", _("None")), ("toggle-maximize", _("Toggle Maximize")), ("minimize", _("Minimize")), ("menu", _("Menu"))]))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)


class Placement(Gtk.Box):

    def __init__(self):
        Gtk.Box.__init__(
            self,
            orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            margin_bottom=16
            )

        self.selection_frame = Gtk.Frame()
        self.selection_box = Gtk.ListBox()
        self.selection_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.selection_box.set_header_func(listbox.list_box_update_header_func,
                None)

        self.window_placement = widgets.BooleanCombo(_('New Window Placement'),
                                                      MUTTER_SCHEMA,
                                                      'center-new-windows',
                                                      _('Centered'),
                                                      _('Spread')
                                                      )
        self.selection_box.add(self.window_placement)

        self.selection_box.add(widgets.GSettingsCombo(_("Window Action Key"),
                               _("You can hold this key down while dragging the cursor to move the window from any position."),
                               WM_SCHEMA,
                               'mouse-button-modifier',
                               [("disabled", _("Disabled")), ("<Alt>", "Alt"), ("<Super>", "Super")]))

        self.selection_box.add(widgets.Switch(_('Attach Modal Dialogs'),
                               MUTTER_SCHEMA,
                               'attach-modal-dialogs',
                               _('When on, modal dialog windows are attached to their parent windows, and cannot be moved.')))

        if ZORIN_TILING_EXTENSION in installed_extensions:
            tiling_extension = environment._get_shell_extension(ZORIN_TILING_EXTENSION)
            tiling_prefs = os.path.join(tiling_extension['path'], "prefs.js")
            if os.path.exists(tiling_prefs):
                self.selection_box.add(widgets.ExtensionSwitchPrefsButton(
                                       tiling_extension,
                                       _('Advanced Window Tiling')))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)


class Focus(Gtk.Box):

    def __init__(self):
        Gtk.Box.__init__(
            self,
            orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            margin_bottom=16
            )

        self.selection_frame = Gtk.Frame()
        self.selection_box = Gtk.ListBox()
        self.selection_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.selection_box.set_header_func(listbox.list_box_update_header_func,
                None)

        self.selection_box.add(widgets.GSettingsCombo(_("Window Focus"),
                               None,
                               WM_SCHEMA,
                               'focus-mode',
                               [("click", _("Click to Focus")), ("sloppy", _("Focus on Hover"))]))

        self.selection_box.add(widgets.Switch(_('Raise Windows When Focused'),
                               WM_SCHEMA,
                               'auto-raise'))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)
