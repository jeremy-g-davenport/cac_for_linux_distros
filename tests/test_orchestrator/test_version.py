import re
import sys
import os
import unittest

# Allow importing version.py from the repo root regardless of working directory
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import version


class TestVersion(unittest.TestCase):
    def test_version_format(self):
        self.assertRegex(
            version.__version__,
            r"^\d+\.\d+\.\d+$",
            f"version.__version__ {version.__version__!r} does not match X.Y.Z",
        )


if __name__ == "__main__":
    unittest.main()
