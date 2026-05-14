from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.client_config import AppiumClientConfig
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver import ActionChains
from selenium.webdriver.common.actions import interaction
from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.pointer_input import PointerInput
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

REPO_ROOT = Path("/home/ubuntu/workspace/ancla")
DEFAULT_OUT_DIR = REPO_ROOT / "tmp/android-browserstack-manual-schedule-flow"
CANONICAL_APPIUM_HOST = "https://hub-cloud.browserstack.com/wd/hub"
HOME_MARKERS = [
    "Ancla",
    "Focus",
    "Create schedule",
    "Release early with Desk anchor",
    "No active session is running right now.",
]
ACTIVE_SESSION_MARKERS = [
    "You're anchored",
    "Unlock options stay on the top left.",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Android real-device schedule flow on BrowserStack."
    )
    parser.add_argument("--app-url", default=os.environ.get("BROWSERSTACK_APP_URL"))
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument(
        "--device",
        default=os.environ.get("BROWSERSTACK_DEVICE_NAME", "Google Pixel 7"),
    )
    parser.add_argument(
        "--platform-version",
        default=os.environ.get("BROWSERSTACK_PLATFORM_VERSION", "13.0"),
    )
    parser.add_argument(
        "--build-name",
        default=os.environ.get(
            "BROWSERSTACK_BUILD_NAME", "android-real-device-manual-schedules"
        ),
    )
    parser.add_argument(
        "--session-name",
        default=os.environ.get("BROWSERSTACK_SESSION_NAME", "manual-schedule-flow"),
    )
    parser.add_argument("--project-name", default="ancla-android")
    parser.add_argument("--appium-version", default="2.4.1")
    parser.add_argument("--timeout-seconds", type=float, default=60.0)
    parser.add_argument("--schedule-start-timeout-seconds", type=float, default=120.0)
    parser.add_argument("--schedule-end-timeout-seconds", type=float, default=210.0)
    return parser.parse_args()


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

def resolve_browserstack_credentials() -> tuple[str, str]:
    username = os.environ.get("BROWSERSTACK_USERNAME", "").strip()
    access_key = os.environ.get("BROWSERSTACK_ACCESS_KEY", "").strip()
    if username and access_key:
        return username, access_key
    validated_username, validated_access_key = validated_pair_from_env()
    if validated_username and validated_access_key:
        return validated_username, validated_access_key
    raise SystemExit(
        "Missing BrowserStack credentials. Provide trimmed BROWSERSTACK_USERNAME/"
        "BROWSERSTACK_ACCESS_KEY or BROWSERSTACK_VALIDATED_USERNAME/"
        "BROWSERSTACK_VALIDATED_ACCESS_KEY."
    )


def require_arg(name: str, value: str | None) -> str:
    trimmed = (value or "").strip()
    if not trimmed:
        raise SystemExit(f"Missing required argument: {name}")
    return trimmed


def xpath_literal(value: str) -> str:
    if "'" not in value:
        return f"'{value}'"
    if '"' not in value:
        return f'"{value}"'
    parts = value.split("'")
    return "concat(" + ", \"'\", ".join(f"'{part}'" for part in parts) + ")"


def text_xpath(text: str, *, contains: bool = False) -> str:
    literal = xpath_literal(text)
    if contains:
        return f"//*[contains(@text, {literal})]"
    return f"//*[@text={literal}]"


def wait_xpath(driver, xpath: str, timeout: float):
    return WebDriverWait(driver, timeout).until(
        EC.presence_of_element_located((By.XPATH, xpath))
    )


def maybe_find(driver, xpath: str):
    try:
        return driver.find_element(By.XPATH, xpath)
    except NoSuchElementException:
        return None


def wait_text(driver, text: str, *, timeout: float, contains: bool = False):
    return wait_xpath(driver, text_xpath(text, contains=contains), timeout)


def click_content_desc(driver, description: str, *, timeout: float) -> None:
    element = wait_xpath(
        driver,
        f"//*[@content-desc={xpath_literal(description)}]/ancestor-or-self::*[@clickable='true'][1]",
        timeout,
    )
    rect = element.rect
    tap_coordinates(
        driver,
        int(rect["x"] + rect["width"] / 2),
        int(rect["y"] + rect["height"] / 2),
    )


def wait_for_any_text(
    driver, texts: list[str], *, timeout: float, contains: bool = False
):
    deadline = time.time() + timeout
    while time.time() < deadline:
        for text in texts:
            found = maybe_find(driver, text_xpath(text, contains=contains))
            if found is not None:
                return text, found
        time.sleep(0.5)
    raise RuntimeError(
        f"Could not find any expected text within {timeout} seconds: {texts}"
    )


def tap_coordinates(driver, x: int, y: int) -> None:
    finger = PointerInput(interaction.POINTER_TOUCH, "finger")
    actions = ActionChains(driver)
    actions.w3c_actions = ActionBuilder(driver, mouse=finger)
    actions.w3c_actions.pointer_action.move_to_location(x, y)
    actions.w3c_actions.pointer_action.pointer_down()
    actions.w3c_actions.pointer_action.pause(0.08)
    actions.w3c_actions.pointer_action.release()
    actions.perform()
    time.sleep(0.8)


def swipe_up(driver, *, start_ratio: float = 0.82, end_ratio: float = 0.24) -> None:
    size = driver.get_window_size()
    center_x = int(size["width"] * 0.5)
    start_y = int(size["height"] * start_ratio)
    end_y = int(size["height"] * end_ratio)
    finger = PointerInput(interaction.POINTER_TOUCH, "finger")
    actions = ActionChains(driver)
    actions.w3c_actions = ActionBuilder(driver, mouse=finger)
    actions.w3c_actions.pointer_action.move_to_location(center_x, start_y)
    actions.w3c_actions.pointer_action.pointer_down()
    actions.w3c_actions.pointer_action.pause(0.06)
    actions.w3c_actions.pointer_action.move_to_location(center_x, end_y)
    actions.w3c_actions.pointer_action.pause(0.06)
    actions.w3c_actions.pointer_action.release()
    actions.perform()
    time.sleep(1.0)


def scroll_until_text(
    driver,
    text: str,
    *,
    timeout: float,
    contains: bool = False,
    max_swipes: int = 8,
):
    deadline = time.time() + timeout
    attempts = 0
    while time.time() < deadline:
        found = maybe_find(driver, text_xpath(text, contains=contains))
        if found is not None:
            return found
        attempts += 1
        if attempts > max_swipes:
            break
        swipe_up(driver)
    raise RuntimeError(f"Could not find text after scrolling: {text}")


def checkpoint(driver, out_dir: Path, steps: list[dict], stage: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    screenshot_path = out_dir / f"{len(steps) + 1:02d}-{stage}.png"
    xml_path = out_dir / f"{len(steps) + 1:02d}-{stage}.xml"
    driver.save_screenshot(str(screenshot_path))
    xml_path.write_text(driver.page_source, encoding="utf-8")
    steps.append(
        {
            "stage": stage,
            "screenshot": str(screenshot_path),
            "xml": str(xml_path),
        }
    )


def set_browserstack_status(driver, status: str, reason: str) -> None:
    safe_reason = reason.replace('"', "'")[:240]
    driver.execute_script(
        "browserstack_executor: {\"action\": \"setSessionStatus\", \"arguments\": "
        "{\"status\": \"%s\", \"reason\": \"%s\"}}" % (status, safe_reason)
    )


def run() -> dict:
    args = parse_args()
    username, access_key = resolve_browserstack_credentials()
    app_url = require_arg("--app-url", args.app_url)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    options = UiAutomator2Options()
    options.set_capability("platformName", "Android")
    options.set_capability("appium:automationName", "UiAutomator2")
    options.set_capability("appium:app", app_url)
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
            "debug": True,
            "deviceLogs": True,
            "idleTimeout": 300,
        },
    )

    client_config = AppiumClientConfig(remote_server_addr=CANONICAL_APPIUM_HOST)
    driver = webdriver.Remote(options=options, client_config=client_config)

    steps: list[dict] = []
    summary: dict[str, object] = {
        "device_name": args.device,
        "platform_version": args.platform_version,
        "app_url": app_url,
        "steps": steps,
        "session_id": driver.session_id,
    }
    session_status = "failed"
    session_reason = "manual Android schedule flow did not finish"

    try:
        initial_state, _ = wait_for_any_text(
            driver,
            HOME_MARKERS + ACTIVE_SESSION_MARKERS,
            timeout=args.timeout_seconds,
            contains=True,
        )
        if initial_state in ACTIVE_SESSION_MARKERS:
            checkpoint(driver, args.out_dir, steps, "schedule-started-immediate")
        else:
            checkpoint(driver, args.out_dir, steps, "seeded-home")
            wait_for_any_text(
                driver,
                ACTIVE_SESSION_MARKERS,
                timeout=args.schedule_start_timeout_seconds,
                contains=True,
            )
            checkpoint(driver, args.out_dir, steps, "schedule-started")

        wait_for_any_text(
            driver,
            HOME_MARKERS,
            timeout=args.schedule_end_timeout_seconds,
            contains=True,
        )
        checkpoint(driver, args.out_dir, steps, "schedule-ended-home")

        click_content_desc(driver, "Unlock tab", timeout=args.timeout_seconds)
        checkpoint(driver, args.out_dir, steps, "unlock-tab")

        scroll_until_text(
            driver,
            "Ended on schedule for",
            timeout=args.timeout_seconds,
            contains=True,
            max_swipes=10,
        )
        checkpoint(driver, args.out_dir, steps, "history-schedule")

        summary["result"] = "passed"
        session_status = "passed"
        session_reason = "schedule auto-start and auto-end passed"
    except Exception as exc:
        summary["result"] = "failed"
        summary["error"] = str(exc)
        failure_xml = args.out_dir / "zz-failure.xml"
        failure_png = args.out_dir / "zz-failure.png"
        try:
            driver.save_screenshot(str(failure_png))
            failure_xml.write_text(driver.page_source, encoding="utf-8")
            summary["failure_screenshot"] = str(failure_png)
            summary["failure_xml"] = str(failure_xml)
        except Exception as capture_exc:  # pragma: no cover
            summary["failure_capture_error"] = str(capture_exc)
        session_reason = str(exc)
        raise
    finally:
        summary["session_id"] = driver.session_id
        (args.out_dir / "summary.json").write_text(
            json.dumps(summary, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        try:
            set_browserstack_status(driver, session_status, session_reason)
        except Exception:
            pass
        driver.quit()

    return summary


if __name__ == "__main__":
    run()
