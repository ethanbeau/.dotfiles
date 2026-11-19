"""Step both Zedokai themes through the installed contrast levels."""

import argparse
import os
import re
from pathlib import Path

BASES = ("Zedokai Light (Filter Sun)", "Zedokai Darker (Filter Spectrum)")
LEVELS = ("", " - Soft", " - Softer", " - Softest")


def adjust(settings: Path, direction: str) -> None:
    text = settings.read_text()
    step = 1 if direction == "down" else -1
    for base in BASES:
        pattern = re.compile(
            r'("(?:light|dark)"\s*:\s*")'
            + re.escape(base)
            + r"(?P<suffix> - Softest| - Softer| - Soft)?"
            + r'(")'
        )

        def replace(match: re.Match[str], base: str = base) -> str:
            level = LEVELS.index(match["suffix"] or "")
            level = max(0, min(len(LEVELS) - 1, level + step))
            return match[1] + base + LEVELS[level] + match[3]

        text = pattern.sub(replace, text)
    if text != settings.read_text():
        settings.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("direction", choices=("down", "up"))
    args = parser.parse_args()
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    adjust(config / "zed/settings.json", args.direction)


if __name__ == "__main__":
    main()
