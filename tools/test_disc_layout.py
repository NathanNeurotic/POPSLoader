#!/usr/bin/env python3
"""Execute the real disc-icon draw block with mocked graphics on host Lua 5.4."""
import argparse
from pathlib import Path
from lupa import lua54

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path,
                    default=Path(__file__).resolve().parent.parent / "bin/POPSLDR/ui.lua")
args = parser.parse_args()
source = args.source.read_text(encoding="utf-8")
start = source.index("          -- An OPL-style _ICO.png")
end = source.index("          -- (EXP56:", start)
block = source[start:end]
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
# Local draw variables match the preview and frame geometry used by GameList.Play.
# All file access is forbidden: drawing an already loaded icon must be pure.
render = lua.eval("""function(block)
  return assert(load([[return function(height, iw, ih, y, enabled, present)
    local Round = function(x) return math.floor(x + 0.5) end
    local UI = {SCR={Y=height}, CoverCache={last_icon_img=present and 99 or nil}}
    local draw_x, draw_y, draw_w, draw_h = 344, y, 256, 256
    local ratio = 480 / height
    local frame_w = ratio >= 1 and 256 or Round(256 * ratio)
    local frame_h = ratio >= 1 and Round(256 / ratio) or 256
    local frame_x = draw_x + draw_w - frame_w
    local cover_enabled = enabled
    local result = nil
    local Graphics = {
      getImageWidth = function() return iw end,
      getImageHeight = function() return ih end,
      drawScaleImage = function(_, x, y, w, h) result={x=x,y=y,w=w,h=h} end
    }
]] .. block .. [[
    return result, frame_h
  end]]))()
end""")(block)
cases = 0
for height in (448, 480, 512):
    for y in (32, 96):  # details lift the artwork; icon must follow it
        for iw, ih in ((128, 128), (256, 128), (128, 256)):
            rect, frame_h = render(height, iw, ih, y, True, True)
            assert 100 <= max(rect.w, rect.h) <= 112, "disc art is still too small"
            assert rect.x >= 344 and rect.x + rect.w <= 600, "icon overlaps game list or safe edge"
            assert rect.y >= y and rect.y + rect.h <= y + frame_h, "icon exceeds artwork height"
            expected = iw / ih * 480 / height
            assert abs(rect.w - rect.h * expected) <= max(1, expected), "pixel aspect ratio lost"
            cases += 1
    for enabled, present, iw, ih in ((False, True, 128, 128),
                                    (True, False, 128, 128),
                                    (True, True, 0, 128),
                                    (True, True, 128, 0)):
        rect, _ = render(height, iw, ih, 96, enabled, present)
        assert rect is None, "disabled/missing/invalid icon was drawn"
        cases += 1
print(f"PASS {cases} disc-icon layout cases (NTSC, PAL, details lift, aspect and visibility)")
