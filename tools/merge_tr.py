#!/usr/bin/env python3
"""Fügt Übersetzungen in einen Katalog ein.

Aufruf: python3 tools/merge_tr.py fr <<'EOF'
Weizen|Blé
Bäckerei|Boulangerie
EOF

Jede Zeile ist `deutscher Text|Übersetzung`. Der Katalog liegt als JSON unter
locale/<sprache>.json. Zeilen ohne `|` werden ignoriert, sodass Kommentare und
Leerzeilen erlaubt sind.
"""
import json
import sys

KEYS = {"\\n": "\n"}


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("Sprache fehlt: merge_tr.py <sprache>")
    locale = sys.argv[1]
    path = f"locale/{locale}.json"
    try:
        with open(path, encoding="utf-8") as handle:
            catalog = json.load(handle)
    except FileNotFoundError:
        catalog = {}

    added = 0
    for line in sys.stdin.read().split("\n"):
        line = line.rstrip("\r")
        if "|" not in line or line.lstrip().startswith("#"):
            continue
        key, value = line.split("|", 1)
        # Schlüssel dürfen mit einem Leerzeichen beginnen („ · %d fertig"),
        # deshalb nur rechts kürzen.
        key = key.rstrip()
        value = value.strip()
        if not key or not value:
            continue
        # Die beiden einzigen Texte mit Zeilenumbruch brauchen einen Platzhalter.
        key = key.replace("<br>", "\\n")
        value = value.replace("<br>", "\\n")
        catalog[key] = value
        added += 1

    with open(path, "w", encoding="utf-8") as handle:
        json.dump(dict(sorted(catalog.items())), handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"{path}: {len(catalog)} Einträge ({added} übernommen)")


if __name__ == "__main__":
    main()
