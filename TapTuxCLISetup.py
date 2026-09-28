#!/usr/bin/env python3
"""
TapTuxCLISetup
================
The project's first-run entry point - run this once, directly
(`python3 TapTuxCLISetup.py`), before ever using `taptux`. It vendors
a shared, TapTux-owned Python interpreter (see PythonVendoring's own
module docstring) and installs the `taptux` command on Termux's PATH,
pointed permanently at TapTux.py - the ongoing picker, which is
deliberately NOT a first-run entry point itself any more (see its own
module docstring for that split and why it exists).

This does exactly that, plus creating the two directories `install`
needs (InstalledContainers, DownloadedContainers), and nothing else -
no environment gets installed here, automatically or otherwise.
`taptux cli` (or `taptux --cli`, equivalent) is what brings up the
picker once this finishes; installing any actual environment from
there is always a deliberate, manual `install` (see TapTux.py's
InstallEnvironment()) - this file's only job is making that command
exist and work, independently of whatever anyone does with it after.

Safe to re-run any time (e.g. if the `taptux` command ever gets lost
or hand-edited) - every step here is idempotent; re-running after
everything's already set up is just a fast no-op confirmation.
"""

from __future__ import annotations

import sys
from pathlib import Path

ScriptRoot = Path(__file__).resolve().parent
sys.path.insert(0, str(ScriptRoot))
import PythonVendoring  # noqa: E402
import RemoteEnvironmentCatalog  # noqa: E402

ContainersRootValue = Path("/data/data/com.termux/files/usr/var/lib/TapTux/InstalledContainers")
DownloadedContainersRootValue = ContainersRootValue.parent / "DownloadedContainers"


def Main() -> None:
    PythonVendoring.EnsureNotOnExternalStorage(ScriptRoot)

    # Re-execs into exactly this script (see EnsureSharedInterpreterAndCommand's
    # own docstring) until we're actually running under the shared vendored
    # interpreter - so a fresh device lands back here for a second, final
    # pass rather than this function ever silently failing to finish. The
    # `taptux` command it installs always targets TapTux.py, never this file.
    PythonVendoring.EnsureSharedInterpreterAndCommand(
        ReExecScriptPath=Path(__file__).resolve(),
        TapTuxCommandTargetPath=ScriptRoot / "TapTux.py",
    )

    print()
    print("Setting up storage...")
    ContainersRootValue.mkdir(parents=True, exist_ok=True)
    DownloadedContainersRootValue.mkdir(parents=True, exist_ok=True)
    print(f"  Installed environments:  {ContainersRootValue}")
    print(f"  Downloaded packages:     {DownloadedContainersRootValue}")

    StateRoot = ContainersRootValue.parent
    HasToken = RemoteEnvironmentCatalog.LoadGithubToken(StateRoot) is not None

    print()
    print("=" * 60)
    print("Setup complete.")
    print("=" * 60)
    print()
    print("Run the picker any time with:")
    print("  taptux cli")
    print("  (or: taptux --cli)")
    print()
    print("Nothing is installed automatically - from the picker, `install`")
    print("downloads and sets up any environment you choose, yourself.")

    if not HasToken:
        TokenFile = RemoteEnvironmentCatalog.GithubTokenFilePath(StateRoot)
        EnvironmentVariable = RemoteEnvironmentCatalog.GithubTokenEnvironmentVariable
        Repository = f"{RemoteEnvironmentCatalog.RepositoryOwner}/{RemoteEnvironmentCatalog.RepositoryName}"
        print()
        print(f"Optional, for the picker's `install`/`refresh` to reach {Repository}:")
        print(f'  export {EnvironmentVariable}="..."')
        print(f"  (or write the token to: {TokenFile})")


if __name__ == "__main__":
    Main()
