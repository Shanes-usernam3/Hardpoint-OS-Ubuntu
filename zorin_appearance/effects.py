# This file is part of the Zorin Appearance program.
#
# Copyright 2023 Zorin OS Technologies Ltd.
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

WINDOW_MOVE_EFFECT_EXTENSION = 'zorin-window-move-effect@zorinos.com'
MAGIC_LAMP_EFFECT_EXTENSION = 'zorin-magic-lamp-effect@zorinos.com'
DESKTOP_CUBE_EXTENSION = 'zorin-desktop-cube@zorinos.com'
SPATIAL_WINDOW_SWITCHER_EXTENSION = 'zorin-spatial-window-switcher@zorinos.com'


class Effects(Gtk.Box):

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

        self.selection_box.add(widgets.Switch(_('Enable animations'),
                               'org.gnome.desktop.interface',
                               'enable-animations'))
        
        if WINDOW_MOVE_EFFECT_EXTENSION in installed_extensions: # The window move extension is the important one
            self.selection_box.add(widgets.SwitchExtension([WINDOW_MOVE_EFFECT_EXTENSION, MAGIC_LAMP_EFFECT_EXTENSION],
                                                           _('Jelly Mode')))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)

class SpatialDesktop(Gtk.Box):

    def __init__(self):
        Gtk.Box.__init__(
            self,
            orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            )

        self.selection_frame = Gtk.Frame()
        self.selection_box = Gtk.ListBox()
        self.selection_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.selection_box.set_header_func(listbox.list_box_update_header_func,
                None)

        if DESKTOP_CUBE_EXTENSION in installed_extensions:
            tiling_assistant_extension = environment._get_shell_extension(DESKTOP_CUBE_EXTENSION)
            tiling_assistant_prefs = os.path.join(tiling_assistant_extension['path'], "prefs.js")
            if os.path.exists(tiling_assistant_prefs):
                self.selection_box.add(widgets.ExtensionSwitchPrefsButton(
                                       tiling_assistant_extension,
                                       _('Desktop Cube'),
                                       _('Switch between workspaces in 3D')))

        if SPATIAL_WINDOW_SWITCHER_EXTENSION in installed_extensions:
            self.selection_box.add(widgets.SwitchExtension([SPATIAL_WINDOW_SWITCHER_EXTENSION],
                                                           _('Spatial Window Switcher'),
                                                           _('Replaces Alt+Tab and Super+Tab with a 3D window switcher')))

        self.selection_frame.add(self.selection_box)
        self.add(self.selection_frame)
