"""
worker.py — Phase 2 QThread bridge (placeholder).

InstallerWorker wraps run_setup() for use in a PyQt6 QThread.
The main/UI thread never calls the orchestrator directly;
communication uses Qt signals only.

This file is designed in Phase 1 and implemented fully in Phase 2.
Importing it in Phase 1 does not require PyQt6 to be installed.
"""
from __future__ import annotations

# Phase 2 implementation note:
#
#   from PyQt6.QtCore import QThread, pyqtSignal
#
#   class InstallerWorker(QThread):
#       progress_signal = pyqtSignal(str)
#       phase_signal = pyqtSignal(str)
#       error_signal = pyqtSignal(str)
#       done_signal = pyqtSignal(bool)
#
#       def __init__(self, driver, sudo_user, cancel_token):
#           super().__init__()
#           self._driver = driver
#           self._sudo_user = sudo_user
#           self._cancel_token = cancel_token
#
#       def run(self):
#           from .setup_flow import run_setup
#           from .cancellation import CancellationError
#           try:
#               run_setup(
#                   self._driver,
#                   self._sudo_user,
#                   cancel_token=self._cancel_token,
#                   progress_cb=self.progress_signal.emit,
#                   phase_cb=self.phase_signal.emit,
#               )
#               self.done_signal.emit(True)
#           except CancellationError:
#               self.done_signal.emit(False)
#           except Exception as exc:
#               self.error_signal.emit(str(exc))
#               self.done_signal.emit(False)
