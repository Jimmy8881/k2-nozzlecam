#!/usr/bin/env python3
"""Seed the Fluidd layout for the 3DO Nozzle Camera control macros."""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

CATEGORY_NAME = "3DO nozzle camera"

# Macro Layout configuration mapping (Macro Name, Button Label Alias, Fluidd Color Hex)
MACRO_LAYOUT = (
    # Core Admin
    ("cam_settings", "CAM_SETTINGS", "#2196F3"),
    
    # LED Control
    ("LED_ON", "LED_ON", "#FF9800"),
    ("LED_OFF", "LED_OFF", "#FF9800"),
    ("TOGGLE_CAM_LED", "TOGGLE_CAM_LED", "#FF9800"),
    ("RESET_CAM_LED_STATE", "RESET_CAM_LED_STATE", "#FF9800"),
    
    # Image Quality / Color
    ("saturation", "SATURATION", "#1AED07"),
    ("hue", "HUE", "#1AED07"),
    ("sharpness", "SHARPNESS", "#1AED07"),
    
    # Exposure
    ("brightness", "BRIGHTNESS", "#9C27B0"),
    ("contrast", "CONTRAST", "#9C27B0"),
    ("gamma", "GAMMA", "#9C27B0"),
    ("gain", "GAIN", "#9C27B0"),
    ("exposure_absolute", "EXPOSURE_ABSOLUTE", "#9C27B0"),
    ("auto_exposure", "AUTO_EXPOSURE", "#9C27B0"),
    ("exposure_manual", "EXPOSURE_MANUAL", "#9C27B0"),
    
    # Temperature / White Balance
    ("white_balance_manual", "WHITE_BALANCE_MANUAL", "#00BCD4"),
    ("white_balance_auto", "WHITE_BALANCE_AUTO", "#00BCD4"),
    ("white_balance_temperature", "WHITE_BALANCE_TEMP", "#00BCD4"),
    
    # Anti-Flicker / Utility
    ("power_line_frequency_Off", "FREQ_OFF", "#2196F3"),
    ("power_line_frequency_50", "FREQ_50HZ", "#2196F3"),
    ("power_line_frequency_60", "FREQ_60HZ", "#2196F3"),
    
    # Focus
    ("focus_manual", "FOCUS_MANUAL", "#E91E63"),
    ("focus_auto", "FOCUS_AUTO", "#E91E63"),
    ("focus_absolute", "FOCUS_ABSOLUTE", "#E91E63"),
    
    # Transformation (Zoom, Tilt, Pan)
    ("zoom_in", "ZOOM_IN", "#E91E63"),
    ("zoom_mid", "ZOOM_MID", "#E91E63"),
    ("zoom_out", "ZOOM_OUT", "#E91E63"),
    ("Zoom_absolute", "ZOOM_ABSOLUTE", "#E91E63"),
    ("Tilt_absolute", "TILT_ABSOLUTE", "#E91E63"),
    ("Pan_absolute", "PAN_ABSOLUTE", "#E91E63"),
)


class LayoutError(RuntimeError):
    pass


def merge_layout(namespace):
    """Return Fluidd namespace data with 3DO Nozzle Camera layout defaults added."""
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
        raise LayoutError("Fluidd macros database arrays are invalid")

    categories = [dict(item) for item in categories if isinstance(item, dict)]
    stored = [dict(item) for item in stored if isinstance(item, dict)]

    # Locate an existing category by name string matching
    category = next(
        (
            item
            for item in categories
            if str(item.get("name", "")).casefold() == CATEGORY_NAME.casefold()
            and item.get("id")
        ),
        None,
    )
    
    if category is None:
        category_id = CATEGORY_NAME
        categories.append({"id": category_id, "name": CATEGORY_NAME})
    else:
        category_id = str(category["id"])

    valid_category_ids = {str(item.get("id")) for item in categories if item.get("id")}
    category_names_by_id = {
        str(item.get("id")): str(item.get("name", "")).casefold()
        for item in categories
        if item.get("id")
    }
    by_name = {
        str(item.get("name", "")).casefold(): index
        for index, item in enumerate(stored)
        if item.get("name")
    }

    for name, alias, color in MACRO_LAYOUT:
        # Determine the targets to process (handles auto_exposure / exposure_auto matching)
        target_names = [name.casefold()]
        if name.casefold() == "auto_exposure":
            target_names.append("exposure_auto")

        for target in target_names:
            index = by_name.get(target)
            if index is None:
                stored.append(
                    {
                        "name": target,
                        "alias": alias,
                        "visible": True,
                        "disabledWhilePrinting": False,
                        "color": color,
                        "categoryId": category_id,
                    }
                )
                by_name[target] = len(stored) - 1
                continue

            item = stored[index]
            if not item.get("alias"):
                item["alias"] = alias
            item["color"] = color
            
            current_category = str(item.get("categoryId", "0"))
            if (
                current_category == "0"
                or current_category not in valid_category_ids
                or category_names_by_id.get(current_category) == "uncategorized"
            ):
                item["categoryId"] = category_id

    macros["categories"] = categories
    macros["stored"] = stored
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


def _request_json(url, method="GET", body=None, allow_missing=False):
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
        if allow_missing and method == "GET" and exc.code == 404:
            return None
        raise LayoutError(str(exc))
    except (urllib.error.URLError, ValueError) as exc:
        raise LayoutError(str(exc))


def configure(api_url):
    api_url = api_url.rstrip("/")
    query = urllib.parse.urlencode({"namespace": "fluidd"})
    payload = _request_json(
        "{}/server/database/item?{}".format(api_url, query), allow_missing=True
    )
    namespace = {} if payload is None else _result_value(payload)
    updated = merge_layout(namespace)

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
        print("E: usage: configure_3do_layout.py")
        return 2

    api_url = os.environ.get("MOONRAKER_URL", "http://127.0.0.1:7125")
    try:
        changed = configure(api_url)
    except LayoutError as exc:
        print("E: could not configure Fluidd 3DO Camera macro layout: {}".format(exc))
        return 1

    if changed:
        print(
            "I: configured Fluidd macros in the '{}' category".format(CATEGORY_NAME)
        )
        print("I: refresh Fluidd to load the aliases, category, and colors")
    else:
        print("I: 3DO macro layout is already configured")

    return 0


if __name__ == "__main__":
    sys.exit(main())
