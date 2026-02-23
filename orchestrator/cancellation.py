import threading


class CancellationError(Exception):
    """Raised when the user requests cancellation."""


class CancellationToken:
    def __init__(self):
        self._event = threading.Event()

    def set(self):
        self._event.set()

    def is_set(self) -> bool:
        return self._event.is_set()

    def check(self):
        """Raise CancellationError if cancellation was requested."""
        if self._event.is_set():
            raise CancellationError("Operation cancelled by user")
