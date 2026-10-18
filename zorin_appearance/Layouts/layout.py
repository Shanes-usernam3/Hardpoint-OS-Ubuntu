# This file is part of the Zorin Appearance program.
#
# Copyright 2016-2025 Zorin OS Technologies Ltd.
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
from abc import ABCMeta, abstractmethod
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gio, GLib
from zorin_appearance import environment, utils

LAYOUT_PREVIEW_WIDTH = 225
LAYOUT_PREVIEW_HEIGHT = 160

if environment._shell_loaded:
    EXTENSION_ENABLED = 1
    EXTENSION_DISABLED = 0
    STANDARD_EXTENSIONS = ['user-theme@gnome-shell-extensions.gcampax.github.com',
                           'drive-menu@gnome-shell-extensions.gcampax.github.com',
                           'zorin-appindicator@zorinos.com',
                           'zorin-printers@zorinos.com']
elif environment._desktop_environment == 'XFCE':
    from zorin_appearance import xfconf
    XFCONF = xfconf.XfconfSetting()


class Layout:

    __metaclass__ = ABCMeta

    @abstractmethod
    def draw_layout_preview(self, widget, cr):
        pass

    @abstractmethod
    def on_clicked(self):
        if self.environment == 'zorin:GNOME':
            schema = Gio.Settings.new('org.gnome.shell')
            schema.delay()

            enabled_extensions = schema.get_strv("enabled-extensions")
            disabled_extensions = schema.get_strv("disabled-extensions")
            for extension in self.disabled_extensions:
                while extension in enabled_extensions:
                    enabled_extensions.remove(extension)
                if extension not in disabled_extensions:
                    disabled_extensions.append(extension)
            for extension in self.enabled_extensions:
                if extension not in enabled_extensions:
                    enabled_extensions.append(extension)
                while extension in disabled_extensions:
                    disabled_extensions.remove(extension)
            for extension in STANDARD_EXTENSIONS:
                if extension not in enabled_extensions:
                    enabled_extensions.append(extension)
                while extension in disabled_extensions:
                    disabled_extensions.remove(extension)

            schema.set_strv("enabled-extensions", enabled_extensions)
            schema.set_strv("disabled-extensions", disabled_extensions)
            schema.apply()

            settings_schemas = {}
            for setting in self.settings:
                if setting[0] not in settings_schemas:
                    setting_schema = Gio.Settings.new(setting[0])
                    setting_schema.delay()
                    settings_schemas[setting[0]] = setting_schema
                
                settings_schemas[setting[0]].set_value(setting[1], setting[2])

            for settings_schema in settings_schemas.values():
                settings_schema.apply()

            # Make sure extensions are enabled
            schema.set_value('disable-user-extensions',
                             GLib.Variant('b', False))
            schema.apply()
        elif self.environment == 'XFCE':
            for setting in self.settings:
                XFCONF.xfconf.SetProperty(setting[0], setting[1],
                        setting[2])

            session_bus = Gio.BusType.SESSION
            conn = Gio.bus_get_sync(session_bus, None)

            destination = 'org.xfce.Panel'
            path = '/org/xfce/Panel'
            interface = destination

            dbus_proxy = Gio.DBusProxy.new_sync(
                conn,
                0,
                None,
                destination,
                path,
                interface,
                None,
                )

            dbus_proxy.call_sync('Terminate', GLib.Variant('(b)',
                                 ('xfce4-panel', )), 0, -1, None)

    @abstractmethod
    def is_current_layout(self):
        if self.environment == 'zorin:GNOME':
            for setting in self.settings:
                if setting[0] in Gio.Settings.list_schemas():
                    schema = Gio.Settings.new(setting[0])
                    if schema.get_value(setting[1]) != setting[2]:
                        return False
                else:
                    return False

            for extension in self.disabled_extensions:
                if environment._shell.extension_is_active(EXTENSION_ENABLED,
                        extension):
                    return False

            for extension in self.enabled_extensions:
                if environment._shell.extension_is_active(EXTENSION_DISABLED,
                        extension):
                    return False

            return True
        elif self.environment == 'XFCE':
            for setting in self.settings:
                if XFCONF.xfconf.PropertyExists(setting[0], setting[1]):
                    if XFCONF.xfconf.GetProperty(setting[0],
                            setting[1]) != setting[2]:
                        return False
                else:
                    return False

            return True


class LayoutBox(type(Gtk.Box), type(Layout)):

    pass
