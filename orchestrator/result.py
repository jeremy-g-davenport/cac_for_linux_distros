from dataclasses import dataclass


@dataclass
class BashResult:
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0
