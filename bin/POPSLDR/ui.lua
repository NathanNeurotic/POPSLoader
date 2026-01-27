--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering POPSLoader UI")
local DEVLOCK = { NONE = 0, USB = 1, MMCE = 2, MX4SIO = 3 }
local UI
local function Round(value)
  return math.floor(value + 0.5)
end
UI = {
    LASTSCENE = 5;
    CURSCENE = 5;
    SCENES = {
      GUSBFAT = 1,
      GUSBEXFAT = 2,
      GSMB = 3,
      GMX4SIO = 4,
      GHDD = 5,
      GAPAHDD = 5,
      GBDMHDD = 6,
      MMAIN = 8,
      MPROFILE = 9,
      CREDITS = 10
    };
    LAUNCHING = false;
    DEVLOCK = DEVLOCK;
    device_lock = DEVLOCK.NONE;
    boot_device = DEVLOCK.NONE;
    boot_locks = {};
    device_lock_name = function (lock)
      if lock == DEVLOCK.USB then return "USB" end
      if lock == DEVLOCK.MMCE then return "MMCE" end
      if lock == DEVLOCK.MX4SIO then return "MX4SIO" end
      return "None"
    end;
    canEnterDevice = function (target)
      if UI.boot_locks ~= nil and UI.boot_locks[target] == true then
        return false, "boot", UI.boot_device
      end
      if UI.device_lock == DEVLOCK.NONE then
        return true
      end
      if UI.device_lock == target then
        return true
      end
      return false, "session", UI.device_lock
    end;
    setDeviceLock = function (target)
      if UI.device_lock == DEVLOCK.NONE then
        UI.device_lock = target
        LOG("Device lock set to "..UI.device_lock_name(target))
      end
    end;
    SceneChange = function (SCENE)
      if UI.Transition ~= nil and UI.Transition.Start ~= nil then
        if UI.CURSCENE ~= SCENE then
          UI.Transition.Start(SCENE)
        end
        return
      end
      UI.LASTSCENE = UI.CURSCENE
      UI.CURSCENE = SCENE
    end;
    UpdateVmode = function ()
      Screen.setMode(UI.SCR.VMODE, UI.SCR.X, UI.SCR.Y, CT24, INTERLACED, FIELD)
    end;
    --- Color Constants
    CCOL = {
      GREY = Color.new(128,128,128,128);
      YELLOW = Color.new(128,128,0,128);
      RED = Color.new(128,0,0);
      TRANSP_BLACK = Color.new(0,0,0,40);
    };
    --- UI Constants
    SCR = {
      X = 702;
      X_MID = 702/2;
      Y = 480;
      Y_MID = 480/2;
      VMODE = _480p;
      BGCOL = Color.new(32,0,32);
    };
    LAYOUT = {
      SAFE = {L = 40, R = 40, T = 24, B = 28};
      ICON_SPACING = 120;
      LIST_ROW_H = 20;
      PREVIEW_W = 240;
      PREVIEW_H = 240;
      FOOTER_LABEL_W = 140;
      FOOTER_ICON_Y_OFFSET = 24;
      FOOTER_LABEL_Y_OFFSET = 10;
    };
    RecalcLayout = function ()
      UI.SCR.X_MID = Round(UI.SCR.X / 2)
      UI.SCR.Y_MID = Round(UI.SCR.Y / 2)
      local safe = UI.LAYOUT.SAFE
      local safe_w = UI.SCR.X - safe.L - safe.R
      local safe_h = UI.SCR.Y - safe.T - safe.B
      UI.LAYOUT.SAFE_W = safe_w
      UI.LAYOUT.SAFE_H = safe_h
      UI.LAYOUT.TITLE_Y = Round(safe.T + 6)
      UI.LAYOUT.STATUS_Y = Round(UI.LAYOUT.TITLE_Y + 20)
      UI.LAYOUT.ICON_ROW_Y = Round(UI.SCR.Y_MID - 40)
      UI.LAYOUT.LIST_X = Round(safe.L)
      UI.LAYOUT.LIST_Y = Round(safe.T + 16)
      UI.LAYOUT.LIST_W = math.floor(safe_w * 0.52)
      UI.LAYOUT.LIST_MAX = math.floor((safe_h - 80) / UI.LAYOUT.LIST_ROW_H)
      if UI.LAYOUT.LIST_MAX < 1 then
        UI.LAYOUT.LIST_MAX = 1
      end
      local preview_w = UI.LAYOUT.PREVIEW_W
      local preview_h = UI.LAYOUT.PREVIEW_H
      local preview_gap = 24
      local max_preview_w = safe_w - UI.LAYOUT.LIST_W - preview_gap
      if max_preview_w < preview_w then
        preview_w = max_preview_w
      end
      if preview_w < 0 then preview_w = 0 end
      UI.LAYOUT.PREVIEW_W = preview_w
      UI.LAYOUT.PREVIEW_H = preview_h
      UI.LAYOUT.PREVIEW_X = Round(UI.SCR.X - safe.R - preview_w)
      UI.LAYOUT.PREVIEW_Y = Round(UI.SCR.Y_MID - (preview_h / 2))
      UI.LAYOUT.FOOTER_ICON_Y = Round(UI.SCR.Y - safe.B - UI.LAYOUT.FOOTER_ICON_Y_OFFSET)
      UI.LAYOUT.FOOTER_LABEL_Y = Round(UI.LAYOUT.FOOTER_ICON_Y + UI.LAYOUT.FOOTER_LABEL_Y_OFFSET)
    end;
    GetRowPosition = function (index, count)
      local spacing = UI.LAYOUT.ICON_SPACING
      local center = UI.SCR.X_MID
      local offset = (index - (count + 1) / 2) * spacing
      return center + offset
    end;
    InputConfig = {
      MIN_ACTION_MS = 220;
      DEBUG_INPUT_LOG = true;
    };
    --- Notifications queue handler
    Notif_queue = {
      display = function ()
        local Q
        if #UI.Notif_queue.msg < 1 then return end
        if #UI.Notif_queue.msg > 1 then
          Q = 0x50
        elseif UI.Notif_queue.ALFA > 0x50 then
          Q = 0x50
        else
          Q = math.floor(UI.Notif_queue.ALFA)
        end
        Graphics.drawRect(30, 30, UI.SCR.X_MID-30, 40, Color.new(0, 0, 0, Q))
        Font.ftPrint(BFONT, 32, 32, 0, UI.SCR.X_MID-30, 32, UI.Notif_queue.msg[1], Color.new(0, 100, 255, math.floor(UI.Notif_queue.ALFA)))
        UI.Notif_queue.ALFA = UI.Notif_queue.ALFA-.8
        if UI.Notif_queue.ALFA < 1 then
          UI.Notif_queue.ALFA = 0x90
          table.remove(UI.Notif_queue.msg, 1)
        end
      end;
      ALFA = 0x80;
      add = function (NOTIF)
        LOG(NOTIF)
        table.insert(UI.Notif_queue.msg, NOTIF)
      end;
      msg = {};
    };
    Footer = {
      order = {"triangle", "circle", "cross", "square"};
      order_with_r2 = {"triangle", "circle", "cross", "square", "R2"};
      Draw = function (labels, order)
        local safe = UI.LAYOUT.SAFE
        local entries = order or UI.Footer.order
        local count = #entries
        local step = 0
        if count > 1 then
          step = UI.LAYOUT.SAFE_W / (count - 1)
        end
        for i = 1, count do
          local key = entries[i]
          local icon = IMG[key]
          local x = Round(safe.L + step * (i - 1))
          local y = UI.LAYOUT.FOOTER_ICON_Y
          if icon ~= nil then
            local w = Graphics.getImageWidth(icon)
            local h = Graphics.getImageHeight(icon)
            Graphics.drawImage(icon, x - (w / 2), y - (h / 2), UI.CCOL.GREY)
          end
          local label = labels and labels[key] or nil
          if label ~= nil then
            Font.ftPrint(SFONT, x, UI.LAYOUT.FOOTER_LABEL_Y, 8, UI.LAYOUT.FOOTER_LABEL_W, 16, label, UI.CCOL.GREY)
          end
        end
      end;
    };
    --- wrapper for Screen.flip(), here you add UI draws that renders on top of everything (for example, error notifications)
    flip = function (notif)
      UI.Notif_queue.display()
      UI.Modal.Draw()
      if UI.Transition ~= nil then
        local alpha = UI.Transition.Update()
        if alpha > 0 then
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
        end
      end
      Screen.flip()
    end;
    WelcomeDraw = {
      Play = function ()
        local function DrawSplashCover(img, screen_w, screen_h, alpha)
          local img_w = Graphics.getImageWidth(img)
          local img_h = Graphics.getImageHeight(img)
          local scale = 1
          if img_w > 0 and img_h > 0 then
            local cover_scale = math.max(screen_w / img_w, screen_h / img_h)
            scale = cover_scale * 1.02
          end
          local draw_w = Round(img_w * scale)
          local draw_h = Round(img_h * scale)
          local x = Round((screen_w - draw_w) / 2)
          local y = Round((screen_h - draw_h) / 2)
          local tint = Color.new(128, 128, 128, alpha)
          Graphics.drawScaleImage(img, x, y, draw_w, draw_h, tint)
        end
        local fade_in_frames = 24
        local hold_frames = 24
        local fade_out_frames = 24
        for i = 1, fade_in_frames do
          local alpha = Round(128 * (i / fade_in_frames))
          Screen.clear(UI.SCR.BGCOL)
          DrawSplashCover(IMG.PSL, UI.SCR.X, UI.SCR.Y, alpha)
          Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID+100, 8, UI.SCR.X, 16, "Coded By El_isra", Color.new(128,128,128,alpha))
          Screen.flip() -- we dont use UI.flip here because we dont want notifications on the welcome screen
        end
        for _ = 1, hold_frames do
          Screen.clear(UI.SCR.BGCOL)
          DrawSplashCover(IMG.PSL, UI.SCR.X, UI.SCR.Y, 128)
          Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID+100, 8, UI.SCR.X, 16, "Coded By El_isra", Color.new(128,128,128,128))
          Screen.flip()
        end
        for i = 1, fade_out_frames do
          local alpha = Round(128 * (1 - (i / fade_out_frames)))
          Screen.clear(UI.SCR.BGCOL)
          DrawSplashCover(IMG.PSL, UI.SCR.X, UI.SCR.Y, alpha)
          Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID+100, 8, UI.SCR.X, 16, "Coded By El_isra", Color.new(128,128,128,alpha))
          Screen.flip()
        end
      end

    };
    --- UI draw routine applied before drawing UI, add background and stuff you want rendered UNDER UI and text
    BottomDraw = {
      Play = function ()
        Screen.clear(UI.SCR.BGCOL)
        if IMG.BKG ~= nil then
          Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
        end
        Graphics.drawRect(0, 20, UI.SCR.X, 398, UI.CCOL.TRANSP_BLACK)
      end;
    };
    Modal = {
      active = false;
      title = "";
      body = "";
      options = {"Confirm", "Cancel"};
      confirm_action = nil;
      cancel_action = nil;
      OpenExit = function ()
        LOG("Exit requested")
        UI.Modal.active = true
        UI.Modal.title = "Exit"
        UI.Modal.body = "Return to OSDSYS?"
        UI.Modal.options = {"Exit", "Cancel"}
        UI.Modal.confirm_action = UI.Modal.ConfirmExit
        UI.Modal.cancel_action = UI.Modal.Close
      end;
      OpenDeviceLock = function (reason, active, target)
        local active_name = UI.device_lock_name(active)
        local target_name = UI.device_lock_name(target)
        UI.Modal.active = true
        UI.Modal.title = "Device drivers already loaded"
        if reason == "boot" then
          UI.Modal.body = ("Current boot device (%s) requires drivers already loaded.\nTo use %s, restart POPSLoader to reload drivers."):format(active_name, target_name)
        else
          UI.Modal.body = ("Drivers for %s are already loaded.\nTo use %s, restart POPSLoader to reload drivers."):format(active_name, target_name)
        end
        UI.Modal.options = {"Return", "Back"}
        UI.Modal.confirm_action = function ()
          LOG("Device lock prompt choice: RETURN")
          UI.Modal.Close()
          UI.SceneChange(UI.SCENES.MMAIN)
        end
        UI.Modal.cancel_action = UI.Modal.Close
      end;
      Close = function ()
        UI.Modal.active = false
        UI.Modal.confirm_action = nil
        UI.Modal.cancel_action = nil
      end;
      ConfirmExit = function ()
        LOG("Exit confirmed")
        UI.LAUNCHING = true
        System.exitToBrowser()
      end;
      HandleInput = function ()
        if not UI.Modal.active then return end
        if UI.Pad.Events.CONFIRM then
          if UI.Modal.confirm_action ~= nil then
            UI.Modal.confirm_action()
          else
            UI.Modal.Close()
          end
        elseif UI.Pad.Events.BACK then
          if UI.Modal.cancel_action ~= nil then
            UI.Modal.cancel_action()
          else
            UI.Modal.Close()
          end
        end
      end;
      Draw = function ()
        if not UI.Modal.active then return end
        local box_w = 320
        local box_h = 140
        local box_x = UI.SCR.X_MID - (box_w / 2)
        local box_y = UI.SCR.Y_MID - (box_h / 2)
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, 120))
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, UI.Modal.title, UI.CCOL.YELLOW)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 50, 8, UI.SCR.X, 16, UI.Modal.body, UI.CCOL.GREY)
        local confirm_label = UI.Modal.options[1] or "Confirm"
        local cancel_label = UI.Modal.options[2] or "Cancel"
        local hint = ("X: %s    O: %s"):format(confirm_label, cancel_label)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 95, 8, UI.SCR.X, 16, hint, UI.CCOL.GREY)
      end;
    };
    Transition = {
      active = false,
      phase = "out",
      target = nil,
      timer = nil,
      start = 0,
      duration_out = 330,
      duration_in = 330,
      Start = function (target)
        if UI.Transition.timer == nil then
          UI.Transition.timer = Timer.new()
        end
        UI.Transition.active = true
        UI.Transition.phase = "out"
        UI.Transition.target = target
        UI.Transition.start = Timer.getTime(UI.Transition.timer)
      end,
      Update = function ()
        if not UI.Transition.active then
          return 0
        end
        local now = Timer.getTime(UI.Transition.timer)
        local elapsed = now - (UI.Transition.start or 0)
        local duration = UI.Transition.phase == "out" and UI.Transition.duration_out or UI.Transition.duration_in
        if duration <= 0 then duration = 1 end
        local t = elapsed / duration
        if t > 1 then t = 1 end
        local alpha
        if UI.Transition.phase == "out" then
          alpha = Round(128 * t)
        else
          alpha = Round(128 * (1 - t))
        end
        if t >= 1 then
          if UI.Transition.phase == "out" then
            UI.LASTSCENE = UI.CURSCENE
            UI.CURSCENE = UI.Transition.target
            UI.Transition.phase = "in"
            UI.Transition.start = now
            alpha = 128
          else
            UI.Transition.active = false
            UI.Transition.target = nil
            alpha = 0
          end
        end
        return alpha
      end
    };
    HandleGlobalInput = function (allow_exit)
      if UI.Modal.active then
        UI.Modal.HandleInput()
        return true
      end
      if allow_exit == nil then allow_exit = true end
      if not allow_exit then return false end
      if UI.LAUNCHING then return false end
      if UI.Pad.Events.EXIT then
        UI.Modal.OpenExit()
        return true
      end
      return false
    end;
    GameList = {
      MAXDRAW = 18;
      CURR = 1;
      STARTUP = 1;
      Reset = function ()
        UI.GameList.CURR = 1;
      end;
      Play = function()
        local layout = UI.LAYOUT
        UI.GameList.MAXDRAW = layout.LIST_MAX
        local titles = {
          [UI.SCENES.GUSBFAT] = "USB FAT32",
          [UI.SCENES.GUSBEXFAT] = "USB exFAT"
        }
        local scene_title = titles[UI.CURSCENE]
        if scene_title ~= nil then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, scene_title, UI.CCOL.GREY)
        end
        local placeholders = {
          [UI.SCENES.GBDMHDD] = "BDM HDD"
        }
        local placeholder_title = placeholders[UI.CURSCENE]
        if placeholder_title ~= nil then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, placeholder_title, UI.CCOL.GREY)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "Not implemented yet", UI.CCOL.YELLOW)
          Input_GetEvent()
          UI.HandleGlobalInput(false)
          if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
          if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
          UI.Footer.Draw({
            triangle = "Credits",
            circle = "Back",
            cross = "Confirm",
            square = "Cover Art"
          })
          return
        end
        local ammount = #PLDR.GAMES
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          if #slots > 1 then
            Font.ftPrint(SFONT, layout.LIST_X, layout.LIST_Y - 20, 0, UI.SCR.X, 16, "Slot: "..PLDR.MMCE.PREFIX, UI.CCOL.GREY)
          end
        end
        if (UI.GameList.CURR > (UI.GameList.STARTUP+(UI.GameList.MAXDRAW-1))) then
          UI.GameList.STARTUP = (UI.GameList.CURR-UI.GameList.MAXDRAW+1)
        elseif (UI.GameList.CURR < UI.GameList.STARTUP) then
          UI.GameList.STARTUP = CLAMP(UI.GameList.CURR-1, 1, ammount)
        end
        for i = UI.GameList.STARTUP, ammount do
          if i >= (UI.GameList.STARTUP+UI.GameList.MAXDRAW) then break end
          local Y = layout.LIST_Y + ((i-UI.GameList.STARTUP) * layout.LIST_ROW_H)
          local display_name = PLDR.GAMES[i]
          local hdd_relpath = string.match(display_name or "", "^[^|]+|(.+)$")
          if hdd_relpath ~= nil then
            display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
          end
          Font.ftPrint(BFONT, layout.LIST_X, Y, 0, layout.LIST_W, 16, string.sub(display_name,1, -5), i == UI.GameList.CURR and UI.CCOL.YELLOW or UI.CCOL.GREY)
        end
        if layout.PREVIEW_W > 0 then
          Graphics.drawRect(layout.PREVIEW_X - 2, layout.PREVIEW_Y - 2, layout.PREVIEW_W + 4, layout.PREVIEW_H + 4, UI.CCOL.GREY)
          if IMG.MISSING ~= nil then
            Graphics.drawScaleImage(IMG.MISSING, layout.PREVIEW_X, layout.PREVIEW_Y, layout.PREVIEW_W, layout.PREVIEW_H)
          end
        end
        if ammount <= 0 then
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "No games found", UI.CCOL.YELLOW)
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, "No games found", UI.CCOL.TRANSP_BLACK)
        end
        Input_GetEvent()
        UI.HandleGlobalInput(false)
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.NAV_DOWN then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) end
        if UI.Pad.Events.NAV_RIGHT then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) end
        if UI.Pad.Events.NAV_UP then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) end
        if UI.Pad.Events.NAV_LEFT then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) end
        if UI.Pad.Events.R2 then
          if UI.CURSCENE == UI.SCENES.GUSBFAT then
            PLDR.ResetPopstarterPack()
          elseif UI.CURSCENE == UI.SCENES.GUSBEXFAT then
            PLDR.ApplyPopstarterPack("USBEXFAT")
          elseif UI.CURSCENE == UI.SCENES.GSMB and UI.device_lock == DEVLOCK.MMCE then
            PLDR.ApplyPopstarterPack("MMCE")
          elseif UI.CURSCENE == UI.SCENES.GMX4SIO then
            PLDR.ApplyPopstarterPack("MX4SIO")
          end
        end
        if UI.Pad.Events.CONFIRM and ammount > 0 then
          if not doesFileExist(PLDR.POPSTARTER_PATH) then
            UI.Notif_queue.add("Cant find POPSTARTER ELF\n"..PLDR.POPSTARTER_PATH)
          else
            if UI.CURSCENE ~= UI.SCENES.GHDD then -- only check if game can be found on USB and SMB
              if not doesFileExist(PLDR.GAMEPATH .. PLDR.GAMES[UI.GameList.CURR]) then
                UI.Notif_queue.add("Cant find Game\n"..PLDR.GAMEPATH .. PLDR.GAMES[UI.GameList.CURR])
              end
            end
            PLDR.RunPOPStarterGame(PLDR.GAMEPATH, PLDR.GAMES[UI.GameList.CURR])
          end
        end
        local footer_labels = {
          triangle = "Credits",
          circle = "Back",
          cross = "Confirm",
          square = "Cover Art"
        }
        local footer_order = UI.Footer.order
        if UI.CURSCENE == UI.SCENES.GUSBFAT then
          footer_labels.R2 = "Reset POPSTARTER"
          footer_order = UI.Footer.order_with_r2
        elseif UI.CURSCENE == UI.SCENES.GUSBEXFAT then
          footer_labels.R2 = "Install USBEXFAT pack"
          footer_order = UI.Footer.order_with_r2
        elseif UI.CURSCENE == UI.SCENES.GSMB and UI.device_lock == DEVLOCK.MMCE then
          footer_labels.R2 = "Install MMCE pack"
          footer_order = UI.Footer.order_with_r2
        elseif UI.CURSCENE == UI.SCENES.GMX4SIO then
          footer_labels.R2 = "Install MX4SIO pack"
          footer_order = UI.Footer.order_with_r2
        end
        UI.Footer.Draw(footer_labels, footer_order)
      end;
    };
    ProfileQuery = {
      lastopt = 1;
      curopt = 1;
      Play = function ()
        local layout = UI.LAYOUT
        local profcnt = #PLDR.PROFILES
        Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, "Choose POPStarter Profile", UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 30, 8, UI.SCR.X, 16, "Profile "..UI.ProfileQuery.curopt, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 140, 8, UI.SCR.X, 16, PLDR.PROFILES[UI.ProfileQuery.curopt].DESC, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 220, 8, UI.SCR.X, 16, PLDR.PROFILES[UI.ProfileQuery.curopt].ELF, Color.new(128,128,128, 110))
        Input_GetEvent()
        UI.HandleGlobalInput(false)
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.NAV_DOWN then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt+1, 1, profcnt) end
        if UI.Pad.Events.NAV_UP then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt-1, 1, profcnt) end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.CONFIRM then
          if not doesFileExist(PLDR.PROFILES[UI.ProfileQuery.curopt].ELF) then
            UI.Notif_queue.add("POPStarter ELF missing")
          else
            PLDR.POPSTARTER_PATH = PLDR.PROFILES[UI.ProfileQuery.curopt].ELF
            UI.SceneChange(UI.SCENES.MMAIN)
          end
        end
        UI.Footer.Draw({
          triangle = "Credits",
          circle = "Back",
          cross = "Confirm",
          square = "Cover Art"
        })
      end;
    };
    MainMenu = {
      OPT = 1;
      opts = {"USB FAT32", "USB exFAT", "MMCE", "MX4SIO", "APA HDD", "BDM HDD", "SMB"};
      Play = function ()
        local layout = UI.LAYOUT
        local profcnt = #UI.MainMenu.opts
        Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, "Welcome to POPStarter Loader", UI.CCOL.GREY)
        local status_y = layout.STATUS_Y
        if UI.boot_device ~= nil and UI.boot_device ~= DEVLOCK.NONE then
          Font.ftPrint(SFONT, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "Booted from: "..UI.device_lock_name(UI.boot_device), UI.CCOL.GREY)
          status_y = status_y + 12
        end
        if UI.device_lock ~= nil and UI.device_lock ~= DEVLOCK.NONE then
          Font.ftPrint(SFONT, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "Active Device: "..UI.device_lock_name(UI.device_lock).." (restart to switch)", UI.CCOL.GREY)
          status_y = status_y + 12
        end
        if UI.boot_locks ~= nil and (UI.boot_locks[DEVLOCK.USB] or UI.boot_locks[DEVLOCK.MMCE] or UI.boot_locks[DEVLOCK.MX4SIO]) then
          Font.ftPrint(SFONT, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "Some devices unavailable this session", UI.CCOL.GREY)
        end
        local icon_map = {
          ["USB FAT32"] = "USB",
          ["USB exFAT"] = "USBEXFAT",
          ["MMCE"] = "MMCE",
          ["MX4SIO"] = "MX4SIO",
          ["APA HDD"] = "APAHDD",
          ["BDM HDD"] = "BDHDD",
          ["SMB"] = "SMB"
        }
        local icon_keys = {}
        local max_w = 0
        local max_h = 0
        for x = 1, #UI.MainMenu.opts do
          local opt = UI.MainMenu.opts[x]
          local key = icon_map[opt] or opt
          icon_keys[x] = key
          local icon = IMG[key]
          if icon == nil then
            error("Missing icon for menu option '"..tostring(opt).."' (key '"..tostring(key).."')")
          end
          local icon_w = Graphics.getImageWidth(icon)
          local icon_h = Graphics.getImageHeight(icon)
          if icon_w > max_w then max_w = icon_w end
          if icon_h > max_h then max_h = icon_h end
        end
        local button_bar_h = nil
        if UI.LAYOUT ~= nil and UI.LAYOUT.FOOTER_ICON_Y ~= nil then
          button_bar_h = UI.SCR.Y - UI.LAYOUT.FOOTER_ICON_Y
        end
        local base_safe_b = button_bar_h and (button_bar_h + 12) or 56
        local min_safe_b = button_bar_h and (button_bar_h + 4) or 48
        local function ComputeScale(box_w, box_h, gx, gy)
          local row_w_unscaled = (3 * max_w) + (2 * gx)
          local total_h_unscaled = (3 * max_h) + (2 * gy)
          local scale_w = box_w / row_w_unscaled
          local scale_h = box_h / total_h_unscaled
          local scale = math.min(1.0, scale_w, scale_h)
          return scale, scale_w, scale_h
        end
        local attempts = {
          {gap_x = 12, gap_y = 10, min_scale = 0.80, safe_l = 16, safe_r = 16, safe_t = 16, safe_b = base_safe_b},
          {gap_x = 8, gap_y = 8, min_scale = 0.80, safe_l = 16, safe_r = 16, safe_t = 16, safe_b = base_safe_b},
          {gap_x = 6, gap_y = 6, min_scale = 0.80, safe_l = 16, safe_r = 16, safe_t = 16, safe_b = base_safe_b},
          {gap_x = 6, gap_y = 6, min_scale = 0.80, safe_l = 12, safe_r = 12, safe_t = 12, safe_b = math.max(base_safe_b - 8, min_safe_b)},
          {gap_x = 6, gap_y = 6, min_scale = 0.75, safe_l = 12, safe_r = 12, safe_t = 12, safe_b = math.max(base_safe_b - 8, min_safe_b)}
        }
        local layout = nil
        for i = 1, #attempts do
          local attempt = attempts[i]
          local box_w = UI.SCR.X - attempt.safe_l - attempt.safe_r
          local box_h = UI.SCR.Y - attempt.safe_t - attempt.safe_b
          local icon_scale, scale_w, scale_h = ComputeScale(box_w, box_h, attempt.gap_x, attempt.gap_y)
          if icon_scale >= attempt.min_scale then
            local cell_w = Round(max_w * icon_scale)
            local cell_h = Round(max_h * icon_scale)
            local total_rows = 3
            local total_h = (total_rows * cell_h) + ((total_rows - 1) * attempt.gap_y)
            local total_w = (3 * cell_w) + (2 * attempt.gap_x)
            if total_h <= box_h and total_w <= box_w then
              layout = {
                safe_l = attempt.safe_l,
                safe_r = attempt.safe_r,
                safe_t = attempt.safe_t,
                safe_b = attempt.safe_b,
                box_w = box_w,
                box_h = box_h,
                box_x = attempt.safe_l,
                box_y = attempt.safe_t,
                gap_x = attempt.gap_x,
                gap_y = attempt.gap_y,
                icon_scale = icon_scale,
                cell_w = cell_w,
                cell_h = cell_h,
                total_h = total_h,
                total_w = total_w,
                total_rows = total_rows
              }
              break
            end
          end
        end
        if layout == nil then
          local final = attempts[#attempts]
          local box_w = UI.SCR.X - final.safe_l - final.safe_r
          local box_h = UI.SCR.Y - final.safe_t - final.safe_b
          local icon_scale = ComputeScale(box_w, box_h, final.gap_x, final.gap_y)
          local cell_w = Round(max_w * icon_scale)
          local cell_h = Round(max_h * icon_scale)
          local total_rows = 3
          local total_h = (total_rows * cell_h) + ((total_rows - 1) * final.gap_y)
          local total_w = (3 * cell_w) + (2 * final.gap_x)
          local block_y = final.safe_t + Round((box_h - total_h) / 2)
          local row1_y = block_y
          local row2_y = row1_y + cell_h + final.gap_y
          local row3_y = row2_y + cell_h + final.gap_y
          if UI.MainMenu.layout_overflow_logged ~= true then
            UI.MainMenu.layout_overflow_logged = true
            LOGF("Main menu layout overflow: screen=%dx%d safe=%d,%d,%d,%d box=%d,%d,%d,%d menuCount=%d rows=%d",
              UI.SCR.X, UI.SCR.Y, final.safe_l, final.safe_r, final.safe_t, final.safe_b,
              final.safe_l, final.safe_t, box_w, box_h, #UI.MainMenu.opts, total_rows)
            LOGF("Main menu layout overflow: wMax=%d hMax=%d gapX=%d gapY=%d scale=%.3f wS=%d hS=%d totalH=%d totalW=%d",
              max_w, max_h, final.gap_x, final.gap_y, icon_scale, cell_w, cell_h, total_h, total_w)
            LOGF("Main menu layout overflow: row1Y=%d row2Y=%d row3Y=%d row1Bottom=%d row2Bottom=%d row3Bottom=%d",
              row1_y, row2_y, row3_y, row1_y + cell_h, row2_y + cell_h, row3_y + cell_h)
          end
          error("Main menu layout overflow: rows exceed CRT-safe box")
        end
        local safe_l = layout.safe_l
        local safe_r = layout.safe_r
        local safe_t = layout.safe_t
        local safe_b = layout.safe_b
        local box_w = layout.box_w
        local box_h = layout.box_h
        local box_x = layout.box_x
        local box_y = layout.box_y
        local gap_x = layout.gap_x
        local gap_y = layout.gap_y
        local icon_scale = layout.icon_scale
        local cell_w = layout.cell_w
        local cell_h = layout.cell_h
        local total_rows = layout.total_rows
        local total_h = layout.total_h
        local block_y = box_y + Round((box_h - total_h) / 2)
        local row1_y = block_y
        local row2_y = row1_y + cell_h + gap_y
        local row3_y = row2_y + cell_h + gap_y
        if UI.MainMenu.layout_logged ~= true then
          UI.MainMenu.layout_logged = true
          LOGF("Main menu layout: boxW=%d boxH=%d wMax=%d hMax=%d gapX=%d gapY=%d scale=%.3f wS=%d hS=%d",
            box_w, box_h, max_w, max_h, gap_x, gap_y, icon_scale, cell_w, cell_h)
        end
        local function RowStartX(count)
          if count == 1 then
            return box_x + Round((box_w - cell_w) / 2)
          end
          local row_w = (count * cell_w) + ((count - 1) * gap_x)
          return box_x + Round((box_w - row_w) / 2)
        end
        local function RowY(row)
          return block_y + ((row - 1) * (cell_h + gap_y))
        end
        local function ResolveMenuPosition(index)
          local row
          local col
          local count
          if index == 1 then
            row = 1
            col = 1
            count = 1
          else
            local idx = index - 2
            row = 2 + math.floor(idx / 3)
            col = (idx % 3) + 1
            count = 3
          end
          local start_x = RowStartX(count)
          local x = Round(start_x + ((col - 1) * (cell_w + gap_x)))
          local y = RowY(row)
          if x < box_x or (x + cell_w) > (box_x + box_w) then
            LOGF("Main menu layout overflow: x=%d y=%d w=%d h=%d boxW=%d boxH=%d gapX=%d gapY=%d scale=%.3f",
              x, y, cell_w, cell_h, box_w, box_h, gap_x, gap_y, icon_scale)
            error("Main menu layout overflow: icon exceeds CRT-safe width")
          end
          if y < box_y or (y + cell_h) > (box_y + box_h) then
            LOGF("Main menu layout overflow: x=%d y=%d w=%d h=%d boxW=%d boxH=%d gapX=%d gapY=%d scale=%.3f",
              x, y, cell_w, cell_h, box_w, box_h, gap_x, gap_y, icon_scale)
            error("Main menu layout overflow: icon exceeds CRT-safe height")
          end
          return x, y
        end
        for x = 1, #UI.MainMenu.opts do
          local icon = IMG[icon_keys[x]]
          local icon_w = Round(Graphics.getImageWidth(icon) * icon_scale)
          local icon_h = Round(Graphics.getImageHeight(icon) * icon_scale)
          local cell_x, cell_y = ResolveMenuPosition(x)
          local pos_x = Round(cell_x + ((cell_w - icon_w) / 2))
          local pos_y = Round(cell_y + ((cell_h - icon_h) / 2))
          Graphics.drawScaleImage(icon, pos_x, pos_y, icon_w, icon_h, x == UI.MainMenu.OPT and UI.CCOL.YELLOW or UI.CCOL.GREY)
        end
        UI.Footer.Draw({
          triangle = "Credits",
          circle = "Exit",
          cross = "Select",
          square = "Cover Art"
        })
        Input_GetEvent()
        UI.HandleGlobalInput(false)
        if UI.Pad.Events.NAV_RIGHT then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT+1, 1, profcnt) end
        if UI.Pad.Events.NAV_LEFT  then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT-1, 1, profcnt) end
        if UI.Pad.Events.START then UI.SceneChange(UI.SCENES.MPROFILE) end
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.BACK then UI.Modal.OpenExit() end
        if UI.Pad.Events.CONFIRM then
          if UI.MainMenu.OPT == 1 then
            PLDR.CleanupGameList()
            PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)
            UI.setDeviceLock(DEVLOCK.USB)
            UI.SceneChange(UI.SCENES.GUSBFAT)
          elseif UI.MainMenu.OPT == 2 then
            PLDR.CleanupGameList()
            PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)
            UI.setDeviceLock(DEVLOCK.USB)
            UI.SceneChange(UI.SCENES.GUSBEXFAT)
          elseif UI.MainMenu.OPT == 3 then
            local slots = PLDR.GetMMCESlots()
            if #slots < 1 then
              UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              UI.SceneChange(UI.SCENES.GSMB)
            else
              if PLDR.MMCE.PREFIX == nil then
                PLDR.SetMMCESlot(1)
              end
              local mmce_prefix = PLDR.MMCE.PREFIX or PLDR.SetMMCESlot(1)
              if mmce_prefix == nil then
                UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
                return
              end
              PLDR.CleanupGameList()
              PLDR.GetPS1GameLists(mmce_prefix.."POPS/", true)
              UI.setDeviceLock(DEVLOCK.MMCE)
              UI.SceneChange(UI.SCENES.GSMB)
            end
          elseif UI.MainMenu.OPT == 4 then
            LOG("Entering MX4SIO page")
            LOG("MX4SIO init start")
            PLDR.CleanupGameList()
            local hint = PLDR and PLDR.MX4SIO and PLDR.MX4SIO.PREFIX_HINT or nil
            local ok, root = System.initMX4SIO(hint)
            if not ok or root == nil then
              PLDR.MX4SIO.READY = false
              PLDR.MX4SIO.ROOT = nil
              UI.Notif_queue.add("No MX4SIO device found.")
              PLDR.GAMEPATH = ""
            else
              PLDR.MX4SIO.READY = true
              PLDR.MX4SIO.ROOT = root
              local list = PLDR.GetPS1GameLists(root.."POPS/", true)
              local count = list and #list or 0
              LOG("MX4SIO games found:", count)
              UI.setDeviceLock(DEVLOCK.MX4SIO)
            end
            UI.SceneChange(UI.SCENES.GMX4SIO)
          elseif UI.MainMenu.OPT == 5 then
            PLDR.LoadHDDModules()
            if UI.LASTSCENE == UI.SCENES.GHDD then
              LOG("skipping cache cleanup")
            else
              PLDR.CleanupGameList()
            end
            local a, b, c = PLDR.CheckPOPStarterDEPS(UI.SCENES.GHDD)
            if PLDR.HDD.STATUS == 0 then
              if not a then UI.Notif_queue.add("ERROR: cannot access 'hdd0:__common' partition") end
              if not b then UI.Notif_queue.add("missing POPS file\nhdd0:__common/POPS/POPS.ELF") end
              if not c then UI.Notif_queue.add("missing POPS file\nhdd0:__common/POPS/IOPRP252.IMG") end
              PLDR.HDD.CheckAvailableHddPopsParts()
              PLDR.HDD.BuildGameList()
              if not PLDR.HDD.FOUNDANY then
                UI.Notif_queue.add("Could not find any '__.POPS' partitions")
              elseif #PLDR.GAMES < 1 then
                UI.Notif_queue.add("Could not find any games on 'hdd0:'")
              end
            else
              UI.Notif_queue.add("ERROR: Cant detect usable HDD ("..PLDR.HDD.STATUS..")")
            end
            UI.SceneChange(UI.MainMenu.OPT)
          elseif UI.MainMenu.OPT == 6 then
            PLDR.CleanupGameList()
            PLDR.GAMEPATH = ""
            UI.SceneChange(UI.SCENES.GBDMHDD)
          elseif UI.MainMenu.OPT == 7 then
            PLDR.CleanupGameList()
            PLDR.GAMEPATH = ""
            UI.Notif_queue.add("SMB not implemented yet.")
            UI.SceneChange(UI.SCENES.GSMB)
          end --because we still dont support SMB
        end
      end
    };
    Pad = {
      OLDPAD = 0;
      GPAD = 0;
      Timer = nil;
      Events = {
        NAV_UP = false,
        NAV_DOWN = false,
        NAV_LEFT = false,
        NAV_RIGHT = false,
        CONFIRM = false,
        BACK = false,
        EXIT = false,
        START = false,
        SELECT = false,
        R2 = false,
        ANY = false,
      };
      NavHeld = {};
      NavNeutral = {UP = true, DOWN = true, LEFT = true, RIGHT = true};
      Queue = {};
      DebugPadTimer = nil;
      DebugPadLast = 0;
      NavEventTimer = nil;
      NavEventLast = 0;
      NavEventCount = 0;
      LastActionEventMs = 0;
      Listen = function ()
        if UI.Pad.Timer == nil then
          UI.Pad.Timer = Timer.new()
          UI.Pad.CLK = Timer.getTime(UI.Pad.Timer)
        end
        local now = Timer.getTime(UI.Pad.Timer)
        UI.Pad.CLK = now
        UI.Pad.OLDPAD = UI.Pad.GPAD
        UI.Pad.GPAD = Pads.get()
        GPAD = UI.Pad.GPAD

        local pressed = UI.Pad.GPAD & ~UI.Pad.OLDPAD
        local released = ~UI.Pad.GPAD & UI.Pad.OLDPAD

        UI.Pad.Queue = {}
        UI.Pad.Events.NAV_UP = false
        UI.Pad.Events.NAV_DOWN = false
        UI.Pad.Events.NAV_LEFT = false
        UI.Pad.Events.NAV_RIGHT = false
        UI.Pad.Events.CONFIRM = false
        UI.Pad.Events.BACK = false
        UI.Pad.Events.EXIT = false
        UI.Pad.Events.START = false
        UI.Pad.Events.SELECT = false
        UI.Pad.Events.R2 = false
        UI.Pad.Events.ANY = false

        local function emit(event)
          table.insert(UI.Pad.Queue, event)
          UI.Pad.Events[event] = true
          UI.Pad.Events.ANY = true
        end

        local function emit_nav(event)
          UI.Pad.NavEventCount = (UI.Pad.NavEventCount or 0) + 1
          emit(event)
        end

        local function emit_action(event)
          if (now - (UI.Pad.LastActionEventMs or 0)) < UI.InputConfig.MIN_ACTION_MS then
            return
          end
          UI.Pad.LastActionEventMs = now
          emit(event)
        end

        if (pressed & PAD_CROSS) ~= 0 then emit_action("CONFIRM") end
        if (pressed & PAD_CIRCLE) ~= 0 then emit_action("BACK") end
        if (pressed & PAD_TRIANGLE) ~= 0 then emit_action("EXIT") end
        if (pressed & PAD_START) ~= 0 then emit("START") end
        if (pressed & PAD_SELECT) ~= 0 then emit("SELECT") end
        if (pressed & PAD_R2) ~= 0 then emit_action("R2") end

        local function resolve_nav(dir, is_down)
          local was_down = UI.Pad.NavHeld[dir] == true
          if not is_down then
            if was_down then
              UI.Pad.NavNeutral[dir] = true
            end
            UI.Pad.NavHeld[dir] = false
            return false
          end
          UI.Pad.NavHeld[dir] = true
          if not UI.Pad.NavNeutral[dir] then
            return false
          end
          UI.Pad.NavNeutral[dir] = false
          return true
        end

        if resolve_nav("UP", ((UI.Pad.GPAD & PAD_UP) ~= 0)) then emit_nav("NAV_UP") end
        if resolve_nav("DOWN", ((UI.Pad.GPAD & PAD_DOWN) ~= 0)) then emit_nav("NAV_DOWN") end
        if resolve_nav("LEFT", ((UI.Pad.GPAD & PAD_LEFT) ~= 0)) then emit_nav("NAV_LEFT") end
        if resolve_nav("RIGHT", ((UI.Pad.GPAD & PAD_RIGHT) ~= 0)) then emit_nav("NAV_RIGHT") end

        if UI.InputConfig.DEBUG_INPUT_LOG then
          if UI.Pad.DebugPadTimer == nil then
            UI.Pad.DebugPadTimer = Timer.new()
            UI.Pad.DebugPadLast = Timer.getTime(UI.Pad.DebugPadTimer)
          end
          local dbg_now = Timer.getTime(UI.Pad.DebugPadTimer)
          if (dbg_now - UI.Pad.DebugPadLast) >= 1000 then
            local up = (UI.Pad.GPAD & PAD_UP) ~= 0
            local down = (UI.Pad.GPAD & PAD_DOWN) ~= 0
            local cross = (UI.Pad.GPAD & PAD_CROSS) ~= 0
            local circle = (UI.Pad.GPAD & PAD_CIRCLE) ~= 0
            LOGF("PAD mask: 0x%04X | UP:%s DOWN:%s X:%s O:%s", UI.Pad.GPAD, tostring(up), tostring(down), tostring(cross), tostring(circle))
            UI.Pad.DebugPadLast = dbg_now
          end
          if UI.Pad.NavEventTimer == nil then
            UI.Pad.NavEventTimer = Timer.new()
            UI.Pad.NavEventLast = Timer.getTime(UI.Pad.NavEventTimer)
            UI.Pad.NavEventCount = 0
          end
          local nav_now = Timer.getTime(UI.Pad.NavEventTimer)
          if (nav_now - UI.Pad.NavEventLast) >= 1000 then
            LOGF("NAV events/sec: %d", UI.Pad.NavEventCount or 0)
            UI.Pad.NavEventCount = 0
            UI.Pad.NavEventLast = nav_now
          end
        end
      end;
    };
    Credits = {
      Q = 1;
      INCR = -1;
      Play = function ()
        local layout = UI.LAYOUT
        if UI.Credits.Q == 0 then
          UI.SceneChange(UI.SCENES.MMAIN)
          UI.Credits.Q = 1
          UI.Credits.INCR = -1
          return
        end
        local currcol = Color.new(128, 128, 128, UI.Credits.Q)
        UI.Credits.Q = CLAMP(UI.Credits.Q-UI.Credits.INCR, 0, 128)
        Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 20, UI.SCR.X, 40, "POPStarter Loader\n"..POPSLDR_VER, currcol)
        Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 60, 20, UI.SCR.X, 40, "Coded By El_isra", currcol)
        Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 80, 20, UI.SCR.X, UI.SCR.Y, "Based on Enceladus by Daniel santos\n\nSpecial thanks to:\nkrHACKen: for making POPStarter\nuyjulian, fjtrujy, HWC and others for always helping me\n\nThis program is free and open source\nif you bought it you've been scammed", currcol)
        Input_GetEvent()
        UI.HandleGlobalInput(false)
        if UI.Pad.Events.EXIT then UI.Credits.INCR = 1 end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.ANY then UI.Credits.INCR = 1 end
        UI.Footer.Draw({
          triangle = "Credits",
          circle = "Back",
          cross = "Confirm",
          square = "Cover Art"
        })
      end
    };
  }
_G.UI = UI
UI.GAME_SCENES = {
  [UI.SCENES.GUSBFAT] = true,
  [UI.SCENES.GUSBEXFAT] = true,
  [UI.SCENES.GSMB] = true,
  [UI.SCENES.GMX4SIO] = true,
  [UI.SCENES.GHDD] = true,
  [UI.SCENES.GBDMHDD] = true
}
function UI.IsGameScene(scene)
  return UI.GAME_SCENES[scene] == true
end
function UI.IsUsbScene(scene)
  return scene == UI.SCENES.GUSBFAT or scene == UI.SCENES.GUSBEXFAT
end
UI.RecalcLayout()
function Input_GetEvent()
  UI.Pad.Listen()
  if UI.Transition ~= nil and UI.Transition.active then
    for key, _ in pairs(UI.Pad.Events) do
      UI.Pad.Events[key] = false
    end
  end
  return UI.Pad.Events
end
return UI
