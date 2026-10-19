'''apport package hook for pipewire

(c) 2025 Canonical Ltd.
Author: Charles <charles05@canonical.com>
'''

import os
from apport.hookutils import (
    attach_alsa,
    attach_conffiles,
    command_available,
    command_output
)

def add_info(report, ui):
    attach_alsa(report)
    attach_conffiles(report, 'pipewire')
    attach_conffiles(report, 'wireplumber')

    # Collect the journal logs, with debug logging enabled if the
    # problem is reproducible.
    if command_available('wpctl'):
        response = ui.choice(
            """A problem has been found with the Pipewire sound server.

If you know how reproduce this issue, additional debug logging can be temporarily enabled
for Pipewire to help triage the bug you are about to report.

Enable debug logging and manually reproduce?
""",
            [
                "Yes, enable the logging, I will reproduce the issue",
                "No, I can't easily reproduce it"
            ],
            False,
        )

        # Only expect exactly one answer
        if response is None or len(response) != 1:
            return

        if response[0] == 0:
            os.popen("wpctl set-log-level D ; wpctl set-log-level 0 4")
            response = ui.information(
                """Debug logging enabled.
Please reproduce the issue and then close this window."""
            )
            os.popen("wpctl set-log-level - ; wpctl set-log-level 0 -")

    if command_available('journalctl'):
        report['PipewireJournal'] = command_output(['journalctl', '-b',
                                                    '--user-unit=pipewire',
                                                    '--user-unit=wireplumber',
                                                    '--user-unit=pipewire-pulse',
                                                    '-o', 'short-monotonic'])

    if command_available('pactl'):
        report['PactlListSinks'] = command_output(['pactl', 'list', 'sinks'])
    if command_available('wpctl'):
        report['WpctlStatus'] = command_output(['wpctl', 'status'])
    if command_available('pw-cli'):
        report['PipewireNodes'] = command_output(['pw-cli', 'list-objects', 'Node'])
    if command_available('pw-dump'):
        report['PipewireDump'] = command_output(['pw-dump', '-N'])
