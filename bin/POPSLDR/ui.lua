--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering POPSLoader UI")
UI = {
    LASTSCENE = 4;
    CURSCENE = 4;
    SCENES = {GUSB=1, GSMB=2, GHDD=3, MMAIN=4, MPROFILE=5, CREDITS=6};
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
    GameList = {
      MAXDRAW = 18;
      CURR = 1;
      STARTUP = 1;
      Reset = function ()
        UI.GameList.CURR = 1;
      end;
      Play = function()
        local ammount = #PLDR.GAMES
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
        UI.Pad.Listen()
        if Pads.check(GPAD, PAD_CIRCLE) then UI.SceneChange(UI.SCENES.MMAIN) end
        if Pads.check(GPAD, PAD_DOWN) then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) GPAD = 0 end
        if Pads.check(GPAD, PAD_RIGHT) then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) GPAD = 0 end
        if Pads.check(GPAD, PAD_UP) then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) GPAD = 0 end
        if Pads.check(GPAD, PAD_LEFT) then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) GPAD = 0 end
        if Pads.check(GPAD, PAD_CROSS) and ammount > 0 then
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
        UI.Pad.Listen()
        if Pads.check(GPAD, PAD_DOWN) then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt+1, 1, profcnt) GPAD = 0 end
        if Pads.check(GPAD, PAD_UP) then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt-1, 1, profcnt) GPAD = 0 end
        if Pads.check(GPAD, PAD_CIRCLE) then UI.SceneChange(UI.SCENES.MMAIN) end
        if Pads.check(GPAD, PAD_CROSS) then
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
        if UI.MainMenu.OPT == 2 then Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID+UI.SCR.Y_MID/2, 8, UI.SCR.X, 16, "COMMING SOON", UI.CCOL.RED) end
        UI.Pad.Listen()
        if Pads.check(GPAD, PAD_RIGHT) then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT+1, 1, profcnt) GPAD = 0 end
        if Pads.check(GPAD, PAD_LEFT)  then UI.MainMenu.OPT = CLAMP(UI.MainMenu.OPT-1, 1, profcnt) GPAD = 0 end
        if Pads.check(GPAD, PAD_START) then UI.SceneChange(UI.SCENES.MPROFILE) end
        if Pads.check(GPAD, PAD_SELECT)then UI.SceneChange(UI.SCENES.CREDITS) end
        if Pads.check(GPAD, PAD_CROSS) then
          if UI.MainMenu.OPT == 1 then
            PLDR.CleanupGameList()
            PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)
            UI.SceneChange(UI.MainMenu.OPT)
          elseif UI.MainMenu.OPT == 2 then
            local mmce_prefix = PLDR.DetectMMCESlot()
            if mmce_prefix == nil then
              UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
            else
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
          GPAD = 0
        end
      end
    };
    Pad = {
      OLDPAD = 0;
      PDELAY = 150;
      CLK = 0;
      Listen = function ()
        if UI.Pad.Timer == nil then
          UI.Pad.Timer = Timer.new()
          UI.Pad.CLK = Timer.getTime(UI.Pad.Timer)
        end
        if (UI.Pad.CLK+UI.Pad.PDELAY) > Timer.getTime(UI.Pad.Timer) then
          GPAD = 0
        else
          GPAD = Pads.get()
          UI.Pad.CLK = Timer.getTime(UI.Pad.Timer)
        end
      end;
      Timer = nil;
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
        UI.Pad.Listen()
        if GPAD ~= 0 then UI.Credits.INCR = 1 end
      end
    };
  }
