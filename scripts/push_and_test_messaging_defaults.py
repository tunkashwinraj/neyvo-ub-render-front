"""
Launcher: runs the backend script from GU_Neyvo_Back so you can run from GU_Neyvo_Front.

Usage (from GU_Neyvo_Front or anywhere):
  python scripts/push_and_test_messaging_defaults.py --dry-run
  python scripts/push_and_test_messaging_defaults.py --base-url https://neyvoub-back.onrender.com --crud-only
"""

from __future__ import annotations

import os
import subprocess
import sys


def _backend_script() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    # GU_Neyvo_Front/scripts -> GU_Neyvo_Front -> Neyvo_GU -> GU_Neyvo_Back/scripts/...
    front = os.path.dirname(here)
    neyvo_gu = os.path.dirname(front)
    return os.path.join(
        neyvo_gu,
        "GU_Neyvo_Back",
        "scripts",
        "push_and_test_messaging_defaults.py",
    )


def main() -> int:
    target = _backend_script()
    if not os.path.isfile(target):
        print(
            f"Backend script not found:\n  {target}\n"
            "Clone GU_Neyvo_Back next to GU_Neyvo_Front (same parent folder as Neyvo_GU).",
            file=sys.stderr,
        )
        return 2
    return subprocess.call([sys.executable, target] + sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
