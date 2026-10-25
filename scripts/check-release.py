"""Detect a published BtbN autobuild, then resolve its exact source revisions."""
import hashlib
import json
import os
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def api(path):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "cs-demodesk-ffmpeg"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    with urlopen(Request("https://api.github.com/repos/" + path, headers=headers), timeout=30) as response:
        return json.load(response)


def select_release(releases):
    candidates = [r for r in releases if not r["draft"] and not r["prerelease"]
                  and re.fullmatch(r"autobuild-\d{4}-\d{2}-\d{2}-\d{2}-\d{2}", r["tag_name"])]
    if not candidates:
        raise ValueError("No published BtbN autobuild found")
    release = max(candidates, key=lambda r: r["published_at"])
    assets = [(a, re.fullmatch(r"ffmpeg-N-\d+-g([0-9a-f]{7,40})-win64-gpl-shared.zip", a["name"]))
              for a in release["assets"] if a["state"] == "uploaded"]
    assets = [(a, m) for a, m in assets if m]
    if len(assets) != 1:
        raise ValueError("Newest autobuild does not have exactly one completed Windows master shared asset")
    asset, match = assets[0]
    return release, asset, match[1]


def main():
    release, asset, ffmpeg_short = select_release(api("BtbN/FFmpeg-Builds/releases?per_page=100"))
    identity = json.dumps([release["id"], release["tag_name"], asset["id"], asset["updated_at"],
                           asset.get("digest"), os.environ["GITHUB_SHA"]])
    tag = "build-" + hashlib.sha256(identity.encode()).hexdigest()[:24]
    outputs = {"tag": tag, "changed": "false"}
    try:
        own_release = api(os.environ["GITHUB_REPOSITORY"] + "/releases/tags/" + tag)
        if own_release["draft"]:
            raise ValueError("Matching release is still a draft; resolve it before retrying")
    except HTTPError as error:
        if error.code != 404:
            raise
        outputs.update(
            changed="true",
            builder=api("BtbN/FFmpeg-Builds/commits/" + release["tag_name"])["sha"],
            ffmpeg=api("FFmpeg/FFmpeg/commits/" + ffmpeg_short)["sha"],
        )
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for key, value in outputs.items():
            output.write(f"{key}={value}\n")
    print(f"Upstream: {release['tag_name']}; build required: {outputs['changed']}")


if __name__ == "__main__":
    main()
