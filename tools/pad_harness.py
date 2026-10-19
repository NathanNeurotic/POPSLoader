#!/usr/bin/env python3
"""Run the real pad.cpp against scripted libpad states (no PS2 hardware).

Requires a host C++ compiler; --source accepts an older pad.cpp to prove the
regression test fails there. A poll guard turns the original infinite loop
into a deterministic failure instead of hanging the test runner.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

STUBS = r"""
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <stdexcept>
#include <vector>
using u32 = unsigned int;
#define DPRINTF(...)
enum { PAD_STATE_DISCONN=0, PAD_STATE_FINDPAD=1, PAD_STATE_FINDCTP1=2,
       PAD_STATE_EXECCMD=5, PAD_STATE_STABLE=6, PAD_STATE_ERROR=7,
       PAD_MODECURID=1, PAD_MODECUREXID=2, PAD_MODETABLE=4,
       PAD_TYPE_DUALSHOCK=7, PAD_MMODE_DUALSHOCK=1, PAD_MMODE_LOCK=3,
       PAD_START=8 };
struct padButtonStatus { unsigned short btns; };
static std::vector<int> states;
static int polls, opens, closes, reads, configs, modes, read_ok, open_ok;
static clock_t ticks;
static bool unplug_on_mode;
static int padGetState(int, int) {
    if (++polls > 2000) throw std::runtime_error("unbounded readiness wait");
    return states[(polls-1 < (int)states.size()) ? polls-1 : states.size()-1];
}
static clock_t fake_clock() { return ticks; }
static int fake_usleep(unsigned int us) {
    ticks += (clock_t)((unsigned long long)us * CLOCKS_PER_SEC / 1000000);
    return 0;
}
#define clock fake_clock
#define usleep fake_usleep
static void padStateInt2String(int, char*) {}
static int padInfoMode(int, int, int info, int index) {
    if (info == PAD_MODETABLE) return index == -1 ? modes : PAD_TYPE_DUALSHOCK;
    return 1;
}
static int padSetMainMode(int, int, int, int) {
    ++configs;
    if (unplug_on_mode) { states={PAD_STATE_DISCONN}; polls=0; }
    return 1;
}
static int padInfoAct(int, int, int, int) { return 0; }
static int padRead(int, int, padButtonStatus *out) {
    ++reads; out->btns=0xffff ^ PAD_START; return read_ok;
}
static int padInit(int) { return 1; }
static int padEnd() { return 1; }
static int padPortOpen(int, int, void*) { ++opens; return open_ok; }
static int padPortClose(int, int) { ++closes; return 1; }
static int padGetPortMax() { return 2; }
static int padGetSlotMax(int) { return 1; }
"""

DRIVER = r"""
static void reset(std::vector<int> script) {
    states=script; polls=opens=closes=reads=configs=0;
    ticks=0; modes=0; read_ok=open_ok=1; unplug_on_mode=false;
}
static void expect(bool ok, const char *name) {
    if (!ok) throw std::runtime_error(name);
    std::printf("PASS %s\n",name);
}
int main() {
  try {
    reset({PAD_STATE_DISCONN}); pad_init();
    expect(polls==1 && configs==0 && opens==1 && closes==0 && ticks==0,
           "boot without controller returns immediately and leaves port open");
    reset({PAD_STATE_ERROR});
    expect(initializePad(0,0)==0 && configs==0,"pad error aborts setup");
    reset({PAD_STATE_FINDPAD});
    expect(initializePad(0,0)==0 && ticks>=CLOCKS_PER_SEC
           && ticks<CLOCKS_PER_SEC*2,"stuck discovery times out");
    reset({PAD_STATE_EXECCMD});
    expect(initializePad(0,0)==0 && ticks>=CLOCKS_PER_SEC,
           "stuck command times out");
    reset({PAD_STATE_FINDPAD,PAD_STATE_EXECCMD,PAD_STATE_STABLE});
    expect(initializePad(0,0)==1,"transient discovery reaches ready");
    reset({PAD_STATE_STABLE});
    expect(initializePad(0,0)==1 && configs==0,"digital controller preserved");
    reset({PAD_STATE_FINDCTP1}); modes=1;
    expect(initializePad(0,0)==1 && configs==1,"DualShock negotiation preserved");
    reset({PAD_STATE_STABLE}); modes=1; unplug_on_mode=true;
    expect(initializePad(0,0)==0,"disconnect during negotiation aborts setup");
    reset({PAD_STATE_DISCONN});
    expect(pad_reinit()==0 && opens==1 && closes==1,"reinit without pad returns failure");
    reset({PAD_STATE_DISCONN}); pad_init();
    states={PAD_STATE_STABLE}; polls=0;
    expect(isButtonPressed(PAD_START)==1 && closes==0,"late connection supplies buttons");
    reset({PAD_STATE_ERROR});
    expect(isButtonPressed(PAD_START)==0 && reads==0,"error-screen read never waits on bad pad");
    reset({PAD_STATE_STABLE}); read_ok=0;
    expect(isButtonPressed(PAD_START)==0,"failed pad read supplies no button");
    reset({PAD_STATE_STABLE}); open_ok=0; pad_init();
    expect(polls==0 && opens==1,"port-open failure returns safely");
  } catch (const std::exception &e) {
    std::fprintf(stderr,"FAIL %s\n",e.what()); return 1;
  }
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path,
                        default=Path(__file__).resolve().parent.parent / "src/pad.cpp")
    args = parser.parse_args()
    # Only platform includes are replaced. All pad functions execute unchanged.
    source = re.sub(r"^#include[^\n]*$", "", args.source.read_text(encoding="utf-8"), flags=re.M)
    with tempfile.TemporaryDirectory(prefix="pldr-pad-") as temp:
        unit = Path(temp) / "pad_test.cpp"
        binary = Path(temp) / ("pad_test.exe" if os.name == "nt" else "pad_test")
        unit.write_text(STUBS + source + DRIVER, encoding="utf-8")
        subprocess.run([os.environ.get("CXX", "g++"), "-std=gnu++17",
                        str(unit), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    main()
