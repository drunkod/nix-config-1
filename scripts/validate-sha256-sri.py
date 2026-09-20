#!/usr/bin/env python3
"""Validate a canonical SHA-256 SRI string."""

import base64
import binascii
import sys


def validate_sha256_sri(value: str) -> None:
    if not isinstance(value, str) or not value.startswith("sha256-"):
        raise ValueError("expected a SHA-256 SRI hash")

    encoded = value.removeprefix("sha256-")
    try:
        digest = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValueError("invalid SRI base64 encoding") from exc

    if len(digest) != 32:
        raise ValueError("SHA-256 digest must contain exactly 32 bytes")

    if base64.b64encode(digest).decode("ascii") != encoded:
        raise ValueError("expected canonical SRI base64 encoding")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-sha256-sri.py <sha256-SRI>", file=sys.stderr)
        return 2
    try:
        validate_sha256_sri(sys.argv[1])
    except ValueError as exc:
        print(f"invalid SHA-256 SRI hash: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
