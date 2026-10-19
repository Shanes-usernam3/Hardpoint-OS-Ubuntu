"""Apport package hook for the Linux kernel.

(c) 2008-2026 Canonical Ltd.
Contributors:
Matt Zimmerman <mdz@canonical.com>
Martin Pitt <martin.pitt@canonical.com>
Brian Murray <brian@canonical.com>
Juerg Haefliger <juerg.haefliger@canonical.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.  See http://www.gnu.org/copyleft/gpl.html for
the full text of the license.
"""

import glob
import os
import re

import apport
import apport.hookutils


def is_ubuntu_kernel(report, ui):
    """Check if the running kernel is an Ubuntu kernel."""
    # If running an upstream kernel, instruct reporter to file bug upstream
    abi = re.search("-(.*?)-", report["Uname"])
    if abi and (abi.group(1) == "999" or re.search("^0\\d", abi.group(1))):
        ui.information(
            "It appears you are currently running a mainline kernel.  It would"
            " be better to report this bug upstream at"
            " http://bugzilla.kernel.org/ so that the upstream kernel"
            " developers are aware of the issue.  If you'd still like to file"
            " a bug against the Ubuntu kernel, please boot with an official"
            " Ubuntu kernel and re-file."
        )
        report["UnreportableReason"] = "The running kernel is not an Ubuntu kernel."
        return False

    version_signature = report.get("ProcVersionSignature", "")
    if not version_signature.startswith("Ubuntu ") and "CrashDB" not in report:
        report["UnreportableReason"] = "The running kernel is not an Ubuntu kernel."
        return False

    return True


def attach_data(report, _ui):
    """Attach relevant data for kernel problems."""
    apport.hookutils.attach_hardware(report)
    apport.hookutils.attach_alsa(report)
    apport.hookutils.attach_wifi(report)
    apport.hookutils.attach_file(report, "/proc/fb", "ProcFB")

    apport.hookutils.attach_file_if_exists(
        report, "/etc/initramfs-tools/conf.d/resume", key="HibernationDevice"
    )

    # Attach the list of installed packages
    report["DpkgList"] = apport.hookutils.command_output(["dpkg", "--list"])


def check_for_staging_drivers(report, _ui):
    """Scan the kernel log for loaded staging drivers."""
    staging_drivers = re.findall(
        "(\\w+): module is from the staging directory", report["CurrentDmesg"]
    )
    if staging_drivers:
        staging_drivers = list(set(staging_drivers))
        report["StagingDrivers"] = " ".join(staging_drivers)
        report["Tags"] += " staging"
        # Only if there is an existing title prepend '[STAGING]'.
        # Changed to prevent bug titles with just '[STAGING] '.
        if report.get("Title"):
            report["Title"] = "[STAGING] " + report.get("Title")


def add_duplicate_crash_signature(report, _ui):
    """Add crash signature for duplicate checks."""
    if "Failure" in report and (
        "resume" in report["Failure"] or "suspend" in report["Failure"]
    ):
        crash_signature = report.crash_signature()
        if crash_signature:
            report["DuplicateSignature"] = crash_signature


def is_dkms_build_failure(report, ui):
    """Check if the trigger is a DKMS build failure."""
    if report.get("ProblemType", "") != "Package":
        return False

    # Collect the DKMS build logs. We only consider the first log. There should
    # only be one anyways, right??
    build_logs = glob.glob("/var/lib/dkms/*/*/build/make.log")
    if not build_logs:
        return False
    build_log = build_logs[0]

    dkms_source = os.path.realpath(
        os.path.join(os.path.dirname(build_log), os.pardir, "source")
    )
    package = apport.packaging.get_file_package(dkms_source)
    if package and apport.packaging.is_distro_package(package):
        # This is a build failure from an offical DKMS, redirect the report there
        report.add_package_info(package)
        report["DkmsStatus"] = apport.hookutils.command_output(["dkms", "status"])
        apport.hookutils.attach_file(report, build_log, "dkms-make.log")
        return True

    # Unofficial DKMS build failure, reject the report.
    ui.information(
        "It appears you have an unofficial third-party DKMS module installed that"
        " fails to build for at least one of your installed kernels. You need to"
        " remove this module or the installation of kernel headers packages will"
        " continue to fail. You should also report this to the provider of the"
        f" DKMS module. See {build_log} for details about the build failure."
    )
    report["UnreportableReason"] = (
        "The failing DKMS module is not an Ubuntu DKMS module."
    )
    return True


def is_aborted_kernel_removal(report, _ui):
    """Check if the trigger is an aborted removal of the running kernel."""
    if report.get("ProblemType", "") != "Package":
        return False

    dpkg_log = report.get("DpkgTerminalLog.txt")
    if dpkg_log and "E: Aborting removal of the running kernel" in "".join(dpkg_log):
        report["UnreportableReason"] = (
            "The user aborted the removal of the running kernel."
        )
        return True

    return False


def add_info(report, ui):
    """Add information for the Linux kernel."""
    report.setdefault("Tags", "")

    if not is_ubuntu_kernel(report, ui):
        return

    if is_aborted_kernel_removal(report, ui):
        return

    if is_dkms_build_failure(report, ui):
        return

    # Prevent reports against the linux-meta and linux-signed families,
    # redirect to the main package.
    for src_pkg in ("linux-meta", "linux-signed"):
        if report["SourcePackage"].startswith(src_pkg):
            report["SourcePackage"] = report["SourcePackage"].replace(
                src_pkg, "linux", 1
            )

    # Attach kernel-relevant data to the report
    attach_data(report, ui)

    # Check the kernel log if staging drivers are loaded
    check_for_staging_drivers(report, ui)

    # Add crash signature for duplicate checks
    add_duplicate_crash_signature(report, ui)


## DEBUGGING ##
if __name__ == "__main__":
    import sys

    r = apport.Report()
    r.add_proc_info()
    r.add_os_info()
    try:
        r["SourcePackage"] = sys.argv[1]
    except IndexError:
        r["SourcePackage"] = "linux"
    r["ProcVersionSignature"] = "Ubuntu 3.4.0"
    add_info(r, None)
    for k, v in r.items():
        print(f"[{k}]\n{v}")
