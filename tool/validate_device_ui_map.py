#!/usr/bin/env python3
"""Offline structural validation for tool/device_ui_map.json."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "tool" / "device_ui_map.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_bounds(value: object, width: int, height: int, owner: str) -> None:
    require(isinstance(value, list) and len(value) == 4, f"{owner}: invalid bounds")
    left, top, right, bottom = value
    require(
        all(isinstance(item, (int, float)) for item in value),
        f"{owner}: bounds must be numeric",
    )
    require(0 <= left <= right <= width, f"{owner}: horizontal bounds outside profile")
    require(0 <= top <= bottom <= height, f"{owner}: vertical bounds outside profile")


def validate_text(value: object, owner: str) -> None:
    if value is None:
        return
    require(isinstance(value, str), f"{owner}: expected text")
    require("\ufffd" not in value, f"{owner}: contains Unicode replacement characters")


def main() -> None:
    data = json.loads(MAP_PATH.read_text(encoding="utf-8-sig"))
    require(data.get("schemaVersion") == 2, "device UI map schemaVersion must be 2")
    require(data.get("package") == "com.mystyle.purelive", "unexpected package name")

    profiles = data.get("profiles")
    require(isinstance(profiles, dict) and profiles, "profiles must be a non-empty object")
    require(data.get("defaultProfile") in profiles, "defaultProfile does not exist")

    total_points = 0
    total_sequences = 0
    for profile_name, profile in profiles.items():
        width = profile.get("width")
        height = profile.get("height")
        orientation = profile.get("orientation")
        require(isinstance(width, int) and width > 0, f"{profile_name}: invalid width")
        require(isinstance(height, int) and height > 0, f"{profile_name}: invalid height")
        require(orientation in {"portrait", "landscape"}, f"{profile_name}: invalid orientation")
        require(
            (orientation == "portrait") == (height >= width),
            f"{profile_name}: orientation does not match dimensions",
        )

        points = profile.get("points", {})
        gestures = profile.get("gestures", {})
        sequences = profile.get("sequences", {})
        require(isinstance(points, dict), f"{profile_name}: points must be an object")
        require(isinstance(gestures, dict), f"{profile_name}: gestures must be an object")
        require(isinstance(sequences, dict), f"{profile_name}: sequences must be an object")

        for point_name, point in points.items():
            x, y = point.get("x"), point.get("y")
            require(isinstance(x, (int, float)), f"{profile_name}.{point_name}: invalid x")
            require(isinstance(y, (int, float)), f"{profile_name}.{point_name}: invalid y")
            require(0 <= x <= width, f"{profile_name}.{point_name}: x outside profile")
            require(0 <= y <= height, f"{profile_name}.{point_name}: y outside profile")
            require(bool(point.get("label")), f"{profile_name}.{point_name}: missing label")
            validate_text(point.get("label"), f"{profile_name}.{point_name}.label")
            semantic = point.get("semantic")
            if isinstance(semantic, list):
                require(bool(semantic), f"{profile_name}.{point_name}: empty semantic list")
                for semantic_index, item in enumerate(semantic):
                    validate_text(item, f"{profile_name}.{point_name}.semantic[{semantic_index}]")
            else:
                validate_text(semantic, f"{profile_name}.{point_name}.semantic")
            if "bounds" in point:
                validate_bounds(point["bounds"], width, height, f"{profile_name}.{point_name}")

        for gesture_name, gesture in gestures.items():
            for axis, limit in (("x1", width), ("x2", width), ("y1", height), ("y2", height)):
                value = gesture.get(axis)
                require(isinstance(value, (int, float)), f"{profile_name}.{gesture_name}: invalid {axis}")
                require(0 <= value <= limit, f"{profile_name}.{gesture_name}: {axis} outside profile")

        for sequence_name, sequence in sequences.items():
            require(isinstance(sequence, list) and sequence, f"{profile_name}.{sequence_name}: empty sequence")
            for index, step in enumerate(sequence):
                actions = [key for key in ("tap", "tapSemantic", "swipe", "wait") if key in step]
                require(len(actions) == 1, f"{profile_name}.{sequence_name}[{index}]: expected one action")
                if "tap" in step:
                    require(step["tap"] in points, f"{profile_name}.{sequence_name}: missing point {step['tap']}")
                if "swipe" in step:
                    require(
                        step["swipe"] in gestures,
                        f"{profile_name}.{sequence_name}: missing gesture {step['swipe']}",
                    )
                wait_ms = step.get("waitMs", 0)
                require(isinstance(wait_ms, int) and wait_ms >= 0, f"{profile_name}.{sequence_name}: invalid waitMs")
                if "wait" in step:
                    require(step["wait"] is True, f"{profile_name}.{sequence_name}[{index}]: wait must be true")
                    require(wait_ms > 0, f"{profile_name}.{sequence_name}[{index}]: wait action requires waitMs")

        for screen_name, screen in profile.get("screens", {}).items():
            require(screen.get("orientation") == orientation, f"{profile_name}.{screen_name}: orientation mismatch")
            require(screen.get("width") == width, f"{profile_name}.{screen_name}: width mismatch")
            require(screen.get("height") == height, f"{profile_name}.{screen_name}: height mismatch")
            require(screen.get("topPackage") == data["package"], f"{profile_name}.{screen_name}: wrong package")
            nodes = screen.get("nodes")
            require(isinstance(nodes, list), f"{profile_name}.{screen_name}: nodes must be a list")
            for node_index, node in enumerate(nodes):
                owner = f"{profile_name}.{screen_name}.nodes[{node_index}]"
                validate_text(node.get("text"), f"{owner}.text")
                validate_text(node.get("semantic"), f"{owner}.semantic")
                validate_text(node.get("resourceId"), f"{owner}.resourceId")
                validate_text(node.get("class"), f"{owner}.class")
                validate_bounds(node.get("bounds"), width, height, owner)
                center = node.get("center")
                require(isinstance(center, list) and len(center) == 2, f"{owner}: invalid center")
                center_x, center_y = center
                require(
                    isinstance(center_x, (int, float)) and 0 <= center_x <= width,
                    f"{owner}: center x outside profile",
                )
                require(
                    isinstance(center_y, (int, float)) and 0 <= center_y <= height,
                    f"{owner}: center y outside profile",
                )

        total_points += len(points)
        total_sequences += len(sequences)

    print(
        f"device UI map valid: {len(profiles)} profiles, "
        f"{total_points} points, {total_sequences} sequences"
    )


if __name__ == "__main__":
    main()
