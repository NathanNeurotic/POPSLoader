--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering POPSLoader UI")
local UI = {
    LASTSCENE = 4;
    CURSCENE = 4;
    SCENES = {GUSB=1, GSMB=2, GHDD=3, MMAIN=4, MPROFILE=5, CREDITS=6};
    LAUNCHING = false;
    SceneChange = function (SCENE)
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
    --- wrapper for Screen.flip(), here you add UI draws that renders on top of everything (for example, error notifications)
    flip = function (notif)
      UI.Notif_queue.display()
      UI.Modal.Draw()
      Screen.flip()
    end;
    WelcomeDraw = {
      Play = function ()
        local Q=0
        while Q<128 do
          Screen.clear(UI.SCR.BGCOL)
          Graphics.drawScaleImage(IMG.PSL, UI.SCR.X_MID-(Graphics.getImageWidth(IMG.PSL)),
          UI.SCR.Y_MID-(Graphics.getImageHeight(IMG.PSL)), Graphics.getImageWidth(IMG.PSL)*2, Graphics.getImageHeight(IMG.PSL)*2, Color.new(128,128,128,Q))
          Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID+100, 8, UI.SCR.X, 16, "Coded By El_isra", Color.new(128,128,128,Q))
          Screen.flip() -- we dont use UI.flip here because we dont want notifications on the welcome screen
          Q=Q+1
        end
      end

    };
    --- UI draw routine applied before drawing UI, add background and stuff you want rendered UNDER UI and text
    BottomDraw = {
      Play = function ()
        Screen.clear(UI.SCR.BGCOL)
        Graphics.drawScaleImage(IMG.PSL, UI.SCR.X_MID-(Graphics.getImageWidth(IMG.PSL)),
        UI.SCR.Y_MID-(Graphics.getImageHeight(IMG.PSL)), Graphics.getImageWidth(IMG.PSL)*2, Graphics.getImageHeight(IMG.PSL)*2)
          Graphics.drawRect(0, 20, UI.SCR.X, 398, UI.CCOL.TRANSP_BLACK)
      end;
    };
    Modal = {
      active = false;
      title = "";
      body = "";
      options = {"Yes", "No"};
      selected = 2;
      OpenExit = function ()
        LOG("Exit requested")
        UI.Modal.active = true
        UI.Modal.title = "Exit"
        UI.Modal.body = "Return to OSDSYS?"
        UI.Modal.options = {"Yes", "No"}
        UI.Modal.selected = 2
      end;
      Close = function ()
        UI.Modal.active = false
      end;
      Confirm = function ()
        LOG("Exit confirmed")
        UI.LAUNCHING = true
        System.exitToBrowser()
      end;
      HandleInput = function ()
        if not UI.Modal.active then return end
        if UI.Pad.Events.NAV_LEFT or UI.Pad.Events.NAV_RIGHT then
          if UI.Modal.selected == 1 then
            UI.Modal.selected = 2
          else
            UI.Modal.selected = 1
          end
        elseif UI.Pad.Events.CONFIRM then
          if UI.Modal.selected == 1 then
            UI.Modal.Confirm()
          else
            UI.Modal.Close()
          end
        elseif UI.Pad.Events.BACK then
          UI.Modal.Close()
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
        local yes_col = UI.Modal.selected == 1 and UI.CCOL.YELLOW or UI.CCOL.GREY
        local no_col = UI.Modal.selected == 2 and UI.CCOL.YELLOW or UI.CCOL.GREY
        Font.ftPrint(BFONT, UI.SCR.X_MID - 60, box_y + 95, 0, UI.SCR.X, 16, UI.Modal.options[1], yes_col)
        Font.ftPrint(BFONT, UI.SCR.X_MID + 20, box_y + 95, 0, UI.SCR.X, 16, UI.Modal.options[2], no_col)
      end;
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
        local ammount = #PLDR.GAMES
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          if #slots > 1 then
            Font.ftPrint(SFONT, 30, 2, 0, UI.SCR.X, 16, "Slot: "..PLDR.MMCE.PREFIX, UI.CCOL.GREY)
            Font.ftPrint(SFONT, 30, 12, 0, UI.SCR.X, 16, "Triangle: switch slot", UI.CCOL.GREY)
          end
        end
        if (UI.GameList.CURR > (UI.GameList.STARTUP+(UI.GameList.MAXDRAW-1))) then
          UI.GameList.STARTUP = (UI.GameList.CURR-UI.GameList.MAXDRAW+1)
        elseif (UI.GameList.CURR < UI.GameList.STARTUP) then
          UI.GameList.STARTUP = CLAMP(UI.GameList.CURR-1, 1, ammount)
        end
        for i = UI.GameList.STARTUP, ammount do
          if i >= (UI.GameList.STARTUP+UI.GameList.MAXDRAW) then break end
          local Y = 20+((i-UI.GameList.STARTUP)*21)
          Font.ftPrint(BFONT, 30, Y, 0, UI.SCR.X, 16, string.sub(PLDR.GAMES[i],1, -5), i == UI.GameList.CURR and UI.CCOL.YELLOW or UI.CCOL.GREY)
        end
        if ammount <= 0 then
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "No games found", UI.CCOL.YELLOW)
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, "No games found", UI.CCOL.TRANSP_BLACK)
        end
        Input_GetEvent()
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          UI.HandleGlobalInput(#slots <= 1)
        else
          UI.HandleGlobalInput(true)
        end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          if #slots > 1 and UI.Pad.Events.EXIT then
            local next_prefix = PLDR.SetMMCESlot(PLDR.MMCE.INDEX + 1)
            if next_prefix ~= nil then
              PLDR.CleanupGameList()
              PLDR.GetPS1GameLists(next_prefix.."POPS/", true)
            end
          end
        end
        if UI.Pad.Events.NAV_DOWN then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) end
        if UI.Pad.Events.NAV_RIGHT then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) end
        if UI.Pad.Events.NAV_UP then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) end
        if UI.Pad.Events.NAV_LEFT then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) end
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
      end;
    };
    ProfileQuery = {
      lastopt = 1;
      curopt = 1;
      Play = function ()
        local profcnt = #PLDR.PROFILES
        Font.ftPrint(LFONT, UI.SCR.X_MID, 30, 8, UI.SCR.X, 16, "Choose POPStarter Profile", UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, 60, 8, UI.SCR.X, 16, "Profile "..UI.ProfileQuery.curopt, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, 190, 8, UI.SCR.X, 16, PLDR.PROFILES[UI.ProfileQuery.curopt].DESC, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, 280, 8, UI.SCR.X, 16, PLDR.PROFILES[UI.ProfileQuery.curopt].ELF, Color.new(128,128,128, 110))
        Input_GetEvent()
        UI.HandleGlobalInput(true)
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
      end;
    };
    MainMenu = {
      OPT = 1;
      opts = {"USB", "SMB", "HDD"};
      Play = function ()
        local profcnt = 3
        Font.ftPrint(LFONT, UI.SCR.X_MID, 30, 8, UI.SCR.X, 16, "Welcome to POPStarter Loader", UI.CCOL.GREY)
        for x = 1, #UI.MainMenu.opts do
          Graphics.drawImage(IMG[UI.MainMenu.opts[x]], 256+(110*(x-1))-64, x == UI.MainMenu.OPT and (UI.SCR.Y_MID-65) or (UI.SCR.Y_MID-64),
            x == UI.MainMenu.OPT and UI.CCOL.YELLOW or UI.CCOL.GREY)
        end
        Graphics.drawImage(IMG["start"], 20, UI.SCR.Y-65) Font.ftPrint(SFONT, 55, UI.SCR.Y-60, 0, UI.SCR.X, 16, "POPStarter profiles")
        Graphics.drawImage(IMG["select"], 20, UI.SCR.Y-85) Font.ftPrint(SFONT, 55, UI.SCR.Y-80, 0, UI.SCR.X, 16, "About")
        if not UI.LAUNCHING and not UI.Modal.active then
          Graphics.drawImage(IMG["triangle"], 20, UI.SCR.Y-105)
          Font.ftPrint(SFONT, 55, UI.SCR.Y-100, 0, UI.SCR.X, 16, "Exit")
        end
        Input_GetEvent()
        UI.HandleGlobalInput(true)
        if UI.Pad.Events.NAV_RIGHT then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT+1, 1, profcnt) end
        if UI.Pad.Events.NAV_LEFT  then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT-1, 1, profcnt) end
        if UI.Pad.Events.START then UI.SceneChange(UI.SCENES.MPROFILE) end
        if UI.Pad.Events.SELECT then UI.SceneChange(UI.SCENES.CREDITS) end
          if UI.Pad.Events.CONFIRM then
          if UI.MainMenu.OPT == 1 then
            PLDR.CleanupGameList()
            PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)
            UI.SceneChange(UI.MainMenu.OPT)
          elseif UI.MainMenu.OPT == 2 then
            local slots = PLDR.GetMMCESlots()
            if #slots < 1 then
              UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              UI.SceneChange(UI.MainMenu.OPT)
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
              UI.SceneChange(UI.MainMenu.OPT)
            end
          elseif UI.MainMenu.OPT == 3 then
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
        if UI.Credits.Q == 0 then
          UI.SceneChange(UI.SCENES.MMAIN)
          UI.Credits.Q = 1
          UI.Credits.INCR = -1
          return
        end
        local currcol = Color.new(128, 128, 128, UI.Credits.Q)
        UI.Credits.Q = CLAMP(UI.Credits.Q-UI.Credits.INCR, 0, 128)
        Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, 040, 20, UI.SCR.X, 40, "POPStarter Loader\n"..POPSLDR_VER, currcol)
        Graphics.drawRect(0, 20, UI.SCR.X, 2, currcol)
        Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, 100, 20, UI.SCR.X, 40, "Coded By El_isra", currcol)
        Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, 120, 20, UI.SCR.X, UI.SCR.Y, "Based on Enceladus by Daniel santos\n\nSpecial thanks to:\nkrHACKen: for making POPStarter\nuyjulian, fjtrujy, HWC and others for always helping me\n\nThis program is free and open source\nif you bought it you've been scammed", currcol)
        Graphics.drawRect(0, UI.SCR.Y-60, UI.SCR.X, 2, currcol)
        Input_GetEvent()
        UI.HandleGlobalInput(true)
        if UI.Pad.Events.ANY then UI.Credits.INCR = 1 end
      end
    };
  }
function Input_GetEvent()
  UI.Pad.Listen()
  return UI.Pad.Events
end
_G.UI = UI
return UI
