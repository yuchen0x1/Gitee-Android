"""Extract a published version's notes from the canonical release history."""

import argparse
import re
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    version = args.version[1:] if args.version.startswith("v") else args.version
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        parser.error("version must have the form v1.2.3 or 1.2.3")
    source = Path(__file__).resolve().parents[1] / "docs/releases/release-notes.md"
    text = source.read_text(encoding="utf-8")
    headings = list(re.finditer(r"^## \[([^\]]+)\].*$", text, re.MULTILINE))
    matches = [(index, heading) for index, heading in enumerate(headings)
               if heading.group(1) == version]
    if len(matches) != 1:
        parser.error(f"expected exactly one release entry for {version}")
    index, heading = matches[0]
    end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
    notes = text[heading.end():end].strip()
    if not notes:
        parser.error(f"release entry for {version} is empty")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        output.write(notes + "\n")


if __name__ == "__main__":
    main()
