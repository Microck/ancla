#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path("/home/ubuntu/workspace/ancla")
ANDROID_ROOT = REPO_ROOT / "android"
DEFAULT_APK = ANDROID_ROOT / "app/build/outputs/apk/debug/app-debug.apk"
CANONICAL_BROWSERSTACK_HOST = "https://api-cloud.browserstack.com"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Use BrowserStack App Live with canonical host and trimmed credential handling."
    )
    parser.add_argument(
        "--validated-username",
        default=os.environ.get("BROWSERSTACK_VALIDATED_USERNAME"),
    )
    parser.add_argument(
        "--validated-access-key",
        default=os.environ.get("BROWSERSTACK_VALIDATED_ACCESS_KEY"),
    )

    subcommands = parser.add_subparsers(dest="command", required=True)

    upload_parser = subcommands.add_parser("upload", help="Upload an APK to BrowserStack App Live.")
    upload_parser.add_argument("--artifact", type=Path, default=DEFAULT_APK)
    upload_parser.add_argument("--custom-id", default=None)
    upload_parser.add_argument("--out", type=Path, default=None)

    recent_parser = subcommands.add_parser("recent", help="List recent App Live uploads.")
    recent_parser.add_argument("--limit", type=int, default=10)
    recent_parser.add_argument(
        "--custom-id",
        default=None,
        help="If set, query the uploads for one BrowserStack custom id group.",
    )
    recent_parser.add_argument("--out", type=Path, default=None)

    recent_group_parser = subcommands.add_parser(
        "recent-group",
        help="List grouped recent App Live uploads.",
    )
    recent_group_parser.add_argument("--out", type=Path, default=None)

    delete_parser = subcommands.add_parser("delete", help="Delete an uploaded App Live artifact.")
    delete_parser.add_argument("--app-id", required=True)
    delete_parser.add_argument("--out", type=Path, default=None)

    return parser.parse_args()


def basic_auth_header(username: str, access_key: str) -> str:
    token = base64.b64encode(f"{username}:{access_key}".encode("utf-8")).decode("ascii")
    return f"Basic {token}"


def validated_pair_from_env() -> tuple[str | None, str | None]:
    raw_username = os.environ.get("BROWSERSTACK_VALIDATED_USERNAME")
    raw_access_key = os.environ.get("BROWSERSTACK_VALIDATED_ACCESS_KEY")
    if raw_username is None or raw_access_key is None:
        return None, None
    username = raw_username.strip()
    access_key = raw_access_key.strip()
    if not username or not access_key:
        return None, None
    return username, access_key


def resolve_browserstack_credentials(args: argparse.Namespace) -> tuple[str, str, str]:
    cli_username = args.validated_username.strip() if args.validated_username else ""
    cli_access_key = args.validated_access_key.strip() if args.validated_access_key else ""
    if cli_username and cli_access_key:
        return cli_username, cli_access_key, "validated CLI args"

    env_username = os.environ.get("BROWSERSTACK_USERNAME", "").strip()
    env_access_key = os.environ.get("BROWSERSTACK_ACCESS_KEY", "").strip()
    if env_username and env_access_key:
        return env_username, env_access_key, "trimmed canonical env vars"

    validated_username, validated_access_key = validated_pair_from_env()
    if validated_username and validated_access_key:
        return validated_username, validated_access_key, "validated env vars"

    raise SystemExit(
        "Missing BrowserStack credentials. Provide BROWSERSTACK_USERNAME/BROWSERSTACK_ACCESS_KEY "
        "or pass --validated-username/--validated-access-key."
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def json_request(
    url: str,
    *,
    username: str,
    access_key: str,
    method: str = "GET",
    data: bytes | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = 120,
):
    request_headers = {"Authorization": basic_auth_header(username, access_key)}
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers=request_headers,
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw) if raw else {"status": "ok"}


def upload_artifact(path: Path, username: str, access_key: str, custom_id: str | None) -> dict:
    boundary = "----ancla-browserstack-app-live-boundary"
    payload = path.read_bytes()
    parts = [
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="file"; filename="' + path.name.encode() + b'"\r\n',
        b"Content-Type: application/octet-stream\r\n\r\n",
        payload,
        b"\r\n",
    ]
    if custom_id:
        parts.extend(
            [
                f"--{boundary}\r\n".encode(),
                b'Content-Disposition: form-data; name="custom_id"\r\n\r\n',
                custom_id.encode(),
                b"\r\n",
            ]
        )
    parts.append(f"--{boundary}--\r\n".encode())
    body = b"".join(parts)
    return json_request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-live/upload",
        username=username,
        access_key=access_key,
        method="POST",
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        },
    )


def recent_uploads(username: str, access_key: str, *, limit: int, custom_id: str | None):
    if custom_id:
        url = (
            f"{CANONICAL_BROWSERSTACK_HOST}/app-live/recent_apps/"
            f"{urllib.parse.quote(custom_id, safe='')}"
        )
    else:
        query = urllib.parse.urlencode({"limit": limit})
        url = f"{CANONICAL_BROWSERSTACK_HOST}/app-live/recent_apps?{query}"
    return json_request(url, username=username, access_key=access_key)


def recent_group_uploads(username: str, access_key: str):
    return json_request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-live/recent_group_apps",
        username=username,
        access_key=access_key,
    )


def delete_upload(app_id: str, username: str, access_key: str):
    return json_request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-live/app/delete/{urllib.parse.quote(app_id, safe='')}",
        username=username,
        access_key=access_key,
        method="DELETE",
    )


def write_output(path: Path | None, payload: dict) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2))


def main() -> int:
    args = parse_args()
    username, access_key, credential_source = resolve_browserstack_credentials(args)

    result: dict = {
        "canonicalHost": CANONICAL_BROWSERSTACK_HOST,
        "credentialSource": credential_source,
        "command": args.command,
    }

    if args.command == "upload":
        if not args.artifact.exists():
            raise SystemExit(f"Artifact missing: {args.artifact}")
        response = upload_artifact(args.artifact, username, access_key, args.custom_id)
        result["artifact"] = {
            "path": str(args.artifact),
            "sha256": sha256(args.artifact),
            "size": args.artifact.stat().st_size,
        }
        result["response"] = response
        write_output(args.out, result)
    elif args.command == "recent":
        response = recent_uploads(username, access_key, limit=args.limit, custom_id=args.custom_id)
        result["response"] = response
        write_output(args.out, result)
    elif args.command == "recent-group":
        response = recent_group_uploads(username, access_key)
        result["response"] = response
        write_output(args.out, result)
    elif args.command == "delete":
        response = delete_upload(args.app_id, username, access_key)
        result["appId"] = args.app_id
        result["response"] = response
        write_output(args.out, result)
    else:
        raise SystemExit(f"Unsupported command: {args.command}")

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        error_payload = {
            "canonicalHost": CANONICAL_BROWSERSTACK_HOST,
            "status": "http-error",
            "code": exc.code,
            "reason": exc.reason,
            "body": body,
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        raise
