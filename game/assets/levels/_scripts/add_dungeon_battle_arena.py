"""Idempotently add the first dungeon combat arena and guardian encounter.

This repair script keeps the real LDtk projects as the editable source of
truth without regenerating the older tutorial layouts around them.
"""

from __future__ import annotations

import copy
import json
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARENAS = ROOT / "battle_arenas.ldtk"
TUTORIAL = ROOT / "tutorial_dungeon.ldtk"
LEVEL_ID = 207
LEVEL_NAME = "DungeonStoneHall"
ARENA_ID = "dungeon_stone_hall"
NAMESPACE = uuid.UUID("5b7e5b9f-a85e-4f23-873d-63ff81d9a087")


def stable_iid(path: str) -> str:
    return str(uuid.uuid5(NAMESPACE, path))


def replace_iids(value, path: str = "level"):
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = f"{path}.{key}"
            if key == "iid":
                value[key] = stable_iid(child_path)
            elif key == "levelId":
                value[key] = LEVEL_ID
            else:
                replace_iids(child, child_path)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            replace_iids(child, f"{path}[{index}]")


def set_field(field: dict, value) -> None:
    field["__value"] = value
    editor_values = field.get("realEditorValues", [])
    if editor_values:
        editor_values[0]["params"] = [value]


def add_arena() -> None:
    project = json.loads(ARENAS.read_text(encoding="utf-8"))
    project["tutorialDesc"] = (
        "T-073/T-087 biome-consistent battle arenas: seven forest boards and "
        "one dungeon stone hall, all 17x7 with explicit deployment zones."
    )
    project["levels"] = [
        level for level in project["levels"] if level["identifier"] != LEVEL_NAME
    ]
    template = next(
        level for level in project["levels"] if level["identifier"] == "ArenaWindingCopse"
    )
    level = copy.deepcopy(template)
    level["identifier"] = LEVEL_NAME
    level["uid"] = LEVEL_ID
    level["worldX"] = max(item["worldX"] for item in project["levels"]) + 288
    level["worldY"] = 0
    level["__smartColor"] = "#777381"
    replace_iids(level)

    for layer in level["layerInstances"]:
        if layer["__identifier"] == "Entities":
            metadata = next(
                entity for entity in layer["entityInstances"] if entity["__identifier"] == "ArenaMetadata"
            )
            values = {
                "ArenaId": ARENA_ID,
                "Biome": "dungeon",
                "Tier": "mid",
                "Weight": 1,
                "Tags": "stone,hall",
                "MirrorSafe": True,
            }
            for field in metadata["fieldInstances"]:
                set_field(field, values[field["__identifier"]])
        elif layer["__identifier"] == "Ground":
            for tile in layer["gridTiles"]:
                # The runtime strip is ground, tree, path, dungeon floor, wall.
                tile["src"] = [64, 0] if tile["src"][0] == 16 else [48, 0]

    project["levels"].append(level)
    ARENAS.write_text(json.dumps(project, indent=2) + "\n", encoding="utf-8")


def wire_guardian() -> None:
    text = TUTORIAL.read_text(encoding="utf-8")
    if '"__value": "dungeon_guardian"' in text:
        return
    fight_pos = text.index('"identifier": "FightRoom"')
    enemy_pos = text.index('"__identifier": "Enemy"', fight_pos)
    unique_key = text.index('"__identifier": "UniqueId"', enemy_pos)
    field_start = text.rfind("{", enemy_pos, unique_key)

    # Find the end of the UniqueId field object without reserializing the
    # surrounding hand-authored/compact LDtk sections.
    depth = 0
    in_string = False
    escaped = False
    field_end = -1
    for index in range(field_start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                field_end = index
                break
    if field_end < 0:
        raise RuntimeError("Could not locate FightRoom UniqueId field end")

    line_start = text.rfind("\n", 0, field_start) + 1
    indent = text[line_start:field_start]
    encounter = {
        "__identifier": "EncounterId",
        "__type": "String",
        "__value": "dungeon_guardian",
        "__tile": None,
        "defUid": 1009,
        "realEditorValues": [{"id": "V_String", "params": ["dungeon_guardian"]}],
    }
    encoded = json.dumps(encounter, indent=1)
    encoded = "\n".join(indent + line if line else line for line in encoded.splitlines())
    text = text[: field_end + 1] + ",\n" + encoded + text[field_end + 1 :]
    TUTORIAL.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    add_arena()
    wire_guardian()
    print("added DungeonStoneHall and wired dungeon_guardian")
