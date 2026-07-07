-- M1.1 Aseprite batch exporter (T-003). Exports every .aseprite source under
-- assets/art/ to the PNG paths the game imports, so art edits never involve
-- manual GUI export steps (BLUEPRINT.md -> Design Decisions: Aseprite chosen
-- for scriptability).
--
-- Contract: for each assets/art/<dir>/src/<name>.aseprite, write
-- assets/art/<dir>/<name>.png (flattened, all layers visible). The generated
-- test art (test_tiles.png, test_hero.png) follows the same paths - when the
-- .aseprite sources are drawn, this exporter simply takes over producing the
-- identical files and nothing downstream changes.
--
-- Run (once Aseprite is installed):
--   /Applications/Aseprite.app/Contents/MacOS/aseprite -b \
--     --script assets/art/_scripts/export_sheets.lua
-- Or via the wrapper: assets/art/_scripts/export_sheets.sh

local function export_dir(src_dir, out_dir)
  local handle = io.popen('ls "' .. src_dir .. '" 2>/dev/null')
  if handle == nil then return 0 end
  local count = 0
  for file in handle:lines() do
    if file:match("%.aseprite$") then
      local sprite = app.open(src_dir .. "/" .. file)
      if sprite ~= nil then
        local out = out_dir .. "/" .. file:gsub("%.aseprite$", ".png")
        sprite:flatten()
        sprite:saveCopyAs(out)
        print("exported " .. out)
        count = count + 1
        sprite:close()
      end
    end
  end
  handle:close()
  return count
end

local total = 0
total = total + export_dir("assets/art/tilesets/src", "assets/art/tilesets")
total = total + export_dir("assets/art/sprites/src", "assets/art/sprites")
total = total + export_dir("assets/art/ui/src", "assets/art/ui")
print("export_sheets.lua: " .. total .. " sheet(s) exported")
