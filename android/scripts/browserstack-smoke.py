#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


REPO_ROOT = Path("/home/ubuntu/workspace/ancla")
ANDROID_ROOT = REPO_ROOT / "android"
DEFAULT_APK = ANDROID_ROOT / "app/build/outputs/apk/debug/app-debug.apk"
DEFAULT_APK_METADATA = ANDROID_ROOT / "app/build/outputs/apk/debug/output-metadata.json"
DEFAULT_OUT_DIR = REPO_ROOT / "tmp/android-browserstack-smoke"
CANONICAL_BROWSERSTACK_HOST = "https://api-cloud.browserstack.com"
CANONICAL_APPIUM_HOST = "https://hub-cloud.browserstack.com/wd/hub"
APP_PACKAGE = "dev.micr.ancla"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload the current Android APK to BrowserStack and run a current smoke flow."
    )
    parser.add_argument("--artifact", type=Path, default=DEFAULT_APK)
    parser.add_argument(
        "--app-url",
        default=os.environ.get("BROWSERSTACK_APP_URL"),
        help="Reuse an existing BrowserStack uploaded app URL instead of uploading again.",
    )
    parser.add_argument("--apk-metadata", type=Path, default=DEFAULT_APK_METADATA)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument(
        "--flow",
        choices=["setup", "seeded-home", "schedule-seeded-home"],
        default="setup",
        help="Which current app surface to validate on BrowserStack.",
    )
    parser.add_argument("--device", default=os.environ.get("BROWSERSTACK_DEVICE_NAME", "Samsung Galaxy S23"))
    parser.add_argument("--platform-version", default=os.environ.get("BROWSERSTACK_PLATFORM_VERSION", "13.0"))
    parser.add_argument("--project-name", default="ancla-android")
    parser.add_argument("--build-name", default=os.environ.get("BROWSERSTACK_BUILD_NAME", "ancla-android-debug"))
    parser.add_argument("--session-name", default=os.environ.get("BROWSERSTACK_SESSION_NAME", "current-smoke"))
    parser.add_argument("--appium-version", default="2.4.1")
    parser.add_argument("--poll-seconds", type=float, default=2.0)
    parser.add_argument("--timeout-seconds", type=float, default=240.0)
    parser.add_argument(
        "--allow-missing-credentials",
        action="store_true",
        help="Write a skipped summary instead of failing when BrowserStack credentials are absent.",
    )
    parser.add_argument("--source-commit", default=None)
    parser.add_argument("--trace-run", default=None)
    parser.add_argument("--trace-built-at", default=None)
    parser.add_argument(
        "--validated-username",
        default=os.environ.get("BROWSERSTACK_VALIDATED_USERNAME"),
    )
    parser.add_argument(
        "--validated-access-key",
        default=os.environ.get("BROWSERSTACK_VALIDATED_ACCESS_KEY"),
    )
    return parser.parse_args()


def credential_state(name: str) -> str:
    return "set" if os.environ.get(name) else "missing"


def trimmed_env(name: str) -> str:
    value = os.environ.get(name, "")
    trimmed = value.strip()
    if not trimmed:
        raise SystemExit(f"Missing required environment variable after trim: {name}")
    return trimmed


def credential_diagnostics(name: str) -> dict:
    raw = os.environ.get(name, "")
    trimmed = raw.strip()
    edge_ordinals: list[int] = []
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


def basic_auth_header(username: str, access_key: str) -> str:
    token = base64.b64encode(f"{username}:{access_key}".encode("utf-8")).decode("ascii")
    return f"Basic {token}"


def request_site_credential_diagnostics(
    username: str,
    access_key: str,
    *,
    source: str,
    validated_username: str | None = None,
    validated_access_key: str | None = None,
) -> dict:
    basic_auth = basic_auth_header(username, access_key)
    diagnostics = {
        "source": source,
        "canonicalApiHost": CANONICAL_BROWSERSTACK_HOST,
        "canonicalAppiumHost": CANONICAL_APPIUM_HOST,
        "usernameLength": len(username),
        "accessKeyLength": len(access_key),
        "usernameSha256": hashlib.sha256(username.encode("utf-8")).hexdigest(),
        "accessKeySha256": hashlib.sha256(access_key.encode("utf-8")).hexdigest(),
        "authorizationLength": len(basic_auth),
        "authorizationSha256": hashlib.sha256(basic_auth.encode("utf-8")).hexdigest(),
        "usernameExactMatchValidatedPair": None,
        "accessKeyExactMatchValidatedPair": None,
        "authorizationExactMatchValidatedPair": None,
    }
    if validated_username is not None and validated_access_key is not None:
        validated_auth = basic_auth_header(validated_username, validated_access_key)
        diagnostics["usernameExactMatchValidatedPair"] = username == validated_username
        diagnostics["accessKeyExactMatchValidatedPair"] = access_key == validated_access_key
        diagnostics["authorizationExactMatchValidatedPair"] = basic_auth == validated_auth
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


def git_commit(rev: str = "HEAD") -> str:
    return subprocess.check_output(["git", "-C", str(REPO_ROOT), "rev-parse", rev], text=True).strip()


def ensure_exists(path: Path, label: str) -> None:
    if not path.exists():
        raise SystemExit(f"{label} not found: {path}")


def read_apk_metadata(path: Path | None) -> dict | None:
    if path is None or not path.exists():
        return None
    return json.loads(path.read_text())


def upload_artifact(path: Path, username: str, access_key: str, custom_id: str) -> dict:
    boundary = "----ancla-browserstack-boundary"
    payload = path.read_bytes()
    parts = [
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="file"; filename="' + path.name.encode() + b'"\r\n',
        b"Content-Type: application/octet-stream\r\n\r\n",
        payload,
        b"\r\n",
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="custom_id"\r\n\r\n',
        custom_id.encode(),
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    body = b"".join(parts)
    request = urllib.request.Request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-automate/upload",
        data=body,
        method="POST",
        headers={
            "Authorization": basic_auth_header(username, access_key),
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def upload_artifact_app_live(path: Path, username: str, access_key: str, custom_id: str) -> dict:
    boundary = "----ancla-browserstack-app-live-boundary"
    payload = path.read_bytes()
    parts = [
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="file"; filename="' + path.name.encode() + b'"\r\n',
        b"Content-Type: application/octet-stream\r\n\r\n",
        payload,
        b"\r\n",
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="custom_id"\r\n\r\n',
        custom_id.encode(),
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    body = b"".join(parts)
    request = urllib.request.Request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-live/upload",
        data=body,
        method="POST",
        headers={
            "Authorization": basic_auth_header(username, access_key),
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def session_status(username: str, access_key: str, session_id: str) -> dict:
    request = urllib.request.Request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-automate/sessions/{session_id}.json",
        headers={"Authorization": basic_auth_header(username, access_key)},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def recent_apps_preflight(username: str, access_key: str) -> dict:
    request = urllib.request.Request(
        f"{CANONICAL_BROWSERSTACK_HOST}/app-automate/recent_apps",
        headers={"Authorization": basic_auth_header(username, access_key)},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if isinstance(payload, list):
        return {"status": "ok", "count": len(payload)}
    if isinstance(payload, dict):
        payload["status"] = payload.get("status", "ok")
    return payload


def auth_wiring_error(exc: urllib.error.HTTPError, request_site: dict) -> dict:
    body = exc.read().decode("utf-8", "replace")
    return {
        "status": "http-error",
        "code": exc.code,
        "reason": exc.reason,
        "body": body,
        "requestSite": request_site,
    }


def is_automate_testing_time_exhausted(error_payload: dict) -> bool:
    return error_payload.get("code") == 403 and "BROWSERSTACK_TESTING_TIME_LIMIT_EXHAUSTED" in error_payload.get(
        "body",
        "",
    )


def xpath_literal(value: str) -> str:
    if "'" not in value:
        return f"'{value}'"
    if '"' not in value:
        return f'"{value}"'
    parts = value.split("'")
    joined = ", \"'\", ".join(f"'{part}'" for part in parts)
    return f"concat({joined})"


def exact_text_xpath(text: str) -> str:
    return f"//*[@text={xpath_literal(text)}]"


def contains_text_xpath(text: str) -> str:
    return f"//*[contains(@text, {xpath_literal(text)})]"


def write_summary(out_dir: Path, summary: dict) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2))


def save_checkpoint(driver, out_dir: Path, name: str, checkpoints: list[dict], observed: str) -> None:
    screenshot = out_dir / f"{name}.png"
    page_source = out_dir / f"{name}.xml"
    driver.save_screenshot(str(screenshot))
    page_source.write_text(driver.page_source)
    checkpoints.append(
        {
            "checkpoint": name,
            "observed": observed,
            "screenshot": str(screenshot),
            "pageSource": str(page_source),
        }
    )


def wait_for_text(wait, text: str):
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support import expected_conditions as EC

    return wait.until(EC.presence_of_element_located((By.XPATH, exact_text_xpath(text))))


def wait_for_contains_text(wait, text: str):
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support import expected_conditions as EC

    return wait.until(EC.presence_of_element_located((By.XPATH, contains_text_xpath(text))))


def clickable_text_container_xpath(text: str) -> str:
    literal = xpath_literal(text)
    return f"//*[@clickable='true' and .//*[@text={literal}]]"


def wait_for_clickable_text_container(wait, text: str):
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support import expected_conditions as EC

    return wait.until(EC.presence_of_element_located((By.XPATH, clickable_text_container_xpath(text))))


def click_element(driver, element):
    try:
        driver.execute_script("mobile: clickGesture", {"elementId": element.id})
    except Exception:
        element.click()
    return element


def click_text(wait, text: str):
    driver = wait._driver
    element = wait_for_clickable_text_container(wait, text)
    return click_element(driver, element)


def bounds_center(bounds: str) -> tuple[int, int]:
    left_top, right_bottom = bounds.strip("[]").split("][")
    left, top = (int(part) for part in left_top.split(","))
    right, bottom = (int(part) for part in right_bottom.split(","))
    return ((left + right) // 2, (top + bottom) // 2)


def click_visible_text_bounds(driver, text: str):
    root = ET.fromstring(driver.page_source)
    for element in root.iter():
        if element.attrib.get("text") == text and element.attrib.get("displayed") == "true":
            bounds = element.attrib.get("bounds")
            if not bounds:
                continue
            x, y = bounds_center(bounds)
            driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
            return
    raise LookupError(f"Could not find visible text bounds for {text!r}")


def click_visible_content_desc_bounds(driver, description: str):
    root = ET.fromstring(driver.page_source)
    for element in root.iter():
        if element.attrib.get("content-desc") == description and element.attrib.get("displayed") == "true":
            bounds = element.attrib.get("bounds")
            if not bounds:
                continue
            x, y = bounds_center(bounds)
            driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
            return
    raise LookupError(f"Could not find visible content description bounds for {description!r}")


def tap_bottom_center_action(driver) -> None:
    for description in ("End block", "Start block", "Turn on NFC", "Pair anchor", "Create mode"):
        try:
            click_visible_content_desc_bounds(driver, description)
            return
        except LookupError:
            continue
    size = driver.get_window_size()
    driver.execute_script(
        "mobile: clickGesture",
        {
            "x": int(size["width"] * 0.5),
            "y": int(size["height"] * 0.9),
        },
    )


def click_section_tab(wait, title: str):
    from selenium.common.exceptions import TimeoutException

    driver = wait._driver
    try:
        click_visible_content_desc_bounds(driver, f"{title} tab")
        return None
    except LookupError:
        try:
            element = wait_for_clickable_text_container(wait, title)
            return click_element(driver, element)
        except TimeoutException:
            click_visible_text_bounds(driver, title)
            return None


def page_contains_text(driver, text: str) -> bool:
    return f'text="{text}"' in driver.page_source

def wait_for_any_page_text(driver, texts: list[str], *, timeout_seconds: float = 12.0, poll_seconds: float = 1.0) -> str | None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        source = driver.page_source
        for text in texts:
            if text in source:
                return text
        time.sleep(poll_seconds)
    return None


def scroll_forward(driver):
    from selenium.webdriver.common.by import By

    scroll_view = driver.find_element(By.XPATH, "//android.widget.ScrollView")
    return driver.execute_script(
        "mobile: scrollGesture",
        {
            "elementId": scroll_view.id,
            "direction": "down",
            "percent": 0.8,
        },
    )


def scroll_until_text(driver, wait, text: str, *, max_swipes: int = 4):
    for _ in range(max_swipes + 1):
        if page_contains_text(driver, text):
            return
        if not scroll_forward(driver):
            break
        time.sleep(wait._poll)
    wait_for_text(wait, text)


def run_setup_flow(driver, wait, out_dir: Path) -> list[dict]:
    checkpoints: list[dict] = []
    wait_for_text(wait, "Finish setup")
    save_checkpoint(driver, out_dir, "01-setup", checkpoints, "Finish setup")

    try:
        click_visible_text_bounds(driver, "I've finished Android setup")
    except Exception:
        click_text(wait, "I've finished Android setup")
    observed_anchor_state = wait_for_any_page_text(
        driver,
        ["No anchor yet", "Turn on NFC"],
        timeout_seconds=12.0,
        poll_seconds=wait._poll,
    )
    if observed_anchor_state is None:
        raise TimeoutException("Setup confirmation did not advance to the Anchor step.")
    save_checkpoint(driver, out_dir, "02-after-confirm", checkpoints, observed_anchor_state)

    if driver.is_app_installed(APP_PACKAGE):
        driver.terminate_app(APP_PACKAGE)
        driver.activate_app(APP_PACKAGE)

    observed_post_relaunch = wait_for_any_page_text(
        driver,
        ["No anchor yet", "Turn on NFC"],
        timeout_seconds=12.0,
        poll_seconds=wait._poll,
    )
    if observed_post_relaunch is None:
        raise TimeoutException("App relaunch did not return to the Anchor step.")
    save_checkpoint(driver, out_dir, "03-post-relaunch", checkpoints, observed_post_relaunch)
    return checkpoints


def run_seeded_home_flow(driver, wait, out_dir: Path, *, include_schedule: bool) -> list[dict]:
    checkpoints: list[dict] = []
    wait_for_text(wait, "Ancla")
    wait_for_text(wait, "Focus")
    save_checkpoint(driver, out_dir, "01-home", checkpoints, "Home loaded with Focus mode")

    tap_bottom_center_action(driver)
    dialog_text = wait_for_any_page_text(
        driver,
        [
            "Waiting for an NFC tag",
            "NFC unavailable",
            "NFC is unavailable on this Android phone.",
        ],
    )
    try:
        if dialog_text is None:
            raise TimeoutException("No scan dialog or NFC unavailable dialog appeared after tapping the primary action.")
        save_checkpoint(driver, out_dir, "02-start-dialog", checkpoints, "Center action opened NFC scan dialog")
        driver.back()
        wait_for_text(wait, "Ancla")
    except Exception:
        if dialog_text in {"NFC unavailable", "NFC is unavailable on this Android phone."}:
            save_checkpoint(driver, out_dir, "02-start-dialog", checkpoints, "Center action opened the NFC unavailable dialog")
            driver.back()
            wait_for_text(wait, "Ancla")
        else:
            wait_for_text(wait, "Ancla")
            save_checkpoint(driver, out_dir, "02-start-action", checkpoints, "Center action returned to the home shell")

    click_section_tab(wait, "Unlock")
    wait_for_text(wait, "FAILSAFE")
    scroll_until_text(driver, wait, "Check 2FA")
    save_checkpoint(driver, out_dir, "03-unlock", checkpoints, "Unlock section with preset loaded")

    if include_schedule:
        click_section_tab(wait, "Schedule")
        wait_for_text(wait, "Create schedule")
        wait_for_contains_text(wait, "Release early with Desk anchor")
        save_checkpoint(driver, out_dir, "04-schedule", checkpoints, "Schedule section with seeded schedule")
    else:
        click_section_tab(wait, "Anchor")
        wait_for_text(wait, "Desk anchor")
        save_checkpoint(driver, out_dir, "04-anchor", checkpoints, "Anchor section with seeded anchor")

    return checkpoints


def run_smoke_checks() -> dict:
    from appium import webdriver
    from appium.options.android import UiAutomator2Options
    from appium.webdriver.client_config import AppiumClientConfig
    from selenium.common.exceptions import TimeoutException
    from selenium.webdriver.support.ui import WebDriverWait

    args = parse_args()
    ensure_exists(args.artifact, "APK artifact")
    args.out_dir.mkdir(parents=True, exist_ok=True)

    username_diagnostics = credential_diagnostics("BROWSERSTACK_USERNAME")
    access_key_diagnostics = credential_diagnostics("BROWSERSTACK_ACCESS_KEY")

    if args.allow_missing_credentials and (
        not username_diagnostics["trimmedLength"] or not access_key_diagnostics["trimmedLength"]
    ):
        summary = {
            "browserstack": {
                "status": "skipped",
                "reason": "BrowserStack credentials are not visible in the worker shell.",
                "canonicalApiHost": CANONICAL_BROWSERSTACK_HOST,
                "canonicalAppiumHost": CANONICAL_APPIUM_HOST,
                "credentialState": {
                    "BROWSERSTACK_USERNAME": credential_state("BROWSERSTACK_USERNAME"),
                    "BROWSERSTACK_ACCESS_KEY": credential_state("BROWSERSTACK_ACCESS_KEY"),
                },
                "credentialDiagnostics": {
                    "BROWSERSTACK_USERNAME": username_diagnostics,
                    "BROWSERSTACK_ACCESS_KEY": access_key_diagnostics,
                },
            }
        }
        write_summary(args.out_dir, summary)
        print(json.dumps(summary, indent=2))
        return summary

    username, access_key, credential_source = resolve_browserstack_credentials(args)
    env_validated_username, env_validated_access_key = validated_pair_from_env()
    validated_username = args.validated_username.strip() if args.validated_username else env_validated_username
    validated_access_key = args.validated_access_key.strip() if args.validated_access_key else env_validated_access_key
    request_site = request_site_credential_diagnostics(
        username,
        access_key,
        source=credential_source,
        validated_username=validated_username,
        validated_access_key=validated_access_key,
    )

    source_commit = args.source_commit or git_commit()
    trace_run = args.trace_run or os.environ.get("ANCLA_RELEASE_RUN") or f"local-{source_commit[:12]}"
    trace_built_at = (
        args.trace_built_at
        or os.environ.get("ANCLA_RELEASE_BUILT_AT")
        or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    )
    custom_id = f"ancla-{args.flow}-{source_commit[:12]}-{sha256(args.artifact)[:12]}"

    summary = {
        "artifact": {
            "apkPath": str(args.artifact),
            "apkSha256": sha256(args.artifact),
            "apkSize": args.artifact.stat().st_size,
            "apkMetadata": read_apk_metadata(args.apk_metadata),
        },
        "flow": args.flow,
        "browserstackCredentialDiagnostics": {
            "BROWSERSTACK_USERNAME": username_diagnostics,
            "BROWSERSTACK_ACCESS_KEY": access_key_diagnostics,
        },
        "browserstackRequestSite": request_site,
        "sourceCommit": source_commit,
        "traceRun": trace_run,
        "traceBuiltAt": trace_built_at,
        "proofBoundaries": {
            "proves": [
                "upload acceptance",
                "install on one BrowserStack Android device",
                "launch to the expected current screen",
                "current home/setup smoke checkpoints",
            ],
            "doesNotProve": [
                "physical NFC anchor behavior",
                "long-running accessibility enforcement reliability",
            ],
        },
    }

    try:
        summary["browserstackPreflight"] = recent_apps_preflight(username, access_key)
    except urllib.error.HTTPError as exc:
        summary["browserstackPreflight"] = auth_wiring_error(exc, request_site)
        write_summary(args.out_dir, summary)
        print(json.dumps(summary, indent=2))
        return summary

    if args.app_url:
        upload_response = {
            "app_url": args.app_url.strip(),
            "custom_id": custom_id,
            "reused": True,
        }
    else:
        try:
            upload_response = upload_artifact(args.artifact, username, access_key, custom_id)
        except urllib.error.HTTPError as exc:
            upload_error = auth_wiring_error(exc, request_site)
            summary["browserstackUploadError"] = upload_error
            if is_automate_testing_time_exhausted(upload_error):
                # App Live is the only BrowserStack lane still usable when Automate testing time is exhausted.
                summary["browserstackAutomateStatus"] = "testing-time-limit-exhausted"
                summary["proofBoundaries"]["doesNotProve"].append(
                    "BrowserStack App Automate smoke execution when the account testing-time quota is exhausted",
                )
                try:
                    app_live_upload = upload_artifact_app_live(args.artifact, username, access_key, custom_id)
                    app_live_upload["custom_id"] = custom_id
                    summary["browserstackAppLiveUpload"] = app_live_upload
                    summary["status"] = "app-live-fallback-only"
                    write_summary(args.out_dir, summary)
                    print(json.dumps(summary, indent=2))
                    return summary
                except urllib.error.HTTPError as app_live_exc:
                    summary["browserstackAppLiveUploadError"] = auth_wiring_error(app_live_exc, request_site)
                    write_summary(args.out_dir, summary)
                    print(json.dumps(summary, indent=2))
                    raise
            write_summary(args.out_dir, summary)
            print(json.dumps(summary, indent=2))
            raise
    summary["browserstackUpload"] = upload_response

    options = UiAutomator2Options()
    options.set_capability("platformName", "Android")
    options.set_capability("appium:automationName", "UiAutomator2")
    options.set_capability("appium:app", upload_response["app_url"])
    options.set_capability("appium:deviceName", args.device)
    options.set_capability("appium:platformVersion", args.platform_version)
    options.set_capability(
        "bstack:options",
        {
            "userName": username,
            "accessKey": access_key,
            "projectName": args.project_name,
            "buildName": args.build_name,
            "sessionName": args.session_name,
            "appiumVersion": args.appium_version,
        },
    )
    options.set_capability("project", args.project_name)
    options.set_capability("build", args.build_name)
    options.set_capability("name", args.session_name)

    driver = webdriver.Remote(
        options=options,
        client_config=AppiumClientConfig(remote_server_addr=CANONICAL_APPIUM_HOST),
    )
    wait = WebDriverWait(driver, args.timeout_seconds, poll_frequency=args.poll_seconds)

    try:
        if args.flow == "setup":
            checkpoints = run_setup_flow(driver, wait, args.out_dir)
        elif args.flow == "seeded-home":
            checkpoints = run_seeded_home_flow(driver, wait, args.out_dir, include_schedule=False)
        else:
            checkpoints = run_seeded_home_flow(driver, wait, args.out_dir, include_schedule=True)
        session_id = driver.session_id
    except TimeoutException as exc:
        failure_shot = args.out_dir / "zz-timeout.png"
        failure_xml = args.out_dir / "zz-timeout.xml"
        driver.save_screenshot(str(failure_shot))
        failure_xml.write_text(driver.page_source)
        summary["checkpoints"] = [
            {
                "checkpoint": "timeout",
                "observed": str(exc),
                "screenshot": str(failure_shot),
                "pageSource": str(failure_xml),
            }
        ]
        summary["browserstackSession"] = session_status(username, access_key, driver.session_id)
        write_summary(args.out_dir, summary)
        raise
    finally:
        driver.quit()

    summary["checkpoints"] = checkpoints
    summary["browserstackSession"] = session_status(username, access_key, session_id)
    write_summary(args.out_dir, summary)
    print(json.dumps(summary, indent=2))
    return summary


if __name__ == "__main__":
    try:
        run_smoke_checks()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        print(body, file=sys.stderr)
        raise
