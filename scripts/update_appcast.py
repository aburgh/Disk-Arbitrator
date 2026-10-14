#!/usr/bin/env python3
"""Write a Sparkle appcast that contains only the release being published."""

import argparse
import email.utils
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC = "http://purl.org/dc/elements/1.1/"

ET.register_namespace("sparkle", SPARKLE)
ET.register_namespace("dc", DC)

APP_ZIP_PREFIX = "Disk.Arbitrator-"


def sparkle(name):
    return f"{{{SPARKLE}}}{name}"


def item_version(item):
    node = item.find(sparkle("version"))
    return (node.text or "").strip() if node is not None else ""


def enclosure_url(item):
    enclosure = item.find("enclosure")
    if enclosure is None:
        return ""
    return enclosure.get("url") or ""


def basename_of(url):
    path = url.split("?", 1)[0].split("#", 1)[0]
    return path.rsplit("/", 1)[-1]


def is_source_archive(name):
    lower = name.lower()
    return "-source." in lower or lower.endswith((".tar.gz", ".tgz"))


def is_app_zip(name):
    return name.startswith(APP_ZIP_PREFIX) and name.endswith(".zip") and not is_source_archive(name)


def new_tree(link):
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Disk Arbitrator"
    ET.SubElement(channel, "link").text = link or "https://github.com"
    ET.SubElement(channel, "description").text = "Disk Arbitrator updates"
    ET.SubElement(channel, "language").text = "en"
    return ET.ElementTree(rss)


def channel_of(tree):
    channel = tree.getroot().find("channel")
    if channel is None:
        raise SystemExit("appcast has no channel")
    return channel


def load(path):
    return ET.parse(path)


def require_app_zip(name):
    if is_source_archive(name) or not is_app_zip(name):
        raise SystemExit(
            f"refusing {name or '(missing enclosure)'} as the Sparkle update archive; "
            f"expected {APP_ZIP_PREFIX}<version>.zip"
        )


def make_item(args):
    require_app_zip(basename_of(args.url))
    item = ET.Element("item")
    ET.SubElement(item, "title").text = args.title or f"Version {args.short_version}"
    published = datetime.now(timezone.utc)
    ET.SubElement(item, "pubDate").text = email.utils.format_datetime(published)
    ET.SubElement(item, sparkle("version")).text = args.version
    ET.SubElement(item, sparkle("shortVersionString")).text = args.short_version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = args.minimum_system_version
    attributes = {
        "url": args.url,
        "length": str(args.length),
        "type": "application/octet-stream",
    }
    if args.ed_signature:
        attributes[sparkle("edSignature")] = args.ed_signature
    ET.SubElement(item, "enclosure", attributes)
    return item


def keep_only(channel, version):
    kept = []
    for item in list(channel.findall("item")):
        name = basename_of(enclosure_url(item))
        if item_version(item) != version or not is_app_zip(name):
            channel.remove(item)
            if item_version(item) == version:
                require_app_zip(name)
            continue
        kept.append(item)
    if len(kept) != 1:
        raise SystemExit(
            f"appcast must contain exactly one item for build {version}; found {len(kept)}"
        )


def write(tree, path):
    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--version", default="")
    parser.add_argument("--short-version", default="")
    parser.add_argument("--url", default="")
    parser.add_argument("--length", default="")
    parser.add_argument("--ed-signature", default="")
    parser.add_argument("--minimum-system-version", default="13.0")
    parser.add_argument("--title", default="")
    parser.add_argument("--link", default="", help="Channel link for a newly created appcast. The release workflow passes https://github.com/<owner>/<repo>.")
    args = parser.parse_args()

    if not args.version:
        raise SystemExit("--version is required so the appcast contains only that build")

    destination = Path(args.appcast)
    tree = load(destination) if destination.is_file() else new_tree(args.link)
    channel = channel_of(tree)

    writing_item = bool(args.url or args.short_version or args.length or args.ed_signature)
    if writing_item:
        if not args.short_version or not args.url or not args.length:
            raise SystemExit("--version requires --short-version, --url, and --length when writing an item")
        for item in list(channel.findall("item")):
            if item_version(item) == args.version:
                channel.remove(item)
        insert_at = None
        for index, child in enumerate(list(channel)):
            if child.tag == "item":
                insert_at = index
                break
        item = make_item(args)
        if insert_at is None:
            channel.append(item)
        else:
            channel.insert(insert_at, item)

    keep_only(channel, args.version)
    destination.parent.mkdir(parents=True, exist_ok=True)
    write(tree, destination)


if __name__ == "__main__":
    main()
