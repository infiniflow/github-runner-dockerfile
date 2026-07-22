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
        "https://download.docker.com/linux/static/stable/x86_64/docker-29.6.1.tgz",
        "https://github.com/docker/buildx/releases/download/v0.35.0/buildx-v0.35.0.linux-amd64",
        "https://github.com/docker/compose/releases/download/v5.2.0/docker-compose-linux-x86_64",
        "https://github.com/getsentry/prevent-cli/releases/download/v11.2.8/codecovcli_linux",
        "https://github.com/astral-sh/uv/releases/download/0.11.25/uv-x86_64-unknown-linux-gnu.tar.gz",
        "https://github.com/astral-sh/ruff/releases/download/0.15.20/ruff-x86_64-unknown-linux-gnu.tar.gz",
        "https://github.com/risinglightdb/sqllogictest-rs/releases/download/v0.29.1/sqllogictest-bin-v0.29.1-x86_64-unknown-linux-musl.tar.gz",
        "https://go.dev/dl/go1.26.4.linux-amd64.tar.gz",
        "https://nodejs.org/dist/v22.23.1/node-v22.23.1-linux-x64.tar.xz",
        "https://github.com/stripe/stripe-cli/releases/download/v1.43.2/stripe_1.43.2_linux_x86_64.tar.gz",
        "https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz",
        ["https://dl.k8s.io/release/v1.36.1/bin/linux/amd64/kubectl", "kubectl-v1.36.1"],
        "https://github.com/opentofu/opentofu/releases/download/v1.12.3/tofu_1.12.3_linux_amd64.tar.gz",
        "https://github.com/evilmartians/lefthook/releases/download/v2.1.10/lefthook_2.1.10_Linux_x86_64.gz",
        # Native static libraries for Go build (pdfium, pdf_oxide, office_oxide)
        ["https://github.com/kognitos/pdfium-static/releases/download/chromium%2F7809/pdfium-linux-x64-static.tgz",
         "pdfium-linux-x64-static.tgz"],
        ["https://github.com/yfedoseev/pdf_oxide/releases/download/v0.3.67/pdf_oxide-go-ffi-linux-amd64.tar.gz",
         "pdf_oxide-go-ffi-linux-amd64.tar.gz"],
        ["https://github.com/yfedoseev/office_oxide/releases/download/v0.1.8/native-linux-x86_64.tar.gz",
         "office_oxide-linux-x86_64.tar.gz"],
    ]
    for item in urls:
        if isinstance(item, list):
            url, filename = item
            rc = download(url, filename)
        else:
            rc = download(item)
        if rc != 0:
            return rc

    local_dir = os.path.abspath("nltk_data")
    for data in ["wordnet", "punkt", "punkt_tab"]:
        print(f"Downloading nltk {data}...")
        nltk.download(data, download_dir=local_dir)

    return 0


if __name__ == "__main__":
    sys.exit(main())
