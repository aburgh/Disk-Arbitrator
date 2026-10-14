#!/usr/bin/env python3
"""Clear unexpanded Sparkle Info.plist values so an empty build setting stays empty.

Xcode substitutes $(SPARKLE_FEED_URL) and $(SPARKLE_PUBLIC_ED_KEY) into
SUFeedURL and SUPublicEDKey. If a setting is missing, the built plist can keep
the literal $(...) text. Sparkle treats that as a broken key and shows its
missing-key alert. An empty string is the configured-off value: the app hides
update checks and does not start Sparkle.
"""

import os
import plistlib
import sys
import time


SPARKLE_KEYS = ("SUFeedURL", "SUPublicEDKey")


def normalized(value):
    if not isinstance(value, str):
        return ""
    stripped = value.strip()
    if not stripped or "$(" in stripped:
        return ""
    return value


def main(argv):
    if len(argv) < 2:
        print("usage: normalize_sparkle_info_plist.py INFO_PLIST [STAMP]", file=sys.stderr)
        return 2

    plist_path = argv[1]
    stamp_path = argv[2] if len(argv) > 2 else None
    deadline = time.time() + 10
    while not os.path.isfile(plist_path):
        if time.time() >= deadline:
            print(f"error: Sparkle Info.plist not found at {plist_path}", file=sys.stderr)
            return 1
        time.sleep(0.25)

    with open(plist_path, "rb") as handle:
        raw = handle.read()
    fmt = plistlib.FMT_BINARY if raw.startswith(b"bplist") else plistlib.FMT_XML
    info = plistlib.loads(raw)
    changed = False
    for key in SPARKLE_KEYS:
        if key not in info:
            info[key] = ""
            changed = True
            continue
        new_value = normalized(info.get(key))
        if info.get(key) != new_value:
            info[key] = new_value
            changed = True
    if changed:
        with open(plist_path, "wb") as handle:
            plistlib.dump(info, handle, fmt=fmt)
    if stamp_path:
        stamp_dir = os.path.dirname(stamp_path)
        if stamp_dir:
            os.makedirs(stamp_dir, exist_ok=True)
        with open(stamp_path, "w", encoding="utf-8") as handle:
            handle.write("ok\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
