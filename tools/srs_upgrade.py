#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.19.0 — the framework release this file came from
"""Upgrade SRS-DD in this project — one command, no clone to keep around.

    python3 tools/srs_upgrade.py              show the change, then ask
    python3 tools/srs_upgrade.py --yes        apply without asking
    python3 tools/srs_upgrade.py --ref v1.2.0 pin a release
    python3 tools/srs_upgrade.py --from ../srs-dd   use a clone you have
    python3 tools/srs_upgrade.py --grounds yes     add the grounds register
    python3 tools/srs_upgrade.py --arch yes        add the architecture layer

It fetches the framework this project was installed from, runs that
framework's installer against this project, and removes what it fetched.
Nothing is written before the version transition, the upgrade notes and
the file list have been printed.

Where the framework lives is read from `framework_url` in
`specs/srs-config.json`; projects installed before that field existed fall
back to the address below. Only `git` and Python 3.9+ are needed.

Exit codes match the installer: 0 installed · 1 checker errors or partial
completion · 2 refused before changing anything · 3 rolled back.
"""

# annotation removed on install

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "specs", "srs-config.json")

# Used when the project's config does not name one — projects installed
# before a project recorded the framework it came from, and hand-made
# installations.
DEFAULT_URL = "https://github.com/CRELLIA-S-L/srs-dd.git"


def fail(message, code=2):
    sys.stderr.write("srs-upgrade: %s\n" % message)
    return code


def framework_url():
    try:
        with open(CONFIG, "r", encoding="utf-8") as handle:
            value = json.load(handle).get("framework_url", "")
    except (OSError, ValueError):
        value = ""
    return value or DEFAULT_URL


def installer_of(clone):
    return os.path.join(clone, "tools", "srs_init.py")


def run_installer(clone, extra):
    """Runs the framework's installer against this project."""
    command = [sys.executable, installer_of(clone), ROOT, "--defaults"] + extra
    return subprocess.call(command)


def main():
    parser = argparse.ArgumentParser(
        description="Upgrade the SRS-DD framework in this project.")
    parser.add_argument("--yes", action="store_true",
                        help="apply without asking (required when stdin is "
                             "not a terminal)")
    parser.add_argument("--ref", metavar="REF",
                        help="branch or tag to fetch, e.g. v1.2.0")
    parser.add_argument("--from", dest="source", metavar="PATH",
                        help="use an existing framework clone instead of "
                             "fetching one")
    parser.add_argument("--force", action="store_true",
                        help="also refresh precious files (CI config, agent "
                             "guides, .gitattributes, the hook)")
    # annotation removed on install
    # Asking has to be possible with the command a project actually has.
    # Without this the only way to add the register is the framework
    # clone's own installer, which is the thing this tool exists to spare
    # anyone from keeping around.
    parser.add_argument("--period", choices=("month", "quarter", "year"),
                        default=None,
                        help="with --grounds yes: the calendar unit the "
                             "register's dashboard counts arrivals in "
                             "(default quarter)")
    parser.add_argument("--grounds", choices=("yes", "no"), default=None,
                        help="add the grounds register to this project, or "
                             "say no. Left out, an upgrade refreshes a "
                             "register that is already here and installs "
                             "none where there is not")
    parser.add_argument("--arch", choices=("yes", "no"), default=None,
                        help="add the architecture layer to this project, or "
                             "say no. The same promise the register makes: "
                             "left out, an upgrade refreshes a layer that is "
                             "already here and installs none where there is "
                             "not")
    args = parser.parse_args()

    if not os.path.isdir(os.path.join(ROOT, "specs")):
        return fail("no specs/ next to tools/ — run this from inside a "
                    "project SRS-DD is installed in")
    if os.path.isdir(os.path.join(ROOT, "skeleton")) \
            and os.path.exists(os.path.join(ROOT, "tools", "srs_init.py")):
        return fail("this looks like the framework repository itself, which "
                    "upgrades with `git pull`")

    if args.source and args.ref:
        return fail("--ref decides what to fetch, and --from fetches "
                    "nothing; drop one of them")

    if args.source:
        clone = os.path.abspath(args.source)
        temporary = None
        if not os.path.exists(installer_of(clone)):
            return fail("%s is not a framework clone: no tools/srs_init.py"
                        % clone)
    else:
        if not shutil.which("git"):
            return fail("git not found, and it is how the framework is "
                        "fetched; or point at a clone with --from")
        url = framework_url()
        temporary = tempfile.mkdtemp(prefix="srs-dd-")
        clone = os.path.join(temporary, "srs-dd")
        command = ["git", "clone", "--quiet", "--depth", "1"]
        if args.ref:
            command += ["--branch", args.ref]
        command += [url, clone]
        sys.stdout.write("Fetching %s%s\n"
                         % (url, " at %s" % args.ref if args.ref else ""))
        if subprocess.call(command) != 0:
            shutil.rmtree(temporary, ignore_errors=True)
            return fail("could not fetch %s" % url)

    try:
        extra = ["--force"] if args.force else []
        if args.grounds:
            extra += ["--grounds", args.grounds]
        if args.period:
            extra += ["--period", args.period]
        # annotation removed on install
        if args.arch:
            extra += ["--arch", args.arch]
        code = run_installer(clone, extra + ["--dry-run"])
        if code != 0:
            return fail("the framework's installer refused; nothing was "
                        "written", code)

        if not args.yes:
            if not sys.stdin.isatty():
                return fail("nothing was written. Re-run with --yes to apply "
                            "this without a terminal to confirm at")
            try:
                answer = input("\nApply this upgrade? [y/N] ").strip().lower()
            except EOFError:
                answer = ""
            if answer not in ("y", "yes"):
                sys.stdout.write("Nothing was written.\n")
                return 0

        return run_installer(clone, extra)
    finally:
        if temporary:
            shutil.rmtree(temporary, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
