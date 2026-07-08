#!/usr/bin/env python3
"""Bootstrap generator for this project's .ldtk files (LDtk 1.5.3 JSON).

The LDtk desktop app is the intended authoring tool once Kayden starts real
map work; until then these files are generated deterministically so the
import pipeline (T-004/T-031) and the rooms built on it (T-011 forest,
T-027 tutorial dungeon) are reproducible from code review alone.

Run from the repo root or this directory:
    python3 game/assets/levels/_scripts/generate_levels.py

Entity-layer conventions consumed by scripts/ldtk/entities_post_import.gd:
PlayerSpawn, Npc{Lines,Heals,ColorHex}, Enemy{StatsId,IsBoss,LeashRadius,
UniqueId}, LockedDoor{KeyId,LinkId}, PushableBlock{LinkId},
PressurePlate{Id,TargetId}, Chest{Id,KeyId,RewardId}, Lever,
Doorway{TargetRoom}.
"""
import json
import os

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GRID = 16
TILESET = {"uid": 1, "rel": "../art/tilesets/test_tiles.png"}
# test_tiles.png columns: 0 grass, 1 tree-on-grass, 2 path, 3 cave floor, 4 cave wall
T_GRASS, T_TREE, T_PATH, T_CAVE_FLOOR, T_CAVE_WALL = 0, 1, 2, 3, 4

LAYER_ENTITIES, LAYER_GROUND, LAYER_WALL, LAYER_PIT = 6, 2, 3, 7
ENTITY_UIDS = {
    "PlayerSpawn": 10, "Npc": 11, "Enemy": 12, "LockedDoor": 13,
    "PushableBlock": 14, "PressurePlate": 15, "Chest": 16, "Lever": 17,
    "Doorway": 18,
}

_iid_counter = 0


def iid():
    global _iid_counter
    _iid_counter += 1
    return "00000000-0000-0000-0000-%012d" % _iid_counter


def base_layer_def(identifier, uid, kind, int_values=None, tileset_uid=None):
    return {
        "gridSize": GRID, "displayOpacity": 1, "pxOffsetX": 0, "pxOffsetY": 0,
        "parallaxFactorX": 0, "parallaxFactorY": 0, "parallaxScaling": True,
        "intGridValuesGroups": [], "autoRuleGroups": [],
        "autoSourceLayerDefUid": None, "tilePivotX": 0, "tilePivotY": 0,
        "canSelectWhenInactive": True, "doc": None, "hideInList": False,
        "hideFieldsWhenInactive": True, "inactiveOpacity": 1,
        "renderInWorldView": True, "requiredTags": [], "excludedTags": [],
        "uiColor": None, "uiFilterTags": [], "useAsyncRender": False,
        "guideGridWid": 0, "guideGridHei": 0, "biomeFieldUid": None,
        "__type": kind, "identifier": identifier, "type": kind, "uid": uid,
        "intGridValues": int_values or [], "tilesetDefUid": tileset_uid,
    }


def entity_def(identifier, uid, color):
    return {
        "identifier": identifier, "uid": uid, "tags": [],
        "exportToToc": False, "allowOutOfBounds": False, "doc": None,
        "width": GRID, "height": GRID, "resizableX": False, "resizableY": False,
        "minWidth": None, "minHeight": None, "maxWidth": None, "maxHeight": None,
        "keepAspectRatio": False, "tileOpacity": 1, "fillOpacity": 1,
        "lineOpacity": 1, "hollow": False, "color": color,
        "renderMode": "Rect", "showName": True, "tilesetId": None,
        "tileRenderMode": "FitInside", "tileRect": None, "uiTileRect": None,
        "nineSliceBorders": [], "maxCount": 0, "limitScope": "PerLevel",
        "limitBehavior": "MoveLastOne", "pivotX": 0, "pivotY": 0,
        "fieldDefs": [],
    }


def field_instance(identifier, ftype, value):
    return {"__identifier": identifier, "__type": ftype, "__value": value,
            "__tile": None, "defUid": None, "realEditorValues": []}


def entity_instance(identifier, cell, fields=None):
    fis = []
    for name, (ftype, value) in (fields or {}).items():
        fis.append(field_instance(name, ftype, value))
    return {
        "__identifier": identifier, "__grid": [cell[0], cell[1]],
        "__pivot": [0, 0], "__tags": [], "__tile": None,
        "__smartColor": "#FFCC00",
        "__worldX": None, "__worldY": None,
        "iid": iid(), "width": GRID, "height": GRID,
        "defUid": ENTITY_UIDS[identifier],
        "px": [cell[0] * GRID, cell[1] * GRID],
        "fieldInstances": fis,
    }


def layer_instance(identifier, kind, uid, cwid, chei, level_uid,
                   int_csv=None, tiles=None, entities=None, tileset=None):
    return {
        "__identifier": identifier, "__type": kind, "__cWid": cwid,
        "__cHei": chei, "__gridSize": GRID, "__opacity": 1,
        "__pxTotalOffsetX": 0, "__pxTotalOffsetY": 0,
        "__tilesetDefUid": tileset["uid"] if tileset else None,
        "__tilesetRelPath": tileset["rel"] if tileset else None,
        "iid": iid(), "levelId": level_uid, "layerDefUid": uid,
        "pxOffsetX": 0, "pxOffsetY": 0, "visible": True,
        "optionalRules": [], "intGridCsv": int_csv or [],
        "autoLayerTiles": [], "seed": 1, "overrideTilesetUid": None,
        "gridTiles": tiles or [], "entityInstances": entities or [],
    }


def grid_tile(cell, t, cwid):
    return {"px": [cell[0] * GRID, cell[1] * GRID], "src": [t * GRID, 0],
            "f": 0, "t": t, "d": [cell[0] + cell[1] * cwid], "a": 1}


def make_level(identifier, uid, wx, grid_map, entities, bg="#1A1A2E"):
    """grid_map: list of strings. W = wall, P = pit, everything else floor.
    Tile lookup decides the Ground tile per char (see tile_for)."""
    chei = len(grid_map)
    cwid = len(grid_map[0])
    wall_csv, pit_csv, tiles = [], [], []
    for y, row in enumerate(grid_map):
        assert len(row) == cwid, f"ragged row {y} in {identifier}"
        for x, ch in enumerate(row):
            wall_csv.append(1 if ch == "W" else 0)
            pit_csv.append(1 if ch == "P" else 0)
            t = tile_for(identifier, ch)
            if t is not None:
                tiles.append(grid_tile((x, y), t, cwid))
    return {
        "identifier": identifier, "iid": iid(), "uid": uid,
        "worldX": wx, "worldY": 0, "worldDepth": 0,
        "pxWid": cwid * GRID, "pxHei": chei * GRID,
        "__bgColor": bg, "bgColor": None, "useAutoIdentifier": False,
        "bgRelPath": None, "bgPos": None, "bgPivotX": 0.5, "bgPivotY": 0.5,
        "__smartColor": "#ADADB5", "__bgPos": None, "externalRelPath": None,
        "fieldInstances": [], "__neighbours": [],
        "layerInstances": [
            layer_instance("Entities", "Entities", LAYER_ENTITIES, cwid, chei,
                           uid, entities=entities),
            layer_instance("Wall", "IntGrid", LAYER_WALL, cwid, chei, uid,
                           int_csv=wall_csv),
            layer_instance("Pit", "IntGrid", LAYER_PIT, cwid, chei, uid,
                           int_csv=pit_csv),
            layer_instance("Ground", "Tiles", LAYER_GROUND, cwid, chei, uid,
                           tiles=tiles, tileset=TILESET),
        ],
    }


def tile_for(level_identifier, ch):
    if level_identifier == "Forest":
        return {"T": T_TREE, "X": T_PATH}.get(ch, T_GRASS)
    # Dungeon rooms: cave walls, cave floor, pits render as background void.
    if ch == "W":
        return T_CAVE_WALL
    if ch == "P":
        return None
    return T_CAVE_FLOOR


def make_world(levels, world_name):
    return {
        "__header__": {
            "fileType": "LDtk Project JSON", "app": "LDtk",
            "doc": "https://ldtk.io/json",
            "schema": "https://ldtk.io/files/JSON_SCHEMA.json",
            "appAuthor": "Sebastien 'deepnight' Benard",
            "appVersion": "1.5.3", "url": "https://ldtk.io",
        },
        "iid": iid(), "jsonVersion": "1.5.3", "appBuildId": 473703,
        "nextUid": 1000, "identifierStyle": "Capitalize", "toc": [],
        "worldLayout": "GridVania", "worldGridWidth": 256,
        "worldGridHeight": 256, "defaultLevelWidth": 320,
        "defaultLevelHeight": 192, "defaultGridSize": GRID,
        "defaultEntityWidth": GRID, "defaultEntityHeight": GRID,
        "bgColor": "#40465B", "defaultLevelBgColor": "#1A1A2E",
        "defaultPivotX": 0, "defaultPivotY": 0, "externalLevels": False,
        "simplifiedExport": False, "imageExportMode": "None",
        "exportLevelBg": False, "pngFilePattern": None, "backupOnSave": False,
        "backupLimit": 10, "backupRelPath": None,
        "levelNamePattern": "Level_%idx", "minifyJson": False,
        "exportPng": False, "exportTiled": False, "flags": [],
        "customCommands": [], "worlds": [], "dummyWorldIid": iid(),
        "tutorialDesc": world_name,
        "defs": {
            "layers": [
                base_layer_def("Entities", LAYER_ENTITIES, "Entities"),
                base_layer_def("Wall", LAYER_WALL, "IntGrid", int_values=[
                    {"value": 1, "identifier": "Wall", "color": "#000000",
                     "tile": None, "groupUid": 0}]),
                base_layer_def("Pit", LAYER_PIT, "IntGrid", int_values=[
                    {"value": 1, "identifier": "Pit", "color": "#20142E",
                     "tile": None, "groupUid": 0}]),
                base_layer_def("Ground", LAYER_GROUND, "Tiles",
                               tileset_uid=TILESET["uid"]),
            ],
            "entities": [
                entity_def("PlayerSpawn", ENTITY_UIDS["PlayerSpawn"], "#4FC3F7"),
                entity_def("Npc", ENTITY_UIDS["Npc"], "#EEC643"),
                entity_def("Enemy", ENTITY_UIDS["Enemy"], "#D9312E"),
                entity_def("LockedDoor", ENTITY_UIDS["LockedDoor"], "#8A5A2B"),
                entity_def("PushableBlock", ENTITY_UIDS["PushableBlock"], "#8E8A84"),
                entity_def("PressurePlate", ENTITY_UIDS["PressurePlate"], "#9FA8B5"),
                entity_def("Chest", ENTITY_UIDS["Chest"], "#C08A3E"),
                entity_def("Lever", ENTITY_UIDS["Lever"], "#B8944D"),
                entity_def("Doorway", ENTITY_UIDS["Doorway"], "#7E57C2"),
            ],
            "tilesets": [{
                "__cWid": 5, "__cHei": 1, "identifier": "TestTiles",
                "uid": TILESET["uid"], "relPath": TILESET["rel"],
                "embedAtlas": None, "pxWid": 80, "pxHei": 16,
                "tileGridSize": GRID, "spacing": 0, "padding": 0, "tags": [],
                "tagsSourceEnumUid": None, "enumTags": [], "customData": [],
            }],
            "enums": [], "externalEnums": [], "levelFields": [],
        },
        "levels": levels,
    }


# --- Forest (T-011): the exact 34x20 layout the code-built slice shipped ---
# T tree/wall, P player spawn, N quest NPC, H healer, E slime, B boss,
# D locked door (+doorway into the tutorial dungeon), X path/cave-mouth.
FOREST_MAP = [
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    "T.....TT......T..........TXXXXTTTT",
    "T..N..TT......T....E.....TXXXXTTTT",
    "T.....TT..TT..............TTDTTTTT",
    "T.P.......TT....TT..........B....T",
    "T.....TT........TT.....TT........T",
    "TT.TTTTT..TT........E..TT...TT...T",
    "T.........TT..TT........T...TT...T",
    "T..TT.........TT...TTT...........T",
    "T..TT...E......T...T......E....TTT",
    "T...............TTTT.........TTTTT",
    "TTTT...TT...........T........TTTTT",
    "T......TT....E......T...TT.....TTT",
    "T...T...........TTT.T...TT.......T",
    "T...T....TT.....T......H.........T",
    "T.TTT....TT.....T....TTTT..TT..TTT",
    "T........E......T....TTTT..TT..TTT",
    "T....TT........TT..............TTT",
    "T.....T........T....E......TT..TTT",
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

NPC_LINES = [
    "Oh, hello there, friend!",
    "Slimes have overrun the whole forest, and their big boss",
    "squats by the old east door with the key in its belly.",
    "Bonk the little ones or slip past them - but that boss",
    "won't budge. If you get hurt, my friend by the fire can help!",
]
HEALER_LINES = [
    "You look roughed up, adventurer.",
    "Sit by my fire a moment... there. Right as rain!",
    "(HP fully restored.)",
]


def forest_level():
    ents = []
    grid = []
    for y, row in enumerate(FOREST_MAP):
        cells = []
        for x, ch in enumerate(row):
            c = (x, y)
            if ch == "P":
                ents.append(entity_instance("PlayerSpawn", c))
            elif ch == "N":
                ents.append(entity_instance("Npc", c, {
                    "Lines": ("Array<String>", NPC_LINES)}))
            elif ch == "H":
                ents.append(entity_instance("Npc", c, {
                    "Lines": ("Array<String>", HEALER_LINES),
                    "Heals": ("Bool", True),
                    "ColorHex": ("String", "#73D9BF")}))
            elif ch == "E":
                ents.append(entity_instance("Enemy", c, {
                    "StatsId": ("String", "forest_slime")}))
            elif ch == "B":
                ents.append(entity_instance("Enemy", c, {
                    "StatsId": ("String", "boss_slime"),
                    "IsBoss": ("Bool", True),
                    "LeashRadius": ("Int", 2),
                    "UniqueId": ("String", "forest_boss")}))
            elif ch == "D":
                ents.append(entity_instance("LockedDoor", c, {
                    "KeyId": ("String", "forest_key"),
                    "LinkId": ("String", "forest_door")}))
                ents.append(entity_instance("Doorway", c, {
                    "TargetRoom": ("String", "tutorial_hub")}))
            # map chars to W/P/other for wall/pit/tiles
            cells.append("W" if ch == "T" else ch)
        grid.append("".join(cells))
    return make_level("Forest", 100, 0, grid, ents, bg="#12210F")


# --- Tutorial dungeon (T-027): hub, pit room, fight room ---------------------
# Hub: entry door locks behind (7,12); plate (5,5) center of the 3x3 with the
# block (4,4) in a corner and a 2-cell margin; chest (10,3) visible from the
# start; lever (1,10) resets; east door (14,6) plate-driven to the pit room;
# west door (0,6) one-way from the fight-room loop.
HUB_MAP = [
    "WWWWWWWWWWWWWWW",
    "W.............W",
    "W.............W",
    "W.............W",
    "W.............W",
    "W.............W",
    "...............",  # row 6: west (x0) and east (x14) door gaps
    "W.............W",
    "W.............W",
    "W.............W",
    "W.............W",
    "W.............W",
    "WWWWWWW.WWWWWWW",  # row 12: entry-door gap at x7
]


def hub_level():
    ents = [
        entity_instance("PlayerSpawn", (7, 11)),
        entity_instance("PushableBlock", (4, 4), {
            "LinkId": ("String", "hub_block")}),
        entity_instance("PressurePlate", (5, 5), {
            "Id": ("String", "hub_plate"),
            "TargetId": ("String", "room2_door")}),
        entity_instance("Chest", (10, 3), {
            "Id": ("String", "tutorial_chest"),
            "KeyId": ("String", "chest_key"),
            "RewardId": ("String", "shield")}),
        entity_instance("Lever", (1, 10)),
        entity_instance("LockedDoor", (7, 12), {
            "KeyId": ("String", ""), "LinkId": ("String", "hub_entry")}),
        entity_instance("Doorway", (7, 12), {
            "TargetRoom": ("String", "forest_exit")}),
        entity_instance("LockedDoor", (14, 6), {
            "KeyId": ("String", ""), "LinkId": ("String", "room2_door")}),
        entity_instance("Doorway", (14, 6), {
            "TargetRoom": ("String", "pit_room")}),
        entity_instance("LockedDoor", (0, 6), {
            "KeyId": ("String", ""), "LinkId": ("String", "hub_west")}),
        entity_instance("Doorway", (0, 6), {
            "TargetRoom": ("String", "fight_room_shortcut")}),
    ]
    return make_level("HubRoom", 101, 0, HUB_MAP, ents)


PIT_MAP = [
    "WWWWW.WWWWW",   # north gap x5 -> fight room
    "W.........W",
    "W.........W",
    "W.........W",
    "W.........W",
    "W.........W",
    "WPPPPPPPPPW",   # pit row (far)
    "WPPPPPPPPPW",   # pit row (near)
    "W.........W",
    "W.........W",
    "W.........W",
    "W.........W",
    "WWWWW.WWWWW",   # south gap x5 -> hub
]


def pit_level():
    ents = [
        entity_instance("PlayerSpawn", (5, 11)),
        entity_instance("PushableBlock", (5, 9), {
            "LinkId": ("String", "pit_block")}),
        entity_instance("Doorway", (5, 0), {
            "TargetRoom": ("String", "fight_room")}),
        entity_instance("Doorway", (5, 12), {
            "TargetRoom": ("String", "hub_return")}),
    ]
    return make_level("PitRoom", 102, 256, PIT_MAP, ents)


FIGHT_MAP = [
    "WWWWWWWWWWW",
    "W.........W",
    "W.........W",
    "W.........W",
    "..........W",   # west gap x0 -> hub loop
    "W.........W",
    "W.........W",
    "W.........W",
    "WWWWW.WWWWW",   # south gap x5 -> back to pit room
]


def fight_level():
    ents = [
        entity_instance("PlayerSpawn", (5, 7)),
        entity_instance("Enemy", (5, 4), {
            "StatsId": ("String", "dungeon_slime"),
            "LeashRadius": ("Int", 3),
            "UniqueId": ("String", "key_guardian")}),
        entity_instance("Doorway", (5, 8), {
            "TargetRoom": ("String", "pit_room_return")}),
        entity_instance("Doorway", (0, 4), {
            "TargetRoom": ("String", "hub_loop")}),
    ]
    return make_level("FightRoom", 103, 512, FIGHT_MAP, ents)


# --- Entity pipeline fixture (T-031 proof): one of every entity type --------
FIXTURE_MAP = [
    "WWWWWWWWWWWW",
    "W..........W",
    "W..........W",
    "W.......P..W",
    "W..........W",
    "W..........W",
    "W..........W",
    "WWWWWWWWWWWW",
]


def fixture_level():
    ents = [
        entity_instance("PlayerSpawn", (2, 2)),
        entity_instance("Npc", (4, 2), {
            "Lines": ("Array<String>", ["Hello from LDtk!"]),
            "Heals": ("Bool", True),
            "ColorHex": ("String", "#73D9BF")}),
        entity_instance("Enemy", (9, 5), {
            "StatsId": ("String", "forest_slime"),
            "LeashRadius": ("Int", 1)}),
        entity_instance("LockedDoor", (6, 4), {
            "KeyId": ("String", "test_key"),
            "LinkId": ("String", "test_door")}),
        entity_instance("PushableBlock", (3, 5), {
            "LinkId": ("String", "test_block")}),
        entity_instance("PressurePlate", (2, 5), {
            "Id": ("String", "test_plate"),
            "TargetId": ("String", "test_door")}),
        entity_instance("Chest", (10, 2), {
            "Id": ("String", "fixture_chest"),
            "KeyId": ("String", ""),
            "RewardId": ("String", "trinket")}),
        entity_instance("Lever", (1, 6)),
        entity_instance("Doorway", (10, 6), {
            "TargetRoom": ("String", "nowhere")}),
    ]
    return make_level("EntityTestRoom", 104, 0, FIXTURE_MAP, ents)


def write(name, world):
    path = os.path.normpath(os.path.join(OUT_DIR, name))
    with open(path, "w") as f:
        json.dump(world, f, indent=1)
        f.write("\n")
    print("wrote", path)


def main():
    write("forest.ldtk", make_world([forest_level()], "Forest overworld"))
    write("tutorial_dungeon.ldtk", make_world(
        [hub_level(), pit_level(), fight_level()], "Tutorial dungeon"))
    write("entity_test_room.ldtk", make_world(
        [fixture_level()], "Entity pipeline fixture"))


if __name__ == "__main__":
    main()
