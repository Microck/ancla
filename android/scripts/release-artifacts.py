#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import time
import zipfile
from pathlib import Path


REPO_ROOT = Path("/home/ubuntu/workspace/ancla")
ANDROID_ROOT = REPO_ROOT / "android"
DEFAULT_APK = ANDROID_ROOT / "app/build/outputs/apk/release/app-release-unsigned.apk"
DEFAULT_AAB = ANDROID_ROOT / "app/build/outputs/bundle/release/app-release.aab"
DEFAULT_APK_METADATA = ANDROID_ROOT / "app/build/outputs/apk/release/output-metadata.json"
DEFAULT_OUTPUT = REPO_ROOT / "tmp/android-release/release-candidate.json"
CANONICAL_BROWSERSTACK_HOST = "https://api-cloud.browserstack.com"
CANONICAL_APPIUM_HOST = "https://hub-cloud.browserstack.com/wd/hub"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_commit(rev: str = "HEAD") -> str:
    return subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "rev-parse", rev],
        text=True,
    ).strip()


def env_credential_diagnostics(name: str) -> dict:
    raw = os.environ.get(name, "")
    trimmed = raw.strip()
    edge_ordinals = []
    if raw:
        edge_ordinals.append(ord(raw[0]))
        if len(raw) > 1:
            edge_ordinals.append(ord(raw[-1]))
    return {
        "present": bool(raw),
        "rawLength": len(raw),
        "trimmedLength": len(trimmed),
        "rawEqualsTrimmed": raw == trimmed,
        "rawSha256": hashlib.sha256(raw.encode("utf-8")).hexdigest(),
        "trimmedSha256": hashlib.sha256(trimmed.encode("utf-8")).hexdigest(),
        "rawEdgeOrdinals": edge_ordinals,
    }


def request_site_credential_diagnostics(
    username: str | None,
    access_key: str | None,
    *,
    source: str,
    validated_username: str | None = None,
    validated_access_key: str | None = None,
) -> dict:
    username = (username or "").strip()
    access_key = (access_key or "").strip()
    authorization = ""
    if username and access_key:
        authorization = "Basic " + __import__("base64").b64encode(f"{username}:{access_key}".encode("utf-8")).decode("ascii")
    diagnostics = {
        "source": source,
        "canonicalHost": CANONICAL_BROWSERSTACK_HOST,
        "usernameLength": len(username),
        "accessKeyLength": len(access_key),
        "usernameSha256": hashlib.sha256(username.encode("utf-8")).hexdigest(),
        "accessKeySha256": hashlib.sha256(access_key.encode("utf-8")).hexdigest(),
        "authorizationLength": len(authorization),
        "authorizationSha256": hashlib.sha256(authorization.encode("utf-8")).hexdigest(),
        "usernameExactMatchValidatedPair": None,
        "accessKeyExactMatchValidatedPair": None,
        "authorizationExactMatchValidatedPair": None,
    }
    if validated_username is not None and validated_access_key is not None:
        validated_username = validated_username.strip()
        validated_access_key = validated_access_key.strip()
        validated_authorization = "Basic " + __import__("base64").b64encode(f"{validated_username}:{validated_access_key}".encode("utf-8")).decode("ascii")
        diagnostics["usernameExactMatchValidatedPair"] = username == validated_username
        diagnostics["accessKeyExactMatchValidatedPair"] = access_key == validated_access_key
        diagnostics["authorizationExactMatchValidatedPair"] = authorization == validated_authorization
    return diagnostics


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


def app_metadata_from_bundle(path: Path) -> str:
    with zipfile.ZipFile(path) as archive:
        return archive.read("BUNDLE-METADATA/com.android.tools.build.gradle/app-metadata.properties").decode("utf-8")


def parse_properties(text: str) -> dict[str, str]:
    details: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        details[key.strip()] = value.strip()
    return details


def apk_manifest_details(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        manifest = archive.read("META-INF/com/android/build/gradle/app-metadata.properties").decode("utf-8")
    return parse_properties(manifest)


def main() -> int:
    parser = argparse.ArgumentParser(description="Write canonical Android release artifact metadata.")
    parser.add_argument("--apk", type=Path, default=DEFAULT_APK)
    parser.add_argument("--aab", type=Path, default=DEFAULT_AAB)
    parser.add_argument("--apk-metadata", type=Path, default=DEFAULT_APK_METADATA)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--run", default=None, help="Immutable workflow/job/run reference")
    parser.add_argument(
        "--trace-commit",
        default=None,
        help="Immutable commit or treeish for the reviewed release-packaging state",
    )
    parser.add_argument(
        "--trace-built-at",
        default=None,
        help="Stable build timestamp for the reviewed release candidate",
    )
    parser.add_argument(
        "--source-commit",
        default=None,
        help="Commit for the live workspace that produced the packaged artifacts",
    )
    parser.add_argument(
        "--canonical-summary",
        type=Path,
        default=None,
        help="Optional immutable BrowserStack summary to mirror when mutable release metadata must stay linked to the reviewed candidate.",
    )
    parser.add_argument(
        "--validated-username",
        default=os.environ.get("BROWSERSTACK_VALIDATED_USERNAME"),
        help="Conductor-validated BrowserStack username for request-site comparison diagnostics",
    )
    parser.add_argument(
        "--validated-access-key",
        default=os.environ.get("BROWSERSTACK_VALIDATED_ACCESS_KEY"),
        help="Conductor-validated BrowserStack access key for request-site comparison diagnostics",
    )
    args = parser.parse_args()

    for label, path in [("APK", args.apk), ("AAB", args.aab), ("APK metadata", args.apk_metadata)]:
        if not path.exists():
            raise SystemExit(f"{label} missing: {path}")

    if args.canonical_summary is not None:
        if not args.canonical_summary.exists():
            raise SystemExit(f"Canonical BrowserStack summary missing: {args.canonical_summary}")
        summary = json.loads(args.canonical_summary.read_text())
        artifact = summary.get("artifact", {})
        release_candidate = summary.get("releaseCandidate", {})
        browserstack_session = summary.get("browserstackSession", {})
        browserstack_upload = summary.get("browserstackUpload", {})
        mirrored = {
            "canonicalArtifacts": {
                "apk": {
                    "path": artifact.get("apkPath"),
                    "sha256": artifact.get("apkSha256"),
                    "size": artifact.get("apkSize"),
                    "outputFile": artifact.get("apkOutputMetadata", {}).get("elements", [{}])[0].get("outputFile"),
                    "appMetadata": artifact.get("apkAppMetadata"),
                },
                "aab": {
                    "path": artifact.get("aabPath"),
                    "sha256": artifact.get("aabSha256"),
                    "size": artifact.get("aabSize"),
                },
            },
            "releaseCandidate": {
                "applicationId": release_candidate.get("applicationId"),
                "variant": release_candidate.get("variant"),
                "versionCode": release_candidate.get("versionCode"),
                "versionName": release_candidate.get("versionName"),
                "commit": release_candidate.get("commit"),
                "run": release_candidate.get("run"),
                "builtAt": release_candidate.get("builtAt"),
                "traceCommit": release_candidate.get("traceCommit", release_candidate.get("commit")),
                "traceRun": release_candidate.get("traceRun", release_candidate.get("run")),
                "traceBuiltAt": release_candidate.get("traceBuiltAt", release_candidate.get("builtAt")),
            },
            "bundleAppMetadata": artifact.get("aabAppMetadata"),
            "browserstack": {
                "canonicalHost": CANONICAL_BROWSERSTACK_HOST,
                "canonicalAppiumHost": CANONICAL_APPIUM_HOST,
                "status": "validated" if browserstack_session else "failed",
                "appUrl": browserstack_upload.get("app_url"),
                "customId": browserstack_upload.get("custom_id"),
                "sessionId": browserstack_session.get("automation_session", {}).get("hashed_id"),
                "credentialDiagnostics": summary.get("browserstackCredentialDiagnostics"),
                "requestSite": summary.get("browserstackRequestSite"),
                "validatedPairAvailable": bool(
                    summary.get("browserstackRequestSite", {}).get("usernameExactMatchValidatedPair") is not None
                    or summary.get("browserstackRequestSite", {}).get("accessKeyExactMatchValidatedPair") is not None
                ),
                "preflight": summary.get("browserstackPreflight"),
                "upload": browserstack_upload or None,
                "session": browserstack_session or None,
                "checkpoints": summary.get("checkpoints", []),
            },
            "proofBoundaries": summary.get(
                "proofBoundaries",
                {
                    "proves": [],
                    "doesNotProve": [
                        "physical NFC anchor behavior",
                        "long-running accessibility enforcement reliability",
                    ],
                },
            ),
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(mirrored, indent=2))
        print(json.dumps(mirrored, indent=2))
        return 0

    apk_metadata = json.loads(args.apk_metadata.read_text())
    env_validated_username, env_validated_access_key = validated_pair_from_env()
    validated_username = args.validated_username.strip() if args.validated_username else env_validated_username
    validated_access_key = args.validated_access_key.strip() if args.validated_access_key else env_validated_access_key
    source_commit = args.source_commit or git_commit()
    trace_commit = args.trace_commit or os.environ.get("ANCLA_RELEASE_COMMIT") or source_commit
    run_reference = args.run or os.environ.get("ANCLA_RELEASE_RUN") or f"local-{trace_commit[:12]}"
    built_at = args.trace_built_at or os.environ.get("ANCLA_RELEASE_BUILT_AT") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    trace_run = run_reference
    trace_built_at = built_at
    apk_manifest = apk_manifest_details(args.apk)
    trimmed_username = os.environ.get("BROWSERSTACK_USERNAME", "").strip()
    trimmed_access_key = os.environ.get("BROWSERSTACK_ACCESS_KEY", "").strip()
    result = {
        "canonicalArtifacts": {
            "apk": {
                "path": str(args.apk),
                "sha256": sha256(args.apk),
                "size": args.apk.stat().st_size,
                "outputFile": apk_metadata["elements"][0]["outputFile"],
                "appMetadata": apk_manifest,
            },
            "aab": {
                "path": str(args.aab),
                "sha256": sha256(args.aab),
                "size": args.aab.stat().st_size,
            },
        },
        "releaseCandidate": {
            "applicationId": apk_metadata["applicationId"],
            "variant": apk_metadata["variantName"],
            "versionCode": apk_metadata["elements"][0]["versionCode"],
            "versionName": apk_metadata["elements"][0]["versionName"],
            "commit": source_commit,
            "run": run_reference,
            "builtAt": built_at,
            "traceCommit": trace_commit,
            "traceRun": trace_run,
            "traceBuiltAt": trace_built_at,
        },
        "bundleAppMetadata": parse_properties(app_metadata_from_bundle(args.aab)),
        "browserstack": {
            "canonicalHost": CANONICAL_BROWSERSTACK_HOST,
            "canonicalAppiumHost": CANONICAL_APPIUM_HOST,
            "status": "pending",
            "appUrl": None,
            "customId": None,
            "sessionId": None,
            "credentialDiagnostics": {
                "BROWSERSTACK_USERNAME": env_credential_diagnostics("BROWSERSTACK_USERNAME"),
                "BROWSERSTACK_ACCESS_KEY": env_credential_diagnostics("BROWSERSTACK_ACCESS_KEY"),
            },
            "requestSite": request_site_credential_diagnostics(
                trimmed_username,
                trimmed_access_key,
                source="trimmed canonical env vars",
                validated_username=validated_username,
                validated_access_key=validated_access_key,
            ),
            "validatedPairAvailable": bool(validated_username and validated_access_key),
        },
        "proofBoundaries": {
            "proves": [
                "declared release APK and AAB exist",
                "artifact hashes and sizes for the release candidate",
                "application ID, version code, and version name",
            ],
            "doesNotProve": [
                "physical NFC anchor behavior",
                "long-running accessibility enforcement reliability",
            ],
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
