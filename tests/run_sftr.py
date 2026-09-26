#!/usr/bin/env python3
"""Offline test harness for the "Steal From The Rich" hub.

Builds one Luau file per scenario:

    __SIM_ARGS header
    tests/mock_roblox.luau   simulated Roblox client (scheduler, instances, prompts, UI mock)
    tests/sftr_server.luau   the game's world + simulated server
    tests/harness.luau       scenario runner and checks
    tests/scenarios/<x>.luau the scenario
    the script under test    embedded as a string and loaded with loadstring("=Steal From The Rich")

The inlined UI library (``local Library = (function()`` up to ``local ThemeManager = loadstring``)
is replaced by ``local Library = __MockLibrary`` padded with blank lines, so line numbers in
errors and stack traces are the real line numbers of the script. The ThemeManager/SaveManager
``loadstring(game:HttpGet(...))()`` lines become mock objects, and setStatus() gets a one-line
observation hook so every status change is logged.

Usage:
    python3 tests/run_sftr.py                 # run every scenario in tests/scenarios
    python3 tests/run_sftr.py a_autosteal_grandpa e_everything
    python3 tests/run_sftr.py -q              # only summaries
Environment: LUAU_BIN=/path/to/luau (otherwise `luau` on PATH or tests/bin/luau).
Exit code is non-zero if any scenario fails, hangs or crashes.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_SCRIPT = os.path.join(ROOT, "Steal From The Rich")
SCRIPT_NAME = "Steal From The Rich"
FALLBACK_LUAU = [
    os.path.join(HERE, "bin", "luau"),
    "/tmp/claude-0/-home-user-Corvus/f1b46c74-946c-5c46-b200-e56075dfe2b3/scratchpad/luau",
]


def find_luau(explicit):
    for cand in [explicit, os.environ.get("LUAU_BIN"), shutil.which("luau"), *FALLBACK_LUAU]:
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    sys.exit("luau CLI not found: set LUAU_BIN or pass --luau")


def transform_script(src):
    """Return (transformed source, info). Line count is preserved exactly."""
    lines = src.split("\n")
    info = {}

    def find(pred, start=0, what=""):
        for i in range(start, len(lines)):
            if pred(lines[i]):
                return i
        sys.exit(f"could not find {what} in the script")

    lib = find(lambda l: l.startswith("local Library = (function()"), what="the inlined library start")
    theme = find(lambda l: l.startswith("local ThemeManager = "), lib, "the ThemeManager line")
    save = find(lambda l: l.startswith("local SaveManager = "), theme, "the SaveManager line")
    lines[lib] = "local Library = __MockLibrary"
    for i in range(lib + 1, theme):
        lines[i] = ""
    lines[theme] = "local ThemeManager = __MockThemeManager"
    lines[save] = "local SaveManager = __MockSaveManager"
    info["library_lines"] = (lib + 1, theme)

    # setStatus observation hook (same line, so numbering is unchanged)
    ss = find(lambda l: l.strip() == "local function setStatus(text)", save, "setStatus()")
    body = next((i for i in range(ss + 1, min(ss + 8, len(lines))) if lines[i].strip() == "Status = text"), None)
    if body is None:
        sys.exit("setStatus() body changed; update the hook in run_sftr.py")
    lines[body] = lines[body] + "; if __SimOnStatus then __SimOnStatus(text) end"

    # the main worker's per-cycle wait (used to count main loop cycles / detect stalls)
    mw = find(lambda l: "Main worker" in l, ss, "the main worker comment")
    wait_line = None
    for i in range(mw, min(mw + 200, len(lines))):
        if lines[i] == "\t\ttask.wait(0.25)":
            wait_line = i + 1
            break
    if not wait_line:
        sys.exit("could not find the main worker's task.wait(0.25)")
    info["main_wait_line"] = wait_line
    return "\n".join(lines), info


def long_bracket(src):
    level = 1
    while ("]" + "=" * level + "]") in src:
        level += 1
    return "[" + "=" * level + "[", "]" + "=" * level + "]"


def build(scenario_path, script_src, info, verbose):
    parts = [
        '__SIM_ARGS = { scriptName = "%s", mainLoopWaitLine = %d, verbose = %s }'
        % (SCRIPT_NAME, info["main_wait_line"], "true" if verbose else "false"),
    ]
    for name in ("mock_roblox.luau", "sftr_server.luau", "harness.luau"):
        with open(os.path.join(HERE, name)) as f:
            parts.append(f"-- ===== {name} =====\n" + f.read())
    with open(scenario_path) as f:
        parts.append(f"-- ===== scenario {os.path.basename(scenario_path)} =====\n" + f.read())
    open_b, close_b = long_bracket(script_src)
    parts.append("local __SCRIPT_SOURCE = " + open_b + "\n" + script_src + close_b)
    parts.append("Sim.runScenario(__SCRIPT_SOURCE)")
    return "\n".join(parts) + "\n"


def run_one(luau, scenario_path, script_src, info, args):
    name = os.path.splitext(os.path.basename(scenario_path))[0]
    build_dir = os.path.join(HERE, ".build")
    log_dir = os.path.join(HERE, "logs")
    os.makedirs(build_dir, exist_ok=True)
    os.makedirs(log_dir, exist_ok=True)
    built = os.path.join(build_dir, name + ".luau")
    with open(built, "w") as f:
        f.write(build(scenario_path, script_src, info, not args.quiet_log))
    log_path = os.path.join(log_dir, name + ".log")

    cmd = [luau, built]
    if shutil.which("stdbuf"):
        cmd = ["stdbuf", "-oL", "-eL"] + cmd  # keep output if we have to kill a hung run
    started = time.time()
    out_lines = []
    in_summary = False
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    timed_out = False
    try:
        import selectors

        sel = selectors.DefaultSelector()
        sel.register(proc.stdout, selectors.EVENT_READ)
        while True:
            remaining = args.timeout - (time.time() - started)
            if remaining <= 0:
                timed_out = True
                proc.kill()
                break
            if not sel.select(timeout=min(remaining, 1.0)):
                if proc.poll() is not None:
                    break
                continue
            line = proc.stdout.readline()
            if not line:
                break
            line = line.rstrip("\n")
            out_lines.append(line)
            if line.startswith("==== SUMMARY"):
                in_summary = True
            if not args.quiet or in_summary or line.startswith("==== SCENARIO") or "LUA-ERROR" in line or "STALL" in line:
                print(line, flush=True)
    finally:
        rest = proc.stdout.read() if not timed_out else ""
        for line in (rest or "").splitlines():
            out_lines.append(line)
            print(line, flush=True)
        proc.wait()
    elapsed = time.time() - started

    result = None
    for line in out_lines:
        m = re.match(r"RESULT (\S+): (PASS|FAIL)", line)
        if m:
            result = m.group(2)
    if timed_out:
        last = [l for l in out_lines if "PROGRESS" in l or "STATUS" in l][-3:]
        msg = (f"HANG: no result after {args.timeout:.0f} s of wall time. A thread is almost certainly stuck "
               f"in a loop that never yields (the scheduler cannot preempt it). Last progress:\n  " + "\n  ".join(last))
        print(msg)
        out_lines.append(msg)
        result = "HANG"
    elif result is None:
        print(f"CRASH: luau exited with code {proc.returncode} without a RESULT line")
        result = "CRASH"
    with open(log_path, "w") as f:
        f.write("\n".join(out_lines) + "\n")
    print(f"---- {name}: {result} ({elapsed:.1f} s wall, log: {os.path.relpath(log_path, ROOT)})\n", flush=True)
    return name, result


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenarios", nargs="*", help="scenario names or paths (default: all)")
    ap.add_argument("--script", default=DEFAULT_SCRIPT)
    ap.add_argument("--luau", default=None)
    ap.add_argument("--timeout", type=float, default=240.0, help="wall-clock seconds per scenario")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only summaries (full logs still go to tests/logs)")
    ap.add_argument("--quiet-log", action="store_true", help="do not log every remote call")
    args = ap.parse_args()

    luau = find_luau(args.luau)
    # Executors compile without optimisations: at -O0 every local takes a
    # register, and a function with more than 200 fails to compile, so the hub
    # does not start at all (live: "nie executuje sie w ogole"). Check that first.
    compiler = os.path.join(os.path.dirname(luau), "luau-compile")
    if os.path.isfile(compiler):
        check = subprocess.run([compiler, "--binary", "-O0", args.script], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if check.returncode != 0:
            print("COMPILE ERROR at -O0 (the executor would not run the script):\n" + check.stderr.strip())
            sys.exit(2)
        print("compile check: ok at -O0")
    else:
        print("compile check skipped: no luau-compile next to " + luau)
    with open(args.script, encoding="utf-8") as f:
        script_src, info = transform_script(f.read())
    print(f"script: {os.path.relpath(args.script, ROOT)} (library lines {info['library_lines'][0]}-{info['library_lines'][1]} mocked, "
          f"main loop wait at line {info['main_wait_line']})\nluau: {luau}\n")

    scen_dir = os.path.join(HERE, "scenarios")
    if args.scenarios:
        paths = []
        for s in args.scenarios:
            p = s if os.path.isfile(s) else os.path.join(scen_dir, s if s.endswith(".luau") else s + ".luau")
            if not os.path.isfile(p):
                sys.exit(f"scenario not found: {s}")
            paths.append(p)
    else:
        paths = sorted(os.path.join(scen_dir, f) for f in os.listdir(scen_dir) if f.endswith(".luau"))

    results = [run_one(luau, p, script_src, info, args) for p in paths]
    # the walk map on the real place geometry (tests/realmap): routes to every crate
    realmap = os.path.join(HERE, "realmap", "run_nav.py")
    if not args.scenarios and args.script == DEFAULT_SCRIPT and os.path.isfile(realmap):
        env = dict(os.environ, LUAU_BIN=luau)
        rm = subprocess.run([sys.executable, realmap], env=env, capture_output=True, text=True)
        print(rm.stdout.strip())
        results.append(("realmap_routes", "PASS" if rm.returncode == 0 else "FAIL"))
    print("==== RESULTS ====")
    for name, res in results:
        print(f"  {res:5s} {name}")
    failed = [n for n, r in results if r != "PASS"]
    print(f"{len(results) - len(failed)}/{len(results)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
