#!/usr/bin/env python3

"""
This script should be run from the project root directory
Usage:  uv run download_deps.py
"""
# PEP 723 metadata
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "nltk",
# ]
# ///

import os
import sys
import ssl
import pathlib
from urllib import request, parse, error
import nltk


def ensure_project_root() -> None:
    cwd = pathlib.Path.cwd()
    if not (cwd / "Dockerfile").is_file():
        print("Error: This script must be run from the project root directory")
        print("Usage: ./download_deps.py")
        sys.exit(1)


def basename_from_url(url: str) -> str:
    path = parse.urlsplit(url).path
    name = os.path.basename(path)
    return name or "downloaded.file"


def file_exists_and_nonempty(path: pathlib.Path) -> bool:
    try:
        return path.is_file() and path.stat().st_size > 0
    except OSError:
        return False


def download(url: str, filename: str | None = None) -> int:
    print(f"download {url}" + (f" -> {filename}" if filename else ""))
    fn = filename or basename_from_url(url)
    out_path = pathlib.Path(fn)

    if file_exists_and_nonempty(out_path):
        print(f"File {fn} already exists, skipping.")
        return 0

    # Match curl --insecure by disabling certificate verification
    ctx = ssl._create_unverified_context()

    try:
        with request.urlopen(url, context=ctx) as resp, open(out_path, "wb") as f:
            # Stream to disk
            chunk_size = 1024 * 64
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                f.write(chunk)
        return 0
    except error.HTTPError as e:
        print(f"HTTP error downloading {url}: {e}")
        return 1
    except error.URLError as e:
        print(f"URL error downloading {url}: {e}")
        return 1
    except Exception as e:
        print(f"Unexpected error downloading {url}: {e}")
        return 1


def main() -> int:
    ensure_project_root()

    urls = [
        "https://download.docker.com/linux/static/stable/x86_64/docker-29.0.2.tgz",
        "https://github.com/docker/buildx/releases/download/v0.30.1/buildx-v0.30.1.linux-amd64",
        "https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64",
        "https://cli.codecov.io/latest/linux/codecov",
        "https://github.com/astral-sh/uv/releases/download/0.9.15/uv-x86_64-unknown-linux-gnu.tar.gz",
        "https://github.com/risinglightdb/sqllogictest-rs/releases/download/v0.28.4/sqllogictest-bin-v0.28.4-x86_64-unknown-linux-musl.tar.gz",
        "https://github.com/actions/runner/releases/download/v2.330.0/actions-runner-linux-x64-2.331.0.tar.gz",
    ]

    for url in urls:
        rc = download(url)
        if rc != 0:
            return rc

    local_dir = os.path.abspath("nltk_data")
    for data in ["wordnet", "punkt", "punkt_tab"]:
        print(f"Downloading nltk {data}...")
        nltk.download(data, download_dir=local_dir)

    return 0


if __name__ == "__main__":
    sys.exit(main())
