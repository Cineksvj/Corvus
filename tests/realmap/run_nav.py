#!/usr/bin/env python3
"""Runs the script's walk-map code (the "-- NAV BEGIN" ... "-- NAV END" block of
"Steal From The Rich") on the real map: every collidable part in the walking band
of the uploaded place file (realmap.json). It plans routes from the spot in the live
log where the farm got stuck at a fence (2523.6, -1098) and from the safe zone to
every crate spot and the lobby stops, then checks each route independently here:
no segment may pass within the character's half width of a wall/fence part.

Usage: python3 tests/realmap/run_nav.py   (LUAU_BIN or the harness fallbacks)
"""
import json, math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
from run_sftr import find_luau  # noqa: E402

data = json.load(open(os.path.join(HERE, "realmap.json")))
src = open(os.path.join(ROOT, "Steal From The Rich"), encoding="utf-8").read()
nav = src[src.index("-- NAV BEGIN"):src.index("-- NAV END")]

PRELUDE = r'''
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Enum = { PathWaypointAction = { Walk = "Walk", Jump = "Jump" } }
task = { wait = function() end }
function log(...) local t = table.pack(...) for i = 1, t.n do t[i] = tostring(t[i]) end print("LOG " .. table.concat(t, " ")) end
local function node(name, parent, className)
	local n = { Name = name, Parent = parent, ClassName = className or "Folder" }
	function n:IsA(c) return c == self.ClassName or (c == "BasePart" and self.ClassName == "Part") end
	function n:IsDescendantOf(a) local p = self.Parent while p do if p == a then return true end p = p.Parent end return false end
	function n:FindFirstChildOfClass() return nil end
	return n
end
workspace = node("Workspace", nil, "Workspace")
local treadmills = node("Treadmills", workspace)
local map = node("Map", workspace)
local all = { treadmills, map }
function workspace:GetDescendants() return all end
function workspace:FindFirstChild(name) if name == "Treadmills" then return treadmills end return nil end
function __addPart(t)
	local p = node("Part", if t[16] == 1 then treadmills else map, "Part")
	local r = { t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12] }
	p.CFrame = { Position = Vector3.new(t[1], t[2], t[3]), RightVector = Vector3.new(r[1], r[4], r[7]), UpVector = Vector3.new(r[2], r[5], r[8]), LookVector = Vector3.new(-r[3], -r[6], -r[9]) }
	p.Size = Vector3.new(t[13], t[14], t[15])
	p.CanCollide = true
	table.insert(all, p)
end
'''

def lua_parts():
    rows = []
    for p in data["parts"]:
        rows.append("__addPart({" + ",".join(repr(v) for v in p[:16]) + "})")
    return "\n".join(rows)

starts = {"stuck_at_fence_log": (2523.6, 3.0, -1098.0), "safe_zone": (2440.0, 3.0, -940.0)}
targets = [(c[0], c[1], c[2], c[3]) for c in data["crates"]]
targets += [("seller", 2433.8, 4.2, -864.1), ("thunder", 2470.3, 5.2, -937.2), ("fuse", 2438.9, 4.8, -845.8),
            ("free_gift", 2430.6, 6.0, -1019.1), ("plot1", 2466.3, 6.0, -1131.8), ("plot3", 2566.2, 6.0, -1110.9)]

driver = ["local clock = os.clock()", "Nav.build()", 'print(string.format("BUILD %.2f", os.clock() - clock))']
for sname, s in starts.items():
    for tname, x, y, z in targets:
        driver.append('do local t0 = os.clock() local list = Nav.path(Vector3.new(%r,%r,%r), Vector3.new(%r,%r,%r)) '
                      'local pts = {} if list then for _, w in ipairs(list) do table.insert(pts, string.format("[%%.2f,%%.2f]", w.Position.X, w.Position.Z)) end end '
                      'print(string.format("ROUTE %s %s %%.3f %%s", os.clock() - t0, list and ("[" .. table.concat(pts, ",") .. "]") or "null")) end'
                      % (s[0], s[1], s[2], x, y, z, sname, tname))
program = PRELUDE + "\n" + lua_parts() + "\n" + nav + "\n" + "\n".join(driver) + "\n"
build_dir = os.path.join(os.path.dirname(HERE), ".build")
os.makedirs(build_dir, exist_ok=True)
path = os.path.join(build_dir, "realmap_nav.luau")
open(path, "w").write(program)
luau = find_luau(None)
res = subprocess.run([luau, path], capture_output=True, text=True, timeout=900)
if res.returncode != 0:
    print(res.stdout[-3000:], res.stderr[-3000:])
    sys.exit("luau failed")

# independent check with the exact part boxes: floor = wide flat parts, walls =
# anything from 0.6 to 5.5 studs above the floor that is not a wide low step
HALF = 0.9
boxes = []
for p in data["parts"]:
    x, y, z = p[0:3]; r = p[3:12]; sx, sy, sz = p[12] / 2, p[13] / 2, p[14] / 2
    ex = abs(r[0]) * sx + abs(r[1]) * sy + abs(r[2]) * sz
    ey = abs(r[3]) * sx + abs(r[4]) * sy + abs(r[5]) * sz
    ez = abs(r[6]) * sx + abs(r[7]) * sy + abs(r[8]) * sz
    boxes.append((x, z, r, sx, sy, sz, ex, ez, y - ey, y + ey, min(ex, ez) * 2 >= 1.5, p[15] == 1, p[16]))

def inside(b, px, pz, margin):
    x, z, r, sx, sy, sz = b[:6]
    dx, dz = px - x, pz - z
    return max(abs(dx * r[0] + dz * r[6]) - sx, abs(dx * r[1] + dz * r[7]) - sy, abs(dx * r[2] + dz * r[8]) - sz) < margin

floors = [b for b in boxes if b[10] and -6 < b[9] <= 4.5]
walls = []
for b in boxes:
    if b[11] or (b[9] > 1.6 and b[8] < 10):
        walls.append(b)
BUCKET = 16
grid = {}
for w in walls:
    for bx in range(int((w[0] - w[6]) // BUCKET), int((w[0] + w[6]) // BUCKET) + 1):
        for bz in range(int((w[1] - w[7]) // BUCKET), int((w[1] + w[7]) // BUCKET) + 1):
            grid.setdefault((bx, bz), []).append(w)

fgrid = {}
for b in floors:
    for bx in range(int((b[0] - b[6]) // BUCKET), int((b[0] + b[6]) // BUCKET) + 1):
        for bz in range(int((b[1] - b[7]) // BUCKET), int((b[1] + b[7]) // BUCKET) + 1):
            fgrid.setdefault((bx, bz), []).append(b)

def ground(px, pz):
    g = None
    for b in fgrid.get((int(px // BUCKET), int(pz // BUCKET)), ()):
        if inside(b, px, pz, 0) and (g is None or b[9] > g):
            g = b[9]
    return 1.0 if g is None else g

def hits(px, pz):
    g = ground(px, pz)
    for b in grid.get((int(px // BUCKET), int(pz // BUCKET)), ()):
        bottom, top, wide, tread = b[8], b[9], b[10], b[11]
        blocks = tread or (bottom < g + 5.5 and top > g + 0.6 and not (wide and top <= g + 2.2))
        if blocks and inside(b, px, pz, HALF):
            return b[12]
    return None

failures, routes, slowest = [], 0, 0.0
build_time = None
for line in res.stdout.splitlines():
    if line.startswith("BUILD"):
        build_time = float(line.split()[1])
    if not line.startswith("ROUTE"):
        continue
    _, sname, tname, secs, pts = line.split(" ", 4)
    routes += 1
    slowest = max(slowest, float(secs))
    if pts == "null":
        failures.append("%s -> %s: no route" % (sname, tname)); continue
    pts = json.loads(pts)
    tgt = next(t for t in targets if t[0] == tname)
    end = pts[-1]
    if math.hypot(end[0] - tgt[1], end[1] - tgt[3]) > 24:
        failures.append("%s -> %s: ends %.0f studs from the target" % (sname, tname, math.hypot(end[0] - tgt[1], end[1] - tgt[3])))
    last_g = None
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 0.5))
        bad = None
        for k in range(n + 1):
            px, pz = a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n
            name = hits(px, pz)
            if name:
                bad = "segment touches %s at (%.1f, %.1f)" % (name, px, pz)
                break
            g = ground(px, pz)
            if last_g is not None and g - last_g > 1.25:
                bad = "climbs a %.1f stud ledge at (%.1f, %.1f)" % (g - last_g, px, pz)
                break
            last_g = g
        if bad:
            failures.append("%s -> %s: %s" % (sname, tname, bad))
            break
print("walk map built in %.2f s (luau CLI), %d routes, slowest %.3f s, %d wall/fence parts checked" % (build_time or -1, routes, slowest, len(walls)))
for f in failures[:30]:
    print("  FAIL", f)
print("%d/%d routes clear" % (routes - len(failures), routes))
sys.exit(1 if failures else 0)
