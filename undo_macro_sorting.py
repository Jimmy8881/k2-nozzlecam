#!/usr/bin/env python3
"""Remove the 3DO Nozzle Camera control category and layout from Fluidd."""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

CATEGORY_NAME = "3DO nozzle camera"

# List of macro names managed by the installation script to revert
MANAGED_MACROS = {
    "cam_settings", "LED_ON", "LED_OFF", "TOGGLE_CAM_LED", "RESET_CAM_LED_STATE",
    "saturation", "hue", "sharpness", "brightness", "contrast", "gamma", "gain",
    "exposure_absolute", "auto_exposure", "exposure_manual", "white_balance_manual",
    "white_balance_auto", "white_balance_temperature", "power_line_frequency_Off",
    "power_line_frequency_50", "power_line_frequency_60", "focus_manual", "focus_auto",
    "focus_absolute", "zoom_in", "zoom_mid", "zoom_out", "Zoom_absolute", "Tilt_absolute",
    "Pan_absolute"
}


class LayoutError(RuntimeError):
    pass


def remove_layout(namespace):
    """Safely strip out the 3DO Nozzle Camera category and reset managed macro layouts."""
    if not isinstance(namespace, dict):
        raise LayoutError("Fluidd database namespace is not an object")

    result = dict(namespace)
    macros = result.get("macros", {})
    if not isinstance(macros, dict):
        raise LayoutError("Fluidd macros database item is not an object")
    macros = dict(macros)

    categories = macros.get("categories", [])
    stored = macros.get("stored", [])
    if not isinstance(categories, list) or not isinstance(stored, list):
        return result

    categories = [dict(item) for item in categories if isinstance(item, dict)]
    stored = [dict(item) for item in stored if isinstance(item, dict)]

    # 1. Track any IDs assigned to the target category matching by its plain text name
    target_ids = set()
    cleaned_categories = []
    for item in categories:
        name = str(item.get("name", "")).casefold()
        item_id = str(item.get("id", ""))
        
        if name == CATEGORY_NAME.casefold():
            if item_id:
                target_ids.add(item_id)
            continue
        cleaned_categories.append(item)

    # 2. Scrub target settings from the stored macro buttons
    has_changes = len(categories) != len(cleaned_categories)
    cleaned_stored = []
    
    for item in stored:
        name = item.get("name", "")
        current_category = str(item.get("categoryId", "0"))
        
        # If macro belongs to the custom category ID or matches our text listing
        if current_category in target_ids or str(name).casefold() in {m.casefold() for m in MANAGED_MACROS}:
            # Revert to default/uncategorized category
            if current_category != "0":
                item["categoryId"] = "0"
                has_changes = True
            
            # Revert script-enforced visual modifications
            if "color" in item:
                del item["color"]
                has_changes = True
                
            # Clear alias if it matches our default uppercase generation pattern
            if "alias" in item and item["alias"] == str(name).upper():
                del item["alias"]
                has_changes = True

        cleaned_stored.append(item)

    if not has_changes:
        return result

    macros["categories"] = cleaned_categories
    macros["stored"] = cleaned_stored
    result["macros"] = macros
    return result


def _result_value(payload):
    if not isinstance(payload, dict):
        raise LayoutError("Moonraker returned a non-object response")
    if "error" in payload:
        raise LayoutError("Moonraker database request failed: {}".format(payload["error"]))
    response = payload.get("result", payload)
    if not isinstance(response, dict) or "value" not in response:
        raise LayoutError("Moonraker database response has no value")
    return response["value"]


def _request_json(url, method="GET", body=None):
    data = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if method == "GET" and exc.code == 404:
            return None
        raise LayoutError(str(exc))
    except (urllib.error.URLError, ValueError) as exc:
        raise LayoutError(str(exc))


def unconfigure(api_url):
    api_url = api_url.rstrip("/")
    query = urllib.parse.urlencode({"namespace": "fluidd"})
    payload = _request_json("{}/server/database/item?{}".format(api_url, query))
    
    if payload is None:
        return False
        
    namespace = _result_value(payload)
    updated = remove_layout(namespace)

    if updated.get("macros") == namespace.get("macros"):
        return False

    payload = _request_json(
        "{}/server/database/item".format(api_url),
        method="POST",
        body={"namespace": "fluidd", "key": "macros", "value": updated["macros"]},
    )
    _result_value(payload)
    return True


def main():
    if sys.argv[1:]:
        print("E: usage: unconfigure_3do_layout.py")
        return 2

    api_url = os.environ.get("MOONRAKER_URL", "http://127.0.0.1:7125")
    try:
        changed = unconfigure(api_url)
    except LayoutError as exc:
        print("E: could not remove Fluidd 3DO Camera layout: {}".format(exc))
        return 1

    if changed:
        print("I: successfully removed '{}' category and reset macro styles".format(CATEGORY_NAME))
        print("I: refresh Fluidd to apply the database changes")
    else:
        print("I: 3DO camera macro configurations already removed (no layout modifications found to revert)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
