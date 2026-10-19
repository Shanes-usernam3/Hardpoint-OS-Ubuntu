#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Copyright (C) 2018 Lubuntu Developers <lubuntu-devel@lists.ubuntu.com>
# Authored by Walter Lapchynski <wxl@ubuntu.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# A copy of the GNU General Public License version 2 is in license.txt.

from apport.hookutils import *
import apport.packaging
from os.path import expanduser


module_path = "/etc/calamares/modules/"

module_names = [
        'after_bootloader_context',
        'automirror',
        'before_bootloader_context',
        'before_bootloader_mkdirs_context',
        'bootloader',
        'displaymanager',
        'finished',
        'fstab',
        'locale',
        'machineid',
        'mount',
        'packages',
        'partition',
        'shellprocess_logs',
        'unpackfs',
        'users',
        'welcome'
]

installed_modules = []

for module in module_names:
    installed_modules.append(module_path + module + ".conf")

log_file = expanduser("~") + "/.cache/calamares/session.log"

config_file = "/etc/calamares/settings.conf"

requested_files = tuple([log_file] + [config_file] + installed_modules)

msg = ' '.join((
        '\n\n'
        'The contents of the files attached to this report will help',
        'developers diagnose your bug more quickly. It may be possible',
        'that there is sensitive information in these files.'
        '\n\n'
        'You will be able to review these attachments before they are',
        'sent. Do you want to include these files?',
))

related_packages = [
        'calamares-settings-ubuntu-common',
        'calamares-settings-lubuntu',
        'xfsprogs',
        'btrfs-progs'
]


def add_info(report, ui):
    attach_files = False
    problem_type = report.get('ProblemType', '')

    if problem_type == 'Bug' and ui:
        if ui.yesno(msg) is None:
            # user decided to cancel
            raise StopIteration

        # user is allowing files to be attached
        attach_files = True

    elif problem_type == 'Crash':
        # crash bugs are private by default
        attach_files = True

    if attach_files is False:
        return

    for requested_file in requested_files:
        attach_file_if_exists(report, requested_file)

    attach_related_packages(report, related_packages)
