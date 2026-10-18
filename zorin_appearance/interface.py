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

INTERFACE_SCHEMA = 'org.gnome.desktop.interface'
ZORIN_MENU_EXTENSION = 'zorin-menu@zorinos.com'
ZORIN_TASKBAR_EXTENSION = 'zorin-taskbar@zorinos.com'
ZORIN_DASH_EXTENSION = 'zorin-dash@zorinos.com'
ZORIN_TRAY_EXTENSION = 'zorin-appindicator@zorinos.com'
ZORIN_SCREEN_KEYBOARD_BUTTON_EXTENSION = 'zorin-screen-keyboard-panel-button@zorinos.com'
READING_STRIP_EXTENSION = 'readingstrip@lupantano.gihthub'
MENU_SCHEMA = 'org.gnome.shell.extensions.zorin-menu'


class Interface(Gtk.Box):

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

        if ZORIN_TASKBAR_EXTENSION in installed_extensions:
            self.zorin_menu_shortcut = widgets.BooleanComboExtension(_('Left Super Key'),
                                                                     MENU_SCHEMA,
                                                                     'super-hotkey',
                                                                     'Zorin ' + _('Menu'),
                                                                     _('Activities Overview'),
                                                                     ZORIN_MENU_EXTENSION)
            self.selection_box.add(self.zorin_menu_shortcut)

        self.selection_box.add(widgets.Switch(_('Display Activities Overview on startup'),
                               INTERFACE_SCHEMA,
                               'zorin-display-overview-on-startup'))

        self.selection_box.add(widgets.Switch(_('Overlay Scrollbars'),
                               INTERFACE_SCHEMA,
                               'overlay-scrolling',
                               _('Applications need to be restarted for change to take effect')))

        if ZORIN_SCREEN_KEYBOARD_BUTTON_EXTENSION in installed_extensions:
            self.selection_box.add(widgets.SwitchExtension(
                                   [ZORIN_SCREEN_KEYBOARD_BUTTON_EXTENSION],
                                   _('Screen Keyboard Button in Panel')))

        if ZORIN_TRAY_EXTENSION in installed_extensions:
            tray_extension = environment._get_shell_extension(ZORIN_TRAY_EXTENSION)
            tray_prefs = os.path.join(tray_extension['path'], "prefs.js")
            if os.path.exists(tray_prefs):
                self.selection_box.add(widgets.ExtensionSwitchPrefsButton(
                                       tray_extension,
                                       _('Tray Icons in Panel')))

        if READING_STRIP_EXTENSION in installed_extensions:
            reading_strip_extension = environment._get_shell_extension(READING_STRIP_EXTENSION)
            reading_strip_prefs = os.path.join(reading_strip_extension['path'], "prefs.js")
            if os.path.exists(reading_strip_prefs):
                self.selection_box.add(widgets.ExtensionSwitchPrefsButton(
                                       reading_strip_extension,
                                       _('Reading Strip'),
                                       _("An assistive guide to help you focus while reading.") + " "
                                       + _("Click the panel icon to toggle.")))

        if ZORIN_TASKBAR_EXTENSION in installed_extensions:
            taskbar_extension = environment._get_shell_extension(ZORIN_TASKBAR_EXTENSION)
            taskbar_prefs = os.path.join(taskbar_extension['path'], "prefs.js")
            if os.path.exists(taskbar_prefs):
                self.selection_box.add(widgets.ExtensionPrefsButton(
                                       _('Taskbar Settings'),
                                       taskbar_extension))

        if ZORIN_DASH_EXTENSION in installed_extensions:
            dash_extension = environment._get_shell_extension(ZORIN_DASH_EXTENSION)
            dash_prefs = os.path.join(dash_extension['path'], "prefs.js")
            if os.path.exists(dash_prefs):
                self.selection_box.add(widgets.ExtensionPrefsButton(
                                       "Dash " + _('Settings'),
                                       dash_extension))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)
