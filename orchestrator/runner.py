"""
runner.py — Subprocess wrappers for Bash execution units.

stream_bash() is the Phase 2 GUI reuse hook: the GUI calls this function
and consumes the yielded line generator to drive a progress widget.
"""
from __future__ import annotations

import subprocess
import time
from pathlib import Path
from typing import TYPE_CHECKING, Iterator

from .cancellation import CancellationError, CancellationToken
from .result import BashResult

if TYPE_CHECKING:
    pass


def run_bash(
    script: Path,
    *args: str,
    env: dict | None = None,
    cancel_token: CancellationToken | None = None,
) -> BashResult:
    """Blocking subprocess call. Polls cancel_token every 50 ms."""
    with subprocess.Popen(
        ["/bin/bash", str(script), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    ) as proc:
        if cancel_token:
            while proc.poll() is None:
                if cancel_token.is_set():
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait()
                    raise CancellationError("Operation cancelled")
                time.sleep(0.05)
        stdout, stderr = proc.communicate()
        return BashResult(proc.returncode, stdout, stderr)


def stream_bash(
    script: Path,
    *args: str,
    env: dict | None = None,
    cancel_token: CancellationToken | None = None,
) -> Iterator[str]:
    """Yields stdout lines as they arrive. Phase 2 GUI reuse hook."""
    with subprocess.Popen(
        ["/bin/bash", str(script), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    ) as proc:
        for line in proc.stdout:
            if cancel_token and cancel_token.is_set():
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                raise CancellationError("Operation cancelled")
            yield line.rstrip()
        proc.wait()
        if proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, script)
