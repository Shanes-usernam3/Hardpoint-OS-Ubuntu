# This file is part of the Zorin Appearance program.
#
# Copyright 2016-2021 Zorin OS Technologies Ltd.
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

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, Gio

from zorin_appearance import environment
from zorin_appearance import utils
from zorin_appearance.Layouts import *

t = gettext.translation('zorin-appearance', '/usr/share/locale', fallback=True)
_ = t.gettext


class Layouts(Gtk.Box):

    def __init__(self):
        Gtk.Box.__init__(self, orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            margin_bottom=16,
            )

        self.flowbox = Gtk.FlowBox()
        self.flowbox.set_valign(Gtk.Align.START)
        self.flowbox.set_row_spacing(32)
        self.flowbox.set_column_spacing(32)
        self.flowbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.flowbox.connect('child-activated', self.on_layout_changed)

        for interface_layout in layout.Layout.__subclasses__():
            if interface_layout.environment == environment._desktop_environment:
                self.flowbox.add(interface_layout())

        self.flowbox.connect('show', self.select_current_layout)

        self.pack_start(self.flowbox, True, True, 0)

    def create_layout_option(self, layout, image):
        selectable = Gtk.Box()
        selectable.pack_start(image, True, False, 0)

        return selectable

    def select_current_layout(self, flowbox):
        index = 0
        for interface_layout in self.flowbox.get_children():
            if interface_layout.get_child().is_current_layout():
                self.flowbox.select_child(interface_layout)
                return
            index += 1

        pass

    def on_layout_changed(self, box, child):
        child.get_child().on_clicked()


class Upgrade(Gtk.Box):

    def __init__(self, settings_schema):
        Gtk.Box.__init__(self, orientation=Gtk.Orientation.VERTICAL,
            spacing=16,
            margin_start=16,
            margin_end=16,
            margin_left=16,
            margin_right=16,
            margin_top=32,
            margin_bottom=0,
            )
            
        self.settings_schema = settings_schema
       
        title = Gtk.Label(_("Get more desktop layouts"))
        title.set_line_wrap(True)
        title.set_justify(Gtk.Justification.CENTER);
        title.set_valign(Gtk.Align.CENTER);
        title.get_style_context().add_class("title-text");
        self.add(title)

        image_name = "layout/shell-premium.svg"
        if environment._desktop_environment == 'XFCE':
            image_name = "layout/xfce-premium.svg"

        illustration_file = utils.APP_DATA_PATH + image_name
        illustration = Gtk.Image.new_from_file(illustration_file)
        illustration.set_halign(Gtk.Align.CENTER)
        illustration.set_valign(Gtk.Align.CENTER)
        self.add(illustration)

        upgrade_button_text = _("Upgrade to Zorin OS Pro")
        if environment._desktop_environment == 'XFCE':
            upgrade_button_text = _("Upgrade to Zorin OS Pro Lite")

        button_box = Gtk.Box(
                     orientation=Gtk.Orientation.HORIZONTAL,
                     spacing=12)
        upgrade_button = Gtk.Button(upgrade_button_text)
        upgrade_button.get_style_context().add_class("suggested-action");
        upgrade_button.connect("clicked", self.on_upgrade_button_clicked)
        button_box.add(upgrade_button)

        if environment._shell_loaded:
            learn_more_button = Gtk.Button(_("Learn More"))
            learn_more_button.connect("clicked", self.on_learn_more_button_clicked)
            button_box.add(learn_more_button)

        cta_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        cta_box.pack_start(button_box, True, False, 0)
        self.add(cta_box)
        
        hide_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, margin_top=8)
        hide_button = Gtk.Button(_("Don’t Show Again"))
        hide_button.connect("clicked", self.on_hide_button_clicked)
        hide_button.get_style_context().add_class("flat");
        hide_button.get_style_context().add_class("smaller-muted");
        hide_box.pack_start(hide_button, True, False, 0)
        self.add(hide_box)
        
    def on_upgrade_button_clicked(self, button):
        upgrader_desktop_id = "com.zorin.desktop.upgrader.desktop"
        app_info = None
        
        try:
            app_info = Gio.DesktopAppInfo.new(upgrader_desktop_id)
        except:
            pass

        if app_info is not None:
            app_info.launch([], None)
        else:
            Gio.AppInfo.launch_default_for_uri("https://zorin.com/os/pro/", None)
        
    def on_learn_more_button_clicked(self, button):
        Gio.AppInfo.launch_default_for_uri("https://zorin.com/os/pro/", None)
        
    def on_hide_button_clicked(self, button):
        self.settings_schema.set_boolean('show-more-layouts-message', False);
        self.hide()
