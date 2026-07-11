#include <kernel.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include "include/pad.h"
#include "include/dprintf.h"

static char padBuf[256] __attribute__((aligned(64)));

static char actAlign[6];
static int actuators;

static int port, slot;

int waitPadReady(int port, int slot)
{
    int state;
    int lastState;
    char stateString[16];

    state = padGetState(port, slot);
    lastState = -1;
    while((state != PAD_STATE_STABLE) && (state != PAD_STATE_FINDCTP1)) {
        if (state != lastState) {
            padStateInt2String(state, stateString);
            DPRINTF("Please wait, pad(%d,%d) is in state %s\n",
                       port, slot, stateString);
        }
        lastState = state;
        state=padGetState(port, slot);
    }
    // Were the pad ever 'out of sync'?
    if (lastState != -1) {
        DPRINTF("Pad OK!\n");
    }
    return 0;
}


/*
 * initializePad()
 */
int initializePad(int port, int slot)
{

    int ret;
    int modes;
    int i;

    waitPadReady(port, slot);

    // How many different modes can this device operate in?
    // i.e. get # entrys in the modetable
    modes = padInfoMode(port, slot, PAD_MODETABLE, -1);
    DPRINTF("The device has %d modes\n", modes);

    if (modes > 0) {
        DPRINTF("( ");
        for (i = 0; i < modes; i++) {
            DPRINTF("%d ", padInfoMode(port, slot, PAD_MODETABLE, i));
        }
        DPRINTF(")");
    }

    DPRINTF("It is currently using mode %d\n",
               padInfoMode(port, slot, PAD_MODECURID, 0));

    // If modes == 0, this is not a Dual shock controller
    // (it has no actuator engines)
    if (modes == 0) {
        DPRINTF("This is a digital controller?\n");
        return 1;
    }

    // Verify that the controller has a DUAL SHOCK mode
    i = 0;
    do {
        if (padInfoMode(port, slot, PAD_MODETABLE, i) == PAD_TYPE_DUALSHOCK)
            break;
        i++;
    } while (i < modes);
    if (i >= modes) {
        DPRINTF("This is no Dual Shock controller\n");
        return 1;
    }

    // If ExId != 0x0 => This controller has actuator engines
    // This check should always pass if the Dual Shock test above passed
    ret = padInfoMode(port, slot, PAD_MODECUREXID, 0);
    if (ret == 0) {
        DPRINTF("This is no Dual Shock controller??\n");
        return 1;
    }

    DPRINTF("Enabling dual shock functions\n");

    // When using MMODE_LOCK, user cant change mode with Select button
    padSetMainMode(port, slot, PAD_MMODE_DUALSHOCK, PAD_MMODE_LOCK);

    waitPadReady(port, slot);
    DPRINTF("infoPressMode: %d\n", padInfoPressMode(port, slot));

    waitPadReady(port, slot);
    DPRINTF("enterPressMode: %d\n", padEnterPressMode(port, slot));

    waitPadReady(port, slot);
    actuators = padInfoAct(port, slot, -1, 0);
    DPRINTF("# of actuators: %d\n",actuators);

    if (actuators != 0) {
        actAlign[0] = 0;   // Enable small engine
        actAlign[1] = 1;   // Enable big engine
        actAlign[2] = 0xff;
        actAlign[3] = 0xff;
        actAlign[4] = 0xff;
        actAlign[5] = 0xff;

        waitPadReady(port, slot);
        DPRINTF("padSetActAlign: %d\n",
                   padSetActAlign(port, slot, actAlign));
    }
    else {
        DPRINTF("Did not find any actuators.\n");
    }

    waitPadReady(port, slot);

    return 1;
}

int isButtonPressed(u32 button)
{
   int ret;
   u32 paddata;
   
   struct padButtonStatus padbuttons;
   
   while (((ret=padGetState(0, 0)) != PAD_STATE_STABLE)&&(ret!=PAD_STATE_FINDCTP1)&&(ret != PAD_STATE_DISCONN)); // more error check ?
   if (padRead(0, 0, &padbuttons) != 0)
   {
    	paddata = 0xffff ^ padbuttons.btns;
     	if(paddata & button)
            return 1;
   }
   return 0;

}

void pad_init()
{
    int ret;

    padInit(0);

    port = 0; // 0 -> Connector 1, 1 -> Connector 2
    slot = 0; // Always zero if not using multitap

    DPRINTF("PortMax: %d\n", padGetPortMax());
    DPRINTF("SlotMax: %d\n", padGetSlotMax(port));


    if((ret = padPortOpen(port, slot, padBuf)) == 0) {
        DPRINTF("padOpenPort failed: %d\n", ret);
        return;  // was SleepThread(): never deadlock the boot UI on a pad fault.
                 // pad_init runs on the main thread before the Lua boot loop, so
                 // SleepThread() here = permanent black screen, no error screen,
                 // no recovery. Come up instead so the menu renders (user can
                 // reconnect the controller / reboot). Mirrors pad_reinit() below.
    }

    if(!initializePad(port, slot)) {
        DPRINTF("pad initalization failed!\n");
        return;  // was SleepThread() — same reason.
    }
}

/*
 * pad_reinit()
 *
 * Rebuild the controller subsystem mid-session. The pad shares the SIO2 bus
 * with mcman/mcserv and mmceman; lazy-loading mmceman AFTER padman has opened
 * the pad (the MMCE-page-on-demand path) can disrupt the pad's in-flight SIO2
 * transfer and silently kill controller input — the list loads but no buttons
 * register.
 *
 * Recovery mirrors Open-PS2-Loader's proven pattern around any bus-disrupting
 * IOP operation (OPL src/opl.c ~1540-1590): unloadPads() = padPortClose +
 * padEnd(), then padInit(0), then startPads() = padPortOpen + initializePad.
 * A bare port close/open does NOT clear a desynced pad library, so we tear the
 * library all the way down (padEnd) and rebuild it (padInit) — padman.irx
 * stays resident, so no IRX reload is needed.
 *
 * Unlike pad_init() this must NOT SleepThread() on failure: it runs on the
 * main thread well after boot, so a failure has to return a status the caller
 * can react to, not deadlock the UI.
 *
 * Returns 1 on success, 0 on failure.
 */
int pad_reinit()
{
    int ret;

    padPortClose(port, slot); // best-effort close of the stale port
    padEnd();                 // tear the pad library down (OPL unloadPads)
    padInit(0);               // rebuild it (padman.irx remains resident)

    if((ret = padPortOpen(port, slot, padBuf)) == 0) {
        DPRINTF("pad_reinit: padPortOpen failed: %d\n", ret);
        return 0;
    }

    if(!initializePad(port, slot)) {
        DPRINTF("pad_reinit: pad initalization failed!\n");
        return 0;
    }

    return 1;
}

