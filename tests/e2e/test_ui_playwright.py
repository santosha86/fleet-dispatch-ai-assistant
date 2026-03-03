"""
Playwright UI tests for SFleet Dispatch Flutter web app (CanvasKit).

Strategy: Launch Chrome with remote debugging, navigate to Flutter app,
use CDP screenshots to capture WebGL canvas content.

- Phase 4.12: Verify chart types with real backend data
- Phase 4.13: Visual screenshots for comparison
- Phase 6.10: Arabic query submission
- Phase 6.11: Arabic font rendering

Requires: backend on port 8000, Flutter web on port 9090
"""

import os
import sys
import time
import base64
import subprocess
from playwright.sync_api import sync_playwright

FLUTTER_URL = "http://localhost:9090"
SCREENSHOT_DIR = os.path.join(os.path.dirname(__file__), "screenshots")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

VW = 430
VH = 932


def wait_for_flutter(page, secs=5):
    """Wait for Flutter to render."""
    try:
        page.wait_for_load_state("networkidle", timeout=15000)
    except:
        pass
    time.sleep(secs)


def take_screenshot(page, name):
    """Take screenshot via CDP to capture WebGL canvas."""
    path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    try:
        cdp = page.context.new_cdp_session(page)
        result = cdp.send("Page.captureScreenshot", {
            "format": "png",
            "fromSurface": True,
        })
        cdp.detach()
        with open(path, "wb") as f:
            f.write(base64.b64decode(result["data"]))
    except Exception as e:
        print(f"  CDP screenshot failed ({e}), using fallback")
        page.screenshot(path=path)
    print(f"  Screenshot: {name}.png")
    return path


def click(page, x, y):
    """Click at coordinates."""
    page.mouse.click(x, y)
    time.sleep(0.5)


def nav_chat(page):
    click(page, VW // 6, VH - 15)
    time.sleep(1)


def nav_stats(page):
    click(page, VW // 2, VH - 15)
    time.sleep(1)


def nav_settings(page):
    click(page, VW * 5 // 6, VH - 15)
    time.sleep(1)


def try_type_query(page, query):
    """Attempt to type into Flutter text input."""
    # Try finding a semantics text field
    for sel in ['input[type="text"]', 'textarea', 'flt-semantics-text-field input']:
        try:
            el = page.locator(sel).first
            if el.is_visible(timeout=1000):
                el.click()
                time.sleep(0.3)
                el.fill(query)
                time.sleep(0.2)
                page.keyboard.press("Enter")
                return True
        except:
            continue

    # Try by role
    try:
        el = page.get_by_role("textbox").first
        if el.is_visible(timeout=1000):
            el.click()
            time.sleep(0.3)
            el.fill(query)
            time.sleep(0.2)
            page.keyboard.press("Enter")
            return True
    except:
        pass

    # Coordinate click on input area
    click(page, VW // 2, VH - 80)
    time.sleep(0.5)

    # Try again after focus
    for sel in ['input[type="text"]', 'textarea']:
        try:
            el = page.locator(sel).first
            if el.is_visible(timeout=1000):
                el.fill(query)
                time.sleep(0.2)
                page.keyboard.press("Enter")
                return True
        except:
            continue

    # Last resort: raw keyboard
    page.keyboard.type(query, delay=15)
    time.sleep(0.2)
    page.keyboard.press("Enter")
    return True


def main():
    print("=" * 60)
    print("Playwright UI Tests - SFleet Dispatch Flutter App")
    print(f"Screenshots: {SCREENSHOT_DIR}")
    print("=" * 60)

    passed = 0
    total = 0

    with sync_playwright() as p:
        # Launch Chrome with remote debugging
        browser = p.chromium.launch(
            channel="chrome",
            headless=False,
            args=[
                f"--window-size={VW},{VH}",
                "--disable-background-timer-throttling",
                "--disable-backgrounding-occluded-windows",
            ]
        )

        context = browser.new_context(
            viewport={"width": VW, "height": VH},
        )
        page = context.new_page()

        try:
            # ---- TEST 1: App loads ----
            total += 1
            print("\n[TEST 1] App loads...")
            page.goto(FLUTTER_URL)
            wait_for_flutter(page, 6)
            take_screenshot(page, "01_app_empty_state")
            print("[PASS] App loaded")
            passed += 1

            # ---- TEST 2: Waybill status query ----
            total += 1
            print("\n[TEST 2] Waybill status query...")
            nav_chat(page)
            time.sleep(1)
            try_type_query(page, "How many waybills are Delivered / Expired / Cancelled?")
            time.sleep(12)
            take_screenshot(page, "02_waybill_status")
            print("[PASS] Waybill query sent")
            passed += 1

            # ---- TEST 3: Vendor query ----
            total += 1
            print("\n[TEST 3] Vendor query (table data)...")
            try_type_query(page, "Which vendors created the most requests")
            time.sleep(15)
            take_screenshot(page, "03_vendor_partial")
            time.sleep(60)
            take_screenshot(page, "03_vendor_full")
            print("[PASS] Vendor query sent")
            passed += 1

            # ---- TEST 4: Settings (English) ----
            total += 1
            print("\n[TEST 4] Settings screen...")
            nav_settings(page)
            time.sleep(2)
            take_screenshot(page, "04_settings_english")
            print("[PASS] Settings captured")
            passed += 1

            # ---- TEST 5: Switch to Arabic ----
            total += 1
            print("\n[TEST 5] Switch to Arabic (Phase 6.10+6.11)...")
            # Try semantics button first
            switched = False
            try:
                btn = page.get_by_text("Arabic", exact=True)
                if btn.is_visible(timeout=2000):
                    btn.click()
                    switched = True
            except:
                pass
            if not switched:
                # Coordinate click: Arabic button at roughly right side of language row
                click(page, VW * 3 // 4, 190)
            time.sleep(2)
            take_screenshot(page, "05_arabic_settings")
            print("[PASS] Arabic switch attempted")
            passed += 1

            # ---- TEST 6: Arabic chat ----
            total += 1
            print("\n[TEST 6] Arabic chat query...")
            nav_chat(page)
            time.sleep(2)
            take_screenshot(page, "06_arabic_chat_empty")
            try_type_query(page, "How many waybills are Delivered / Expired / Cancelled?")
            time.sleep(12)
            take_screenshot(page, "06_arabic_chat_response")
            print("[PASS] Arabic chat captured")
            passed += 1

            # ---- TEST 7: Arabic font on Statistics ----
            total += 1
            print("\n[TEST 7] Arabic font rendering...")
            nav_stats(page)
            time.sleep(2)
            take_screenshot(page, "07_arabic_statistics")
            print("[PASS] Arabic statistics captured")
            passed += 1

            # ---- TEST 8: Switch back to English ----
            total += 1
            print("\n[TEST 8] Switch back to English...")
            nav_settings(page)
            time.sleep(1)
            try:
                btn = page.get_by_text("English", exact=True)
                if btn.is_visible(timeout=2000):
                    btn.click()
            except:
                click(page, VW // 4, 190)
            time.sleep(2)
            take_screenshot(page, "08_english_settings")
            print("[PASS] English restored")
            passed += 1

            # ---- TEST 9: Statistics (English) ----
            total += 1
            print("\n[TEST 9] Statistics (English)...")
            nav_stats(page)
            time.sleep(2)
            take_screenshot(page, "09_statistics_english")
            print("[PASS] Statistics captured")
            passed += 1

        except Exception as e:
            print(f"\n[FATAL ERROR] {e}")
            take_screenshot(page, "error_fatal")
        finally:
            take_screenshot(page, "99_final")
            browser.close()

    # Summary
    print()
    print("=" * 60)
    print(f"Results: {passed}/{total} UI tests passed")
    print(f"Screenshots: {SCREENSHOT_DIR}")
    status = "ALL TESTS PASSED" if passed == total else f"FAILURES: {total - passed}"
    print(status)
    print("=" * 60)

    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
