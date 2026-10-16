#!/usr/bin/env python3
"""Download an explicitly selected native package. Never execute installers."""

import hashlib
import json
import platform
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path


def fetch(url):
    request = urllib.request.Request(
        url, headers={"User-Agent": "dotfiles-native-packages"}
    )
    return urllib.request.urlopen(request, timeout=60)


def github_asset(repo, pattern):
    with fetch(f"https://api.github.com/repos/{repo}/releases/latest") as response:
        release = json.load(response)
    matches = [a for a in release["assets"] if re.fullmatch(pattern, a["name"])]
    if len(matches) != 1:
        raise ValueError(
            f"Expected one compatible native asset from {repo}; found {len(matches)}"
        )
    return matches[0]["browser_download_url"], matches[0].get("digest")


def release_url(source, extension):
    machine = platform.machine()
    deb_arch = {"x86_64": "amd64", "aarch64": "arm64"}.get(machine)
    if deb_arch is None:
        raise ValueError(f"Unsupported native package architecture: {machine}")
    if source == "bruno-release":
        arch = deb_arch if extension == "deb" else machine
        return github_asset(
            "usebruno/bruno", rf"bruno_[0-9.]+_{arch}_linux\.{extension}"
        )
    if source == "ghostty-deb" and extension == "deb":
        info = {}
        for line in Path("/etc/os-release").read_text().splitlines():
            key, _, value = line.partition("=")
            info[key] = value.strip('"')
        version = (
            info.get("VERSION_ID")
            if info["ID"] == "ubuntu"
            else info.get("VERSION_CODENAME")
        )
        if not version:
            raise ValueError("No distribution version for Ghostty package selection")
        return github_asset(
            "mkasberg/ghostty-ubuntu",
            rf"ghostty_[^/]+_{deb_arch}_{re.escape(version)}\.deb",
        )
    if source == "cmux-deb" and machine == "x86_64" and extension == "deb":
        return "https://cmux.com/api/download/browser-nightly/linux-x64/deb", None
    if source == "docker-desktop" and machine == "x86_64":
        filename = (
            "docker-desktop-amd64.deb"
            if extension == "deb"
            else "docker-desktop-x86_64.rpm"
        )
        return f"https://desktop.docker.com/linux/main/amd64/{filename}", None
    raise ValueError(f"No supported {extension} package for {source} on {machine}")


def main():
    source, extension, target = sys.argv[1:]
    if extension not in {"deb", "rpm"}:
        raise ValueError("Only native deb/rpm packages are permitted")
    url, digest = release_url(source, extension)
    checksum = hashlib.sha256()
    with fetch(url) as response, Path(target).open("wb") as output:
        if not response.url.startswith("https://"):
            raise ValueError("Native package download must use HTTPS")
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
            checksum.update(chunk)
    if digest and digest != "sha256:" + checksum.hexdigest():
        Path(target).unlink()
        raise ValueError("Native package checksum does not match release metadata")
    print(f"Downloaded {source} from {url}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, urllib.error.URLError) as error:
        print(f"Native package unavailable: {error}", file=sys.stderr)
        sys.exit(1)
