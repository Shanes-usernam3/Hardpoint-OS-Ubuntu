# This file is part of the Zorin Appearance program.
#
# Copyright 2016-2024 Zorin OS Technologies Ltd.
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
import os
import sys

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gio, Gdk

from zorin_appearance import theme
from zorin_appearance import desktop
from zorin_appearance import fonts
from zorin_appearance import environment
from zorin_appearance import layout
from zorin_appearance import utils

if environment._shell_loaded:
    from zorin_appearance import interface
    from zorin_appearance import effects
    from zorin_appearance import windows

t = gettext.translation('zorin-appearance', '/usr/share/locale',
                        fallback=True)
_ = t.gettext

WINDOW_WIDTH = 838
WINDOW_HEIGHT = 589
if environment._shell_loaded:
	WINDOW_HEIGHT = 663
SIDEBAR_WIDTH = 172

ZORIN_APPEARANCE_GSETTINGS_PATH = "com.zorin.desktop.appearance"
# Check if Auto Theme schema is installed
if Gio.SettingsSchemaSource.get_default().lookup(ZORIN_APPEARANCE_GSETTINGS_PATH, True):
    ZORIN_APPEARANCE_SCHEMA = Gio.Settings.new(ZORIN_APPEARANCE_GSETTINGS_PATH)
else:
    ZORIN_APPEARANCE_SCHEMA = None

DOC_PATH = "/usr/share/doc"

class ZorinAppearance(Gtk.Window):

    def __init__(self):
        Gtk.Window.__init__(self)
        self.set_resizable(False)
        self.set_size_request(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_position(Gtk.WindowPosition.CENTER)

        icon = Gio.ThemedIcon(name='zorin-appearance')
        theme_icon = Gtk.IconTheme.get_default().lookup_by_gicon(icon,
                48, 0)
        image = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.DIALOG)
        if theme_icon:
            self.set_default_icon(theme_icon.load_icon())

        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        self.set_titlebar(hb)

        grid = Gtk.Grid()
        self.add(grid)

        self.stack = Gtk.Stack()
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_UP_DOWN)
        grid.attach(self.stack, 1, 0, 1, 1)

        stack_sidebar = Gtk.StackSidebar()
        stack_sidebar.set_stack(self.stack)
        stack_sidebar.set_size_request(SIDEBAR_WIDTH, -1)
        grid.attach(stack_sidebar, 0, 0, 1, 1)
        
        # Layout tab
        layout_scrolled = Gtk.ScrolledWindow()
        layout_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                              spacing=16)
        layout_box.set_border_width(16)
        layout_box.add(layout.Layouts())
        layout_scrolled.add(layout_box)
        if (
            ZORIN_APPEARANCE_SCHEMA != None and
            ZORIN_APPEARANCE_SCHEMA.get_boolean('show-more-layouts-message') == True and
            (environment._shell_loaded or environment._desktop_environment == 'XFCE') and
            (not os.path.isdir(os.path.join(DOC_PATH, 'zorin-appearance-layouts-shell-premium'))) and
            (not os.path.isdir(os.path.join(DOC_PATH, 'zorin-appearance-layouts-xfce-premium')))
        ):
            layout_box.add(layout.Upgrade(ZORIN_APPEARANCE_SCHEMA))
        self.stack.add_titled(layout_scrolled, 'layout', _('Layout'))
        
        # Theme tab
        theme_scrolled = Gtk.ScrolledWindow()
        theme_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                  Gtk.PolicyType.AUTOMATIC)
        theme_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                            spacing=16)
        theme_box.set_border_width(16)
        self.themes = theme.Themes()
        theme_box.add(self.themes)
        theme_scrolled.add(theme_box)
        self.stack.add_titled(theme_scrolled, 'theme', _('Theme'))

        # Effects tab
        if environment._shell_loaded:
            effects_scrolled = Gtk.ScrolledWindow()
            effects_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                      Gtk.PolicyType.AUTOMATIC)
            effects_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                  spacing=16)
            effects_box.set_border_width(16)
            effects_box.add(effects.Effects())
            
            spatial_desktop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                          spacing=12)
            spatial_desktop_label = Gtk.Label(margin_start=16, margin_end=16)
            spatial_desktop_label.set_markup("<b>" + _("Spatial Desktop") + "</b>")
            spatial_desktop_label.set_alignment(0,0)
            spatial_desktop_box.add(spatial_desktop_label)
            spatial_desktop_box.add(effects.SpatialDesktop())
            effects_box.add(spatial_desktop_box)

            effects_scrolled.add(effects_box)
            self.stack.add_titled(effects_scrolled, 'effects', _('Effects'))

        # Desktop tab
        desktop_scrolled = Gtk.ScrolledWindow()
        desktop_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                  Gtk.PolicyType.AUTOMATIC)
        desktop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                              spacing=16)
        desktop_box.set_border_width(16)

        if environment._shell_loaded:
            background_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                    spacing=12)
            background_label = Gtk.Label(margin_start=16, margin_end=16)
            background_label.set_markup("<b>" + _("Background") + "</b>")
            background_label.set_alignment(0,0)
            background_box.add(background_label)
            background_box.add(desktop.Background())
            desktop_box.add(background_box)

        icons_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                            spacing=12)
        icons_label = Gtk.Label(margin_start=16, margin_end=16)
        icons_label.set_markup("<b>" + _("Icons") + "</b>")
        icons_label.set_alignment(0,0)
        icons_box.add(icons_label)
        icons_box.add(desktop.Icons())
        desktop_box.add(icons_box)

        desktop_scrolled.add(desktop_box)
        self.stack.add_titled(desktop_scrolled, 'desktop', _('Desktop'))

        # Windows tab
        if environment._shell_loaded:
            windows_scrolled = Gtk.ScrolledWindow()
            windows_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                        Gtk.PolicyType.AUTOMATIC)
            windows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                  spacing=16)
            windows_box.set_border_width(16)

            placement_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                           spacing=12)
            placement_label = Gtk.Label(margin_start=16, margin_end=16)
            placement_label.set_markup("<b>" + _("Placement") + "</b>")
            placement_label.set_alignment(0,0)
            placement_box.add(placement_label)
            placement_box.add(windows.Placement())
            windows_box.add(placement_box)

            titlebars_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                           spacing=12)
            titlebars_label = Gtk.Label(margin_start=16, margin_end=16)
            titlebars_label.set_markup("<b>" + _("Window Titlebars") + "</b>")
            titlebars_label.set_alignment(0,0)
            titlebars_box.add(titlebars_label)
            titlebars_box.add(windows.Titlebars())
            windows_box.add(titlebars_box)

            focus_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                           spacing=12)
            focus_label = Gtk.Label(margin_start=16, margin_end=16)
            focus_label.set_markup("<b>" + _("Focus") + "</b>")
            focus_label.set_alignment(0,0)
            focus_box.add(focus_label)
            focus_box.add(windows.Focus())
            windows_box.add(focus_box)

            windows_scrolled.add(windows_box)
            self.stack.add_titled(windows_scrolled, 'windows', _('Windows'))

        # Interface tab
        if environment._shell_loaded:
            interface_scrolled = Gtk.ScrolledWindow()
            interface_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                          Gtk.PolicyType.AUTOMATIC)
            interface_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                    spacing=16)
            interface_box.set_border_width(16)
            interface_box.add(interface.Interface())
            interface_scrolled.add(interface_box)
            self.stack.add_titled(interface_scrolled, 'interface', _('Interface'))

        # Fonts tab
        fonts_scrolled = Gtk.ScrolledWindow()
        fonts_scrolled.set_policy(Gtk.PolicyType.NEVER,
                                  Gtk.PolicyType.AUTOMATIC)
        fonts_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            border_width=16,
            )
        fonts_box.add(fonts.Fonts())
        fonts_scrolled.add(fonts_box)
        self.stack.add_titled(fonts_scrolled, 'fonts', _('Fonts'))

        self.show()


class ZorinAppearanceApplication(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.zorin.desktop.appearance")
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(utils.APP_DATA_PATH + 'css/application.css')
        screen = Gdk.Screen.get_default()
        style_context = Gtk.StyleContext()
        style_context.add_provider_for_screen(screen, css_provider,
                                              Gtk.STYLE_PROVIDER_PRIORITY_USER)
        self.window = None

    def do_startup(self):
        Gtk.Application.do_startup(self)

        action = Gio.SimpleAction.new("quit", None)
        action.connect("activate", self.on_quit)
        self.add_action(action)

    def do_activate(self):
        if not self.window:
            self.window = ZorinAppearance()
            self.window.set_application(self)
            self.window.set_title(_('Zorin Appearance'))
            self.window.show_all()
            self.window.themes.zorin_themes.set_auto_theme_visibility()
            self.window.themes.set_active_page()

        if len(sys.argv) > 1:
            page_name = sys.argv[1]
            self.window.stack.set_visible_child_name(page_name)

        self.window.present()

    def on_quit(self, action, param):
        self.quit()

def main():
    app = ZorinAppearanceApplication()
    app.run(None)

if __name__ == '__main__':
    main()
