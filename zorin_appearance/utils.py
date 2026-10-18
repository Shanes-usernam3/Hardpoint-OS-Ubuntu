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
import os
import subprocess
import logging

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gio, GLib


APP_DATA_PATH = '/usr/share/zorin-appearance/'


def walk_directories(dirs, filter_func):
    valid = []
    try:
        for thdir in dirs:
            if os.path.isdir(thdir):
                for t in os.listdir(thdir):
                    if filter_func(os.path.join(thdir, t)):
                        valid.append(t)
    except:
        logging.critical('Error parsing directories', exc_info=True)
    return valid


def execute_subprocess(cmd_then_args, block=True):
    p = subprocess.Popen(
            cmd_then_args,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, close_fds=True,
            universal_newlines=True)
    if block:
        stdout, stderr = p.communicate()
        return stdout, stderr, p.returncode


def strtobool (val):
    val = val.lower()
    if val in ('y', 'yes', 't', 'true', 'on', '1'):
        return 1
    elif val in ('n', 'no', 'f', 'false', 'off', '0'):
        return 0
    else:
        raise ValueError("invalid truth value %r" % (val,))

def spawn_process(args=[]):
    return Gio.Subprocess.new(args, Gio.SubprocessFlags.NONE)
