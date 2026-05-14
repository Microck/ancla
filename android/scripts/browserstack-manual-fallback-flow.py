from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.client_config import AppiumClientConfig
from selenium.common.exceptions import NoSuchElementException, TimeoutException
from selenium.webdriver import ActionChains
from selenium.webdriver.common.actions import interaction
from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.pointer_input import PointerInput
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

REPO_ROOT = Path("/home/ubuntu/workspace/ancla")
DEFAULT_OUT_DIR = REPO_ROOT / "tmp/android-browserstack-manual-fallback-flow"
CANONICAL_APPIUM_HOST = "https://hub-cloud.browserstack.com/wd/hub"
HOME_MARKERS = [
    "Ancla Android",
    "Finish Android setup",
    "Modes",
    "Schedules",
    "Create schedule",
    "Create preset",
    "Start unavailable",
    "Revisit setup instructions",
]
PARAGRAPH_CHALLENGE_PASSAGE = (
    "Attention drifts toward the nearest open door, even when the work in front of you is "
    "the work you chose. A locked boundary is not punishment. It is a promise that the next "
    "impulse does not get to outrank the longer intention."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Android real-device fallback flows on BrowserStack."
    )
    parser.add_argument("--app-url", default=os.environ.get("BROWSERSTACK_APP_URL"))
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument(
        "--device",
        default=os.environ.get("BROWSERSTACK_DEVICE_NAME", "Samsung Galaxy S23"),
    )
    parser.add_argument(
        "--platform-version",
        default=os.environ.get("BROWSERSTACK_PLATFORM_VERSION", "13.0"),
    )
    parser.add_argument(
        "--build-name",
        default=os.environ.get(
            "BROWSERSTACK_BUILD_NAME", "android-real-device-manual-fallbacks"
        ),
    )
    parser.add_argument(
        "--session-name",
        default=os.environ.get("BROWSERSTACK_SESSION_NAME", "manual-fallback-flow"),
    )
    parser.add_argument("--project-name", default="ancla-android")
    parser.add_argument("--appium-version", default="2.4.1")
    parser.add_argument("--timeout-seconds", type=float, default=45.0)
    parser.add_argument("--temp-unlock-seconds", type=float, default=65.0)
    parser.add_argument("--seeded-ready-state", action="store_true")
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


def clickable_text_xpath(text: str, *, contains: bool = False) -> str:
    return f"{text_xpath(text, contains=contains)}/ancestor-or-self::*[@clickable='true'][1]"


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


def scroll_until_text(
    driver,
    text: str,
    *,
    timeout: float,
    contains: bool = False,
    max_swipes: int = 7,
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


def reveal_text_any_direction(
    driver,
    text: str,
    *,
    timeout: float,
    contains: bool = False,
    max_swipes_each_way: int = 4,
):
    found = maybe_find(driver, text_xpath(text, contains=contains))
    if found is not None:
        return found
    for _ in range(max_swipes_each_way):
        swipe_down(driver)
        found = maybe_find(driver, text_xpath(text, contains=contains))
        if found is not None:
            return found
    for _ in range(max_swipes_each_way):
        swipe_up(driver)
        found = maybe_find(driver, text_xpath(text, contains=contains))
        if found is not None:
            return found
    raise RuntimeError(f"Could not reveal text in either direction: {text}")


def tap_element_center(driver, element) -> None:
    tap_coordinates(
        driver,
        int(element.rect["x"] + element.rect["width"] / 2),
        int(element.rect["y"] + element.rect["height"] / 2),
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


def swipe_down(driver, *, start_ratio: float = 0.24, end_ratio: float = 0.82) -> None:
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


def tap_bottom_action(driver, *, side: str = "right") -> None:
    size = driver.get_window_size()
    action_x_ratio = 0.77 if side == "right" else 0.5
    tap_coordinates(driver, int(size["width"] * action_x_ratio), int(size["height"] * 0.9))


def tap_mode_dialog_save(driver) -> None:
    size = driver.get_window_size()
    tap_coordinates(driver, int(size["width"] * 0.73), int(size["height"] * 0.81))


def tap_keyboard_hide(driver) -> None:
    size = driver.get_window_size()
    tap_coordinates(driver, int(size["width"] * 0.965), int(size["height"] * 0.985))


def tap_create_mode_slot(driver) -> None:
    size = driver.get_window_size()
    tap_coordinates(driver, int(size["width"] * 0.28), int(size["height"] * 0.52))


def click_text(driver, text: str, *, timeout: float, contains: bool = False) -> None:
    xpath = clickable_text_xpath(text, contains=contains)
    try:
        element = WebDriverWait(driver, timeout).until(
            EC.element_to_be_clickable((By.XPATH, xpath))
        )
    except TimeoutException:
        element = wait_text(driver, text, timeout=timeout, contains=contains)
    tap_element_center(driver, element)


def click_text_native(driver, text: str, *, timeout: float, contains: bool = False) -> None:
    xpath = clickable_text_xpath(text, contains=contains)
    element = wait_xpath(driver, xpath, timeout)
    element.click()
    time.sleep(0.8)


def scroll_and_click_text(
    driver,
    text: str,
    *,
    timeout: float,
    contains: bool = False,
    max_swipes: int = 7,
) -> None:
    deadline = time.time() + timeout
    attempts = 0
    while time.time() < deadline:
        target = maybe_find(driver, clickable_text_xpath(text, contains=contains))
        if target is not None:
            tap_element_center(driver, target)
            return
        target = maybe_find(driver, text_xpath(text, contains=contains))
        if target is not None:
            tap_element_center(driver, target)
            return
        attempts += 1
        if attempts > max_swipes:
            break
        swipe_up(driver)
    raise RuntimeError(f"Could not click text after scrolling: {text}")


def fill_first_edit_text(driver, value: str, *, timeout: float, index: int = 0) -> None:
    fields = WebDriverWait(driver, timeout).until(
        lambda current: current.find_elements(By.CLASS_NAME, "android.widget.EditText")
    )
    if len(fields) <= index:
        raise RuntimeError(
            f"Expected edit text index {index}, found {len(fields)} field(s)"
    )
    field = fields[index]
    field.click()
    time.sleep(0.3)
    for attempt in range(3):
        try:
            field.clear()
        except Exception:
            pass
        try:
            field.set_value(value)
        except Exception:
            field.send_keys(value)
        current_text = (field.get_attribute("text") or "").strip()
        if current_text == value:
            break
        if attempt < 2:
            try:
                field.click()
            except Exception:
                pass
            time.sleep(0.3)
    else:
        raise RuntimeError(
            f"Edit text index {index} did not accept the expected value {value!r}; "
            f"last seen text was {(field.get_attribute('text') or '').strip()!r}"
        )
    try:
        driver.execute_script("mobile: performEditorAction", {"action": "done"})
    except Exception:
        pass
    tap_keyboard_hide(driver)
    try:
        driver.hide_keyboard()
    except Exception:
        pass
    time.sleep(0.3)


def fill_dialog_edit_text(driver, value: str, *, timeout: float, index: int = 0) -> None:
    fields = WebDriverWait(driver, timeout).until(
        lambda current: current.find_elements(By.CLASS_NAME, "android.widget.EditText")
    )
    if len(fields) <= index:
        raise RuntimeError(
            f"Expected dialog edit text index {index}, found {len(fields)} field(s)"
        )
    field = fields[index]
    field.click()
    time.sleep(0.3)
    for attempt in range(3):
        try:
            field.clear()
        except Exception:
            pass
        try:
            field.set_value(value)
        except Exception:
            field.send_keys(value)
        current_text = (field.get_attribute("text") or "").strip()
        if current_text == value:
            break
        if attempt < 2:
            try:
                field.click()
            except Exception:
                pass
            time.sleep(0.3)
    else:
        raise RuntimeError(
            f"Dialog edit text index {index} did not accept the expected value {value!r}; "
            f"last seen text was {(field.get_attribute('text') or '').strip()!r}"
        )
    try:
        driver.execute_script("mobile: performEditorAction", {"action": "done"})
    except Exception:
        pass
    try:
        driver.hide_keyboard()
    except Exception:
        pass
    time.sleep(0.3)


def dismiss_editor_focus(driver) -> None:
    focused_field = maybe_find(
        driver,
        "//android.widget.EditText[@focused='true']",
    )
    if focused_field is None:
        return
    try:
        driver.back()
        time.sleep(0.4)
    except Exception:
        pass
    tap_keyboard_hide(driver)
    size = driver.get_window_size()
    tap_coordinates(driver, int(size["width"] * 0.88), int(size["height"] * 0.13))
    for candidate_text in ["Choose targets", "Set as default mode", "Create mode"]:
        candidate = maybe_find(driver, text_xpath(candidate_text))
        if candidate is not None:
            tap_element_center(driver, candidate)
            break
    try:
        driver.hide_keyboard()
    except Exception:
        pass
    time.sleep(0.4)


def dismiss_dialog_focus(driver) -> None:
    focused_field = maybe_find(
        driver,
        "//android.widget.EditText[@focused='true']",
    )
    if focused_field is None:
        return
    # The failsafe challenge is an AlertDialog. Outside taps dismiss it, so only
    # ask Android to hide the keyboard and leave the dialog contents untouched.
    try:
        driver.hide_keyboard()
    except Exception:
        pass
    time.sleep(0.4)


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


def ensure_ready_home(driver, out_dir: Path, steps: list[dict], timeout: float) -> None:
    wait_text(driver, "Finish Android setup", timeout=timeout)
    checkpoint(driver, out_dir, steps, "setup-gate")

    click_text(driver, "I finished the Android setup step", timeout=timeout)
    wait_text(driver, "Pair sample anchor", timeout=timeout)
    checkpoint(driver, out_dir, steps, "acknowledged")

    click_text(driver, "Pair sample anchor", timeout=timeout)
    wait_text(driver, "Pair anchor", timeout=timeout)
    click_text(driver, "Pair", timeout=timeout)
    wait_text(driver, "Desk anchor paired.", timeout=timeout)
    checkpoint(driver, out_dir, steps, "anchor-paired")

    swipe_up(driver)
    try:
        scroll_and_click_text(driver, "Create mode", timeout=timeout, max_swipes=4)
    except RuntimeError:
        # On some Samsung BrowserStack runs the mode card is visible after the first swipe
        # but the Create mode button is missing from the accessibility tree.
        tap_create_mode_slot(driver)
    wait_text(driver, "Mode name", timeout=timeout)
    checkpoint(driver, out_dir, steps, "mode-editor")
    fill_first_edit_text(driver, "Focus", timeout=timeout)
    checkpoint(driver, out_dir, steps, "mode-name-filled")
    click_text(driver, "App - Slack", timeout=timeout)
    checkpoint(driver, out_dir, steps, "mode-target-selected")
    home_state = save_mode_and_wait_for_home(driver, timeout=timeout)
    if home_state not in {"Ancla Android", "Finish Android setup"}:
        raise RuntimeError("Mode save did not return to the home shell.")
    checkpoint(driver, out_dir, steps, "home-ready")

    reveal_text_any_direction(driver, "Android blocking setup", timeout=timeout)
    switch = wait_xpath(
        driver,
        "//*[@text='Android blocking setup']/ancestor::android.view.View[@clickable='false'][1]//*[@checkable='true' and @clickable='true']",
        timeout,
    )
    tap_element_center(driver, switch)
    wait_text(driver, "Authorization ready.", timeout=timeout)
    checkpoint(driver, out_dir, steps, "authorization-ready")


def ensure_seeded_ready_home(
    driver, out_dir: Path, steps: list[dict], timeout: float
) -> None:
    wait_for_any_text(
        driver,
        ["Start block", "No blocking session is active.", "Ancla Android"],
        timeout=timeout,
    )
    checkpoint(driver, out_dir, steps, "seeded-home-ready")


def start_block(driver, out_dir: Path, steps: list[dict], timeout: float, stage: str) -> None:
    reveal_text_any_direction(driver, "Start block", timeout=timeout)
    click_text(driver, "Start block", timeout=timeout)
    wait_text(driver, "Scan anchor to start", timeout=timeout)
    click_text(driver, "Desk anchor", timeout=timeout)
    click_text(driver, "Confirm start", timeout=timeout)
    wait_text(driver, "You're anchored", timeout=timeout)
    checkpoint(driver, out_dir, steps, stage)


def verify_history_reason(
    driver, out_dir: Path, steps: list[dict], *, reason: str, stage: str, timeout: float
) -> None:
    scroll_and_click_text(driver, f"Reason: {reason}", timeout=timeout, max_swipes=8)
    checkpoint(driver, out_dir, steps, stage)


def return_home_from_history(driver, *, timeout: float) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        for text in HOME_MARKERS + [
            "Start block",
            "No blocking session is active.",
            "Android blocking setup",
        ]:
            if maybe_find(driver, text_xpath(text)) is not None:
                return
        swipe_down(driver)
    raise RuntimeError("Could not scroll back to the home sections after history review.")


def save_mode_and_wait_for_home(driver, *, timeout: float) -> str:
    deadline = time.time() + timeout
    attempts = 0
    while time.time() < deadline and attempts < 3:
        attempts += 1
        dismiss_editor_focus(driver)
        try:
            scroll_and_click_text(driver, "Save", timeout=min(8.0, timeout), max_swipes=4)
        except RuntimeError:
            if maybe_find(driver, text_xpath("Create mode")) is not None and maybe_find(
                driver, text_xpath("Mode name")
            ) is not None:
                tap_mode_dialog_save(driver)
            else:
                tap_bottom_action(driver, side="right")

        settle_deadline = time.time() + 8.0
        while time.time() < settle_deadline:
            for text in HOME_MARKERS:
                if maybe_find(driver, text_xpath(text)) is not None:
                    return text
            if maybe_find(driver, text_xpath("Mode name")) is None:
                break
            time.sleep(0.8)

        # Some BrowserStack Samsung runs keep the editor onscreen after the first tap even
        # though the footer is partly offscreen. Nudging the sheet upward exposes the footer.
        if maybe_find(driver, text_xpath("Mode name")) is not None:
            swipe_up(driver, start_ratio=0.85, end_ratio=0.45)

    raise RuntimeError(
        "Could not find any expected text within %.1f seconds: %s"
        % (timeout, HOME_MARKERS)
    )


def submit_failsafe_and_wait(
    driver,
    *,
    timeout: float,
    expected_texts: list[str],
) -> str:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            submit_label = maybe_find(driver, text_xpath("Submit"))
            if submit_label is not None:
                tap_element_center(driver, submit_label)
            else:
                structural_submit = maybe_find(
                    driver,
                    "(//android.widget.EditText/following-sibling::*[@clickable='true'])[last()]",
                )
                if structural_submit is not None:
                    tap_element_center(driver, structural_submit)
                else:
                    submit_button = wait_xpath(
                    driver,
                    clickable_text_xpath("Submit"),
                    min(8.0, timeout),
                    )
                    tap_element_center(driver, submit_button)
        except Exception:
            click_text(driver, "Submit", timeout=min(8.0, timeout))
        settle_deadline = time.time() + 8.0
        while time.time() < settle_deadline:
            for text in expected_texts:
                if maybe_find(driver, text_xpath(text)) is not None:
                    return text
            if maybe_find(driver, text_xpath("Failsafe challenge")) is None:
                break
            time.sleep(0.8)
    raise RuntimeError(f"Failsafe submit did not reach any expected text: {expected_texts}")


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
    session_reason = "manual Android fallback flow did not finish"

    try:
        if args.seeded_ready_state:
            ensure_seeded_ready_home(driver, args.out_dir, steps, args.timeout_seconds)
        else:
            ensure_ready_home(driver, args.out_dir, steps, args.timeout_seconds)

        for cycle in range(1, 6):
            start_block(
                driver,
                args.out_dir,
                steps,
                args.timeout_seconds,
                f"emergency-session-{cycle}",
            )
            scroll_and_click_text(
                driver,
                "Use emergency unbrick",
                timeout=args.timeout_seconds,
                contains=True,
                max_swipes=4,
            )
            wait_text(
                driver,
                "Emergency unbrick used. Session released.",
                timeout=args.timeout_seconds,
            )
            checkpoint(driver, args.out_dir, steps, f"emergency-release-{cycle}")

        verify_history_reason(
            driver,
            args.out_dir,
            steps,
            reason="Emergency unbrick",
            stage="history-emergency-unbrick",
            timeout=args.timeout_seconds,
        )
        return_home_from_history(driver, timeout=args.timeout_seconds)

        start_block(
            driver,
            args.out_dir,
            steps,
            args.timeout_seconds,
            "paragraph-session-started",
        )
        scroll_until_text(
            driver,
            "Type the failsafe passage",
            timeout=args.timeout_seconds,
            max_swipes=6,
        )
        checkpoint(driver, args.out_dir, steps, "paragraph-available")

        click_text(driver, "Type the failsafe passage", timeout=args.timeout_seconds)
        wait_text(driver, "Failsafe challenge", timeout=args.timeout_seconds)
        checkpoint(driver, args.out_dir, steps, "paragraph-dialog-opened")
        fill_dialog_edit_text(driver, "wrong", timeout=args.timeout_seconds)
        checkpoint(driver, args.out_dir, steps, "paragraph-dialog-filled-wrong")
        submit_failsafe_and_wait(
            driver,
            timeout=args.timeout_seconds,
            expected_texts=["The typed passage did not match.", "Type the failsafe passage"],
        )
        checkpoint(driver, args.out_dir, steps, "paragraph-failure")
        click_text(driver, "Cancel", timeout=args.timeout_seconds)

        click_text(driver, "Type the failsafe passage", timeout=args.timeout_seconds)
        wait_text(driver, "Failsafe challenge", timeout=args.timeout_seconds)
        checkpoint(driver, args.out_dir, steps, "paragraph-dialog-reopened")
        fill_dialog_edit_text(
            driver,
            PARAGRAPH_CHALLENGE_PASSAGE,
            timeout=args.timeout_seconds,
        )
        checkpoint(driver, args.out_dir, steps, "paragraph-dialog-filled-correct")
        submit_failsafe_and_wait(
            driver,
            timeout=args.timeout_seconds,
            expected_texts=[
                "Failsafe challenge passed. Session released.",
                "Reason: Paragraph challenge",
            ],
        )
        checkpoint(driver, args.out_dir, steps, "paragraph-success")

        verify_history_reason(
            driver,
            args.out_dir,
            steps,
            reason="Paragraph challenge",
            stage="history-paragraph-challenge",
            timeout=args.timeout_seconds,
        )
        return_home_from_history(driver, timeout=args.timeout_seconds)

        start_block(
            driver,
            args.out_dir,
            steps,
            args.timeout_seconds,
            "temp-unlock-session-started",
        )
        scroll_and_click_text(
            driver,
            "Temporary unlock for 60 seconds",
            timeout=args.timeout_seconds,
            max_swipes=4,
        )
        wait_text(
            driver,
            "Temporary unlock active for 60 seconds.",
            timeout=args.timeout_seconds,
        )
        checkpoint(driver, args.out_dir, steps, "temp-unlock-active")

        time.sleep(args.temp_unlock_seconds)
        wait_text(
            driver,
            "Temporary unlock ended.",
            timeout=args.timeout_seconds,
            contains=True,
        )
        checkpoint(driver, args.out_dir, steps, "temp-unlock-expired")

        summary["result"] = "passed"
        session_status = "passed"
        session_reason = (
            "emergency unbrick, paragraph challenge, and temporary unlock passed"
        )
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
        except Exception as capture_exc:  # pragma: no cover - best effort evidence path
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
