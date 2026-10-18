# This file is part of the Zorin Appearance program.
#
# Copyright 2016-2026 Zorin OS Technologies Ltd.
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
import zorin_appearance.Layouts.layout as layout
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gio, GLib


class GnomeShell(layout.Layout, Gtk.Box):

    __metaclass__ = layout.LayoutBox

    environment = 'zorin:GNOME'

    def __init__(self):
        Gtk.Box.__init__(self)

        self.enabled_extensions = ['add-to-desktop@tommimon.github.com']
        self.disabled_extensions = [
            'apps-menu@gnome-shell-extensions.gcampax.github.com',
            'places-menu@gnome-shell-extensions.gcampax.github.com',
            'zorin-dash@zorinos.com',
            'zorin-menu@zorinos.com',
            'zorin-taskbar@zorinos.com',
            'zorin-hide-activities-move-clock@zorinos.com']
        self.settings = [
            ('org.gnome.desktop.wm.preferences', 'button-layout',
             GLib.Variant('s', 'appmenu:minimize,maximize,close')),
            ('org.gnome.desktop.interface', 'enable-hot-corners',
             GLib.Variant('b', True)),
            ('org.gnome.desktop.interface', 'zorin-display-overview-on-startup',
             GLib.Variant('b', True)),
            ('org.gnome.nautilus.preferences', 'click-policy',
             GLib.Variant('s', 'double'))
            ]

        preview = Gtk.DrawingArea()
        preview.connect('draw', self.draw_layout_preview)
        preview.set_size_request(layout.LAYOUT_PREVIEW_WIDTH,
                                 layout.LAYOUT_PREVIEW_HEIGHT)

        self.pack_start(preview, True, False, 0)

    def draw_layout_preview(self, widget, cr):
        style_context = widget.get_style_context()
        color = style_context.get_color(Gtk.StateFlags.NORMAL)
        cr.set_source_rgba(*color)

        # Outline
        cr.set_line_width(2)
        cr.rectangle(1, 1, layout.LAYOUT_PREVIEW_WIDTH - 2,
                     layout.LAYOUT_PREVIEW_HEIGHT - 2)
        cr.stroke()

        # Top panel
        cr.set_line_width(2)
        cr.move_to(2, 9)
        cr.line_to(layout.LAYOUT_PREVIEW_WIDTH - 2, 9)
        cr.stroke()
        cr.move_to(0, 0)

        # Top panel activities
        cr.rectangle(4, 4, 4, 2)
        cr.fill()

        # Top panel time
        cr.rectangle(layout.LAYOUT_PREVIEW_WIDTH / 2 - 5, 4, 10, 2)
        cr.fill()

        # Top panel indicators
        cr.rectangle(layout.LAYOUT_PREVIEW_WIDTH - 34, 4, 30, 2)
        cr.fill()

        # Workspace 1
        cr.set_line_width(2)
        cr.rectangle(0, round(layout.LAYOUT_PREVIEW_HEIGHT / 2) - 39, 19, 86)
        cr.stroke()

        # Workspace 2
        cr.set_line_width(2)
        cr.rectangle(round(layout.LAYOUT_PREVIEW_WIDTH / 2) - 79,
                     round(layout.LAYOUT_PREVIEW_HEIGHT / 2) - 45, 159, 98)
        cr.stroke()

        # Workspace 3
        cr.set_line_width(2)
        cr.rectangle(layout.LAYOUT_PREVIEW_WIDTH - 19,
                     round(layout.LAYOUT_PREVIEW_HEIGHT / 2) - 39, 19, 86)
        cr.stroke()
