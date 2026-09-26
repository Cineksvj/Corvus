--!nocheck
-- Simulated Roblox client engine for running the game-logic half of the Corvus hub offline
-- in the standalone Luau CLI: datatypes (Vector3/CFrame/...), a deterministic cooperative
-- scheduler with simulated time (task.*, os.clock, RunService.Heartbeat/RenderStepped),
-- an Instance tree with signals/attributes, remotes that log every call and deliver to the
-- simulated server with latency, the ProximityPrompt engine and a mock of the UI library.
--
-- run_sftr.py concatenates: __SIM_ARGS header + this file + sftr_server.luau (world and
-- game server) + harness.luau (scenario runner) + a scenario + the script under test, which
-- is loaded with loadstring(src, "=Steal From The Rich") so line numbers match the file.

local fmt = string.format
local ARGS = __SIM_ARGS or {}

Sim = {}
Sim.T0 = 500 -- os.clock() at scenario start (a real client has been running for a while)
Sim.now = Sim.T0
Sim.dt = 1 / 60
Sim.frame = 0
Sim.config = {}
Sim.errors = {}
Sim.warnings = {}
Sim.remoteLog = {}
Sim.statusHistory = {}
Sim.notes = {}
Sim.status = nil
Sim.statusSince = Sim.T0
Sim.verbose = ARGS.verbose ~= false

local function stamp()
	return fmt("[t=%7.2f]", Sim.now - Sim.T0)
end

function Sim.log(kind, msg)
	print(stamp() .. " " .. kind .. " " .. msg)
end

function Sim.elapsed()
	return Sim.now - Sim.T0
end

---------------------------------------------------------------------------
-- typeof with __type support for our table-based datatypes
---------------------------------------------------------------------------
local rawtypeof = typeof
function typeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__type") then
			return mt.__type
		end
	end
	return rawtypeof(v)
end

---------------------------------------------------------------------------
-- Datatypes: Vector3, Vector2, CFrame, Color3, UDim/UDim2, Enum, TweenInfo
---------------------------------------------------------------------------
local V3MT = { __type = "Vector3" }
local V3methods = {}
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3MT)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	elseif k == "z" then
		return v.Z
	end
	local m = V3methods[k]
	if m then
		return m
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3MT.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3MT.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3MT.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3MT.__tostring = function(v)
	return fmt("%g, %g, %g", v.X, v.Y, v.Z)
end
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3methods.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3methods.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
function V3methods.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
Vector3 = {
	new = function(x, y, z)
		return v3(x or 0, y or 0, z or 0)
	end,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

local V2MT = { __type = "Vector2" }
V2MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	return nil
end
V2MT.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, V2MT)
end
V2MT.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, V2MT)
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
	end,
}
Vector2.zero = Vector2.new(0, 0)

-- CFrame: position + 3x3 rotation matrix (row major, [1..9])
local CFMT = { __type = "CFrame" }
local CFmethods = {}
local function cfraw(x, y, z, r)
	return setmetatable({ x = x, y = y, z = z, r = r }, CFMT)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
local function rotvec(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
CFMT.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c.x, c.y, c.z)
	elseif k == "X" then
		return c.x
	elseif k == "Y" then
		return c.y
	elseif k == "Z" then
		return c.z
	elseif k == "Rotation" then
		return cfraw(0, 0, 0, c.r)
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "RightVector" then
		return v3(c.r[1], c.r[4], c.r[7])
	elseif k == "UpVector" then
		return v3(c.r[2], c.r[5], c.r[8])
	end
	local m = CFmethods[k]
	if m then
		return m
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CFMT.__mul = function(a, b)
	local tb = typeof(b)
	if tb == "CFrame" then
		local x, y, z = rotvec(a.r, b.x, b.y, b.z)
		return cfraw(a.x + x, a.y + y, a.z + z, matmul(a.r, b.r))
	elseif tb == "Vector3" then
		local x, y, z = rotvec(a.r, b.X, b.Y, b.Z)
		return v3(a.x + x, a.y + y, a.z + z)
	end
	error("invalid CFrame multiplication with " .. tb, 2)
end
CFMT.__add = function(a, b)
	return cfraw(a.x + b.X, a.y + b.Y, a.z + b.Z, a.r)
end
CFMT.__sub = function(a, b)
	return cfraw(a.x - b.X, a.y - b.Y, a.z - b.Z, a.r)
end
CFMT.__eq = function(a, b)
	if a.x ~= b.x or a.y ~= b.y or a.z ~= b.z then
		return false
	end
	for i = 1, 9 do
		if a.r[i] ~= b.r[i] then
			return false
		end
	end
	return true
end
CFMT.__tostring = function(c)
	return fmt("%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g", c.x, c.y, c.z, table.unpack(c.r))
end
function CFmethods.Inverse(c)
	local rt = transpose(c.r)
	local x, y, z = rotvec(rt, c.x, c.y, c.z)
	return cfraw(-x, -y, -z, rt)
end
function CFmethods.PointToWorldSpace(c, v)
	return c * v
end
function CFmethods.PointToObjectSpace(c, v)
	return c:Inverse() * v
end
function CFmethods.VectorToWorldSpace(c, v)
	return v3(rotvec(c.r, v.X, v.Y, v.Z))
end
function CFmethods.VectorToObjectSpace(c, v)
	return v3(rotvec(transpose(c.r), v.X, v.Y, v.Z))
end
function CFmethods.ToWorldSpace(c, o)
	return c * o
end
function CFmethods.ToObjectSpace(c, o)
	return c:Inverse() * o
end
function CFmethods.GetComponents(c)
	return c.x, c.y, c.z, table.unpack(c.r)
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.Lerp(a, b, t)
	return cfraw(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, t < 0.5 and a.r or b.r)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function lookAt(pos, target)
	local f = (target - pos).Unit
	local right = f:Cross(v3(0, 1, 0))
	if right.Magnitude < 1e-6 then
		right = v3(1, 0, 0)
	end
	right = right.Unit
	local up = right:Cross(f)
	return cfraw(pos.X, pos.Y, pos.Z, { right.X, up.X, -f.X, right.Y, up.Y, -f.Y, right.Z, up.Z, -f.Z })
end
CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then
		return cfraw(0, 0, 0, IDENT)
	end
	if typeof(a) == "Vector3" then
		if typeof(b) == "Vector3" then
			return lookAt(a, b)
		end
		return cfraw(a.X, a.Y, a.Z, IDENT)
	end
	local rest = { ... }
	if #rest == 9 then
		return cfraw(a, b, c, rest)
	end
	return cfraw(a, b or 0, c or 0, IDENT)
end
function CFrame.Angles(x, y, z)
	return cfraw(0, 0, 0, matmul(matmul(rx(x or 0), ry(y or 0)), rz(z or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return cfraw(0, 0, 0, matmul(matmul(ry(y or 0), rx(x or 0)), rz(z or 0)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
CFrame.lookAt = lookAt
CFrame.identity = cfraw(0, 0, 0, IDENT)

local C3Methods = {}
local C3MT = { __type = "Color3", __index = C3Methods }
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3MT)
	end,
}
function C3Methods:ToHex()
	local function byte(v)
		return math.clamp(math.floor(v * 255 + 0.5), 0, 255)
	end
	return string.format("%02x%02x%02x", byte(self.R), byte(self.G), byte(self.B))
end
function C3Methods:Lerp(other, t)
	return Color3.new(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
end
Color3.fromRGB = function(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
Color3.fromHSV = function(h, sat, v)
	h, sat, v = h or 0, sat or 0, v or 1
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - sat), v * (1 - f * sat), v * (1 - (1 - f) * sat)
	local row = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
	return Color3.new(row[1], row[2], row[3])
end
Color3.fromHex = function(hex)
	hex = tostring(hex or ""):gsub("^#", "")
	if not hex:match("^%x%x%x%x%x%x$") then
		error("Unable to convert hex string", 2)
	end
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
local UDMT = { __type = "UDim2" }
UDim2 = {
	new = function(a, b, c, d)
		return setmetatable({ X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } }, UDMT)
	end,
}
UDim2.fromScale = function(a, b)
	return UDim2.new(a, 0, b, 0)
end
UDim2.fromOffset = function(a, b)
	return UDim2.new(0, a, 0, b)
end
UDim = {
	new = function(a, b)
		return setmetatable({ Scale = a or 0, Offset = b or 0 }, { __type = "UDim" })
	end,
}
TweenInfo = {
	new = function(...)
		return setmetatable({ Time = select(1, ...) or 1 }, { __type = "TweenInfo" })
	end,
}
RaycastParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude, IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false }, { __type = "RaycastParams" })
	end,
}
OverlapParams = RaycastParams
NumberSequence = { new = function() return {} end }
NumberSequenceKeypoint = { new = function() return {} end }
ColorSequence = { new = function() return {} end }

local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
Enum = setmetatable({}, {
	__index = function(t, enumName)
		local e = setmetatable({}, {
			__index = function(t2, itemName)
				local item = setmetatable({ Name = itemName, EnumType = enumName, Value = 0 }, EnumItemMT)
				rawset(t2, itemName, item)
				return item
			end,
		})
		rawset(t, enumName, e)
		return e
	end,
})

---------------------------------------------------------------------------
-- Scheduler (cooperative, simulated time)
---------------------------------------------------------------------------
local timers = {}
local deferredQ = {}
local seq = 0
local threadSite = setmetatable({}, { __mode = "k" }) -- thread -> last yield site
Sim.threadSite = threadSite

local function reportError(co, err)
	local tb = debug.traceback(co, tostring(err))
	table.insert(Sim.errors, tb)
	Sim.log("LUA-ERROR", tb)
end

local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return false
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		reportError(co, err)
	end
	return ok
end
Sim.resume = resume

local function callerSite(level)
	local src, line = debug.info(level + 1, "sl")
	return src, line
end

local function noteSite(co, level)
	local src, line = callerSite(level + 1)
	threadSite[co] = { src = src, line = line, since = Sim.now }
	if ARGS.mainLoopWaitLine and line == ARGS.mainLoopWaitLine and src == ARGS.scriptName then
		Sim.onMainLoopCycle(co)
	end
end

local function schedule(entry)
	seq += 1
	entry.seq = seq
	table.insert(timers, entry)
end

-- internal sleep used by mock methods; records the call site `level` frames up
local function sleep(t, level)
	local co, isMain = coroutine.running()
	if isMain or co == nil then
		error("attempt to yield from outside a coroutine", 3)
	end
	noteSite(co, (level or 1) + 1)
	schedule({ co = co, wake = Sim.now + (tonumber(t) or 0), start = Sim.now })
	return coroutine.yield()
end
Sim.sleep = sleep

task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(deferredQ, { co = co, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	schedule({ co = co, wake = Sim.now + (tonumber(t) or 0), start = Sim.now, args = table.pack(...) })
	return co
end
function task.wait(t)
	return sleep(t, 2)
end
function task.cancel(co)
	for i = #timers, 1, -1 do
		if timers[i].co == co then
			table.remove(timers, i)
		end
	end
	pcall(coroutine.close, co)
end
function task.synchronize() end
function task.desynchronize() end
wait = function(t)
	local e = sleep(t or 0.03, 2)
	return e, Sim.now
end
spawn = function(f)
	task.defer(f)
end
delay = function(t, f)
	task.delay(t, f)
end

local function runTimers()
	local due, keep = {}, {}
	for _, tm in ipairs(timers) do
		if tm.wake <= Sim.now + 1e-9 then
			table.insert(due, tm)
		else
			table.insert(keep, tm)
		end
	end
	timers = keep
	table.sort(due, function(a, b)
		if a.wake ~= b.wake then
			return a.wake < b.wake
		end
		return a.seq < b.seq
	end)
	for _, tm in ipairs(due) do
		if tm.args then
			resume(tm.co, table.unpack(tm.args, 1, tm.args.n))
		else
			resume(tm.co, Sim.now - tm.start)
		end
	end
end

local function runDeferred()
	local guard = 0
	while #deferredQ > 0 do
		local q = deferredQ
		deferredQ = {}
		for _, d in ipairs(q) do
			resume(d.co, table.unpack(d.args, 1, d.args.n))
		end
		guard += 1
		if guard > 1000 then
			error("task.defer re-entrancy limit reached (deferred threads keep deferring)")
		end
	end
end
Sim.runDeferred = runDeferred

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local ConnMT = {}
ConnMT.__index = ConnMT
function ConnMT:Disconnect()
	self.Connected = false
end
ConnMT.disconnect = ConnMT.Disconnect
setmetatable(Signal, { __type = "RBXScriptSignal" })
Signal.__type = "RBXScriptSignal"

function Signal.new(name)
	return setmetatable({ conns = {}, waiters = {}, name = name }, Signal)
end
function Signal:Connect(fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local c = setmetatable({ Connected = true, fn = fn }, ConnMT)
	table.insert(self.conns, c)
	return c
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local co, isMain = coroutine.running()
	if isMain or co == nil then
		error("attempt to yield from outside a coroutine", 2)
	end
	noteSite(co, 2)
	table.insert(self.waiters, co)
	return coroutine.yield()
end
Signal.wait = Signal.Wait
function Signal:Fire(...)
	if #self.conns > 0 then
		local live = {}
		for _, c in ipairs(self.conns) do
			if c.Connected then
				table.insert(live, c)
			end
		end
		self.conns = live
		for _, c in ipairs(table.clone(live)) do
			if c.Connected then
				task.spawn(c.fn, ...)
			end
		end
	end
	if #self.waiters > 0 then
		local w = self.waiters
		self.waiters = {}
		for _, co in ipairs(w) do
			resume(co, ...)
		end
	end
end
function Signal:HasListeners()
	return #self.conns > 0 or #self.waiters > 0
end
Sim.Signal = Signal

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local NIL = {}
local InstMT = { __type = "Instance" }
local Classes = {}
local Prompts = {} -- every live ProximityPrompt, in creation order (deterministic iteration)
Sim.Prompts = Prompts
local Parts = {} -- every BasePart, for raycasts
Sim.Parts = Parts

local function defClass(name, superName, def)
	def = def or {}
	local super = superName and Classes[superName]
	local cls = { name = name, props = {}, propNames = {}, methods = {}, getters = {}, setters = {}, events = {}, isa = { [name] = true }, init = def.init }
	if super then
		for k, v in pairs(super.props) do
			cls.props[k] = v
		end
		for k in pairs(super.propNames) do
			cls.propNames[k] = true
		end
		for k, v in pairs(super.methods) do
			cls.methods[k] = v
		end
		for k, v in pairs(super.getters) do
			cls.getters[k] = v
		end
		for k, v in pairs(super.setters) do
			cls.setters[k] = v
		end
		for k in pairs(super.events) do
			cls.events[k] = true
		end
		for k in pairs(super.isa) do
			cls.isa[k] = true
		end
		cls.init = def.init or super.init
		cls.superInit = super.init
	end
	for k, v in pairs(def.props or {}) do
		cls.props[k] = v
		cls.propNames[k] = true
	end
	for k, v in pairs(def.methods or {}) do
		cls.methods[k] = v
	end
	for k, v in pairs(def.getters or {}) do
		cls.getters[k] = v
	end
	for k, v in pairs(def.setters or {}) do
		cls.setters[k] = v
	end
	for _, e in ipairs(def.events or {}) do
		cls.events[e] = true
	end
	for _, a in ipairs(def.isa or {}) do
		cls.isa[a] = true
	end
	Classes[name] = cls
	return cls
end

local function isInstance(v)
	return type(v) == "table" and getmetatable(v) == InstMT
end
Sim.isInstance = isInstance

local function getEvent(self, name)
	local s = self.__sig[name]
	if not s then
		s = Signal.new(name)
		self.__sig[name] = s
	end
	return s
end
local function fireEvent(self, name, ...)
	local s = self.__sig[name]
	if s then
		s:Fire(...)
	end
end
Sim.fireEvent = fireEvent

local function propChanged(self, prop)
	local s = self.__psig[prop]
	if s then
		s:Fire()
	end
	fireEvent(self, "Changed", prop)
end

local function fullName(self)
	local parts = {}
	local node = self
	while node and node ~= game do
		table.insert(parts, 1, node.__p.Name)
		node = node.__p.Parent
	end
	return table.concat(parts, ".")
end
Sim.fullName = fullName

local function findChild(self, name, recursive)
	for _, c in ipairs(self.__ch) do
		if c.__p.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(self.__ch) do
			local r = findChild(c, name, true)
			if r then
				return r
			end
		end
	end
	return nil
end

InstMT.__index = function(self, k)
	local p = self.__p
	local v = p[k]
	if v ~= nil then
		return v
	end
	local cls = self.__cls
	local m = cls.methods[k]
	if m ~= nil then
		return m
	end
	local g = cls.getters[k]
	if g then
		return g(self)
	end
	if cls.events[k] then
		return getEvent(self, k)
	end
	if cls.propNames[k] then
		return nil
	end
	local child = findChild(self, k)
	if child then
		return child
	end
	error(fmt("%s is not a valid member of %s \"%s\"", tostring(k), cls.name, fullName(self)), 2)
end

local typeChecks = {
	CFrame = "CFrame",
	Position = "Vector3",
	Size = "Vector3",
	AssemblyLinearVelocity = "Vector3",
	Velocity = "Vector3",
	Name = "string",
	Enabled = "boolean",
	HoldDuration = "number",
	MaxActivationDistance = "number",
	WalkSpeed = "number",
}

InstMT.__newindex = function(self, k, v)
	local cls = self.__cls
	local want = typeChecks[k]
	if want and typeof(v) ~= want and not (want == "boolean" and v == nil) then
		error(fmt("Unable to assign property %s. %s expected, got %s", k, want, typeof(v)), 2)
	end
	local setter = cls.setters[k]
	if setter then
		setter(self, v)
		return
	end
	if cls.propNames[k] or self.__p[k] ~= nil then
		local old = self.__p[k]
		self.__p[k] = v
		if old ~= v then
			propChanged(self, k)
		end
		return
	end
	error(fmt("%s is not a valid member of %s \"%s\"", tostring(k), cls.name, fullName(self)), 2)
end
InstMT.__tostring = function(self)
	return self.__p.Name
end

local function descendants(self, out)
	out = out or {}
	for _, c in ipairs(self.__ch) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local function isDescendantOf(self, anc)
	local node = self.__p.Parent
	while node do
		if node == anc then
			return true
		end
		node = node.__p.Parent
	end
	return false
end
Sim.isDescendantOf = isDescendantOf

local function setParent(self, newParent)
	if newParent ~= nil and not isInstance(newParent) then
		error("Unable to assign property Parent. Instance expected, got " .. typeof(newParent), 3)
	end
	local old = self.__p.Parent
	if old == newParent then
		return
	end
	if self.__destroyed then
		error(fmt("The Parent property of %s is locked, current parent: NULL, new parent %s", self.__p.Name, newParent and newParent.__p.Name or "NULL"), 3)
	end
	if newParent == self or (newParent and isDescendantOf(newParent, self)) then
		error("Attempt to set parent of " .. self.__p.Name .. " to itself or a descendant", 3)
	end
	if old then
		local list = old.__ch
		local idx = table.find(list, self)
		if idx then
			table.remove(list, idx)
		end
		local node = old
		while node do
			fireEvent(node, "DescendantRemoving", self)
			node = node.__p.Parent
		end
		fireEvent(old, "ChildRemoved", self)
	end
	self.__p.Parent = newParent
	if newParent then
		table.insert(newParent.__ch, self)
		fireEvent(newParent, "ChildAdded", self)
		local node = newParent
		while node do
			fireEvent(node, "DescendantAdded", self)
			node = node.__p.Parent
		end
	end
	fireEvent(self, "AncestryChanged", self, newParent)
	for _, d in ipairs(descendants(self)) do
		fireEvent(d, "AncestryChanged", self, newParent)
	end
	propChanged(self, "Parent")
end

local allowedAttr = {
	["nil"] = true, boolean = true, number = true, string = true, Vector3 = true, Vector2 = true, CFrame = true,
	Color3 = true, UDim = true, UDim2 = true, EnumItem = true,
}

defClass("Instance", nil, {
	props = { Name = "Instance", Parent = NIL, Archivable = true },
	events = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "AttributeChanged", "Destroying" },
	getters = {
		ClassName = function(self)
			return self.__cls.name
		end,
	},
	setters = {
		Parent = setParent,
		Name = function(self, v)
			self.__p.Name = v
			propChanged(self, "Name")
		end,
	},
	methods = {
		FindFirstChild = function(self, name, recursive)
			return findChild(self, name, recursive)
		end,
		FindFirstChildOfClass = function(self, className)
			for _, c in ipairs(self.__ch) do
				if c.__cls.name == className then
					return c
				end
			end
			return nil
		end,
		FindFirstChildWhichIsA = function(self, className, recursive)
			for _, c in ipairs(recursive and descendants(self) or self.__ch) do
				if c.__cls.isa[className] then
					return c
				end
			end
			return nil
		end,
		FindFirstAncestor = function(self, name)
			local node = self.__p.Parent
			while node do
				if node.__p.Name == name then
					return node
				end
				node = node.__p.Parent
			end
			return nil
		end,
		FindFirstAncestorOfClass = function(self, className)
			local node = self.__p.Parent
			while node do
				if node.__cls.name == className then
					return node
				end
				node = node.__p.Parent
			end
			return nil
		end,
		FindFirstAncestorWhichIsA = function(self, className)
			local node = self.__p.Parent
			while node do
				if node.__cls.isa[className] then
					return node
				end
				node = node.__p.Parent
			end
			return nil
		end,
		GetChildren = function(self)
			return table.clone(self.__ch)
		end,
		GetDescendants = function(self)
			return descendants(self)
		end,
		IsA = function(self, className)
			return self.__cls.isa[className] == true or className == "Instance"
		end,
		IsDescendantOf = function(self, anc)
			return isDescendantOf(self, anc)
		end,
		IsAncestorOf = function(self, d)
			return isDescendantOf(d, self)
		end,
		GetFullName = function(self)
			return fullName(self)
		end,
		GetAttribute = function(self, name)
			return self.__attr[name]
		end,
		GetAttributes = function(self)
			return table.clone(self.__attr)
		end,
		SetAttribute = function(self, name, value)
			if not allowedAttr[typeof(value)] then
				error(fmt("SetAttribute(%q): %s is not a supported attribute type", tostring(name), typeof(value)), 2)
			end
			local old = self.__attr[name]
			if old == value then
				return
			end
			self.__attr[name] = value
			local s = self.__asig[name]
			if s then
				s:Fire()
			end
			fireEvent(self, "AttributeChanged", name)
		end,
		GetAttributeChangedSignal = function(self, name)
			local s = self.__asig[name]
			if not s then
				s = Signal.new("Attr:" .. name)
				self.__asig[name] = s
			end
			return s
		end,
		GetPropertyChangedSignal = function(self, prop)
			local s = self.__psig[prop]
			if not s then
				s = Signal.new("Prop:" .. prop)
				self.__psig[prop] = s
			end
			return s
		end,
		WaitForChild = function(self, name, timeout)
			local c = findChild(self, name)
			if c then
				return c
			end
			local started = Sim.now
			local warned = false
			while true do
				sleep(0, 2)
				c = findChild(self, name)
				if c then
					return c
				end
				if timeout and Sim.now - started >= timeout then
					return nil
				end
				if not timeout and not warned and Sim.now - started >= 5 then
					warned = true
					Sim.warn(fmt("Infinite yield possible on '%s:WaitForChild(\"%s\")'", fullName(self), name))
				end
			end
		end,
		Destroy = function(self)
			if self.__destroyed then
				return
			end
			fireEvent(self, "Destroying")
			for _, c in ipairs(table.clone(self.__ch)) do
				c:Destroy()
			end
			self.Parent = nil
			self.__destroyed = true
		end,
		ClearAllChildren = function(self)
			for _, c in ipairs(table.clone(self.__ch)) do
				c:Destroy()
			end
		end,
		Clone = function(self)
			error("Clone is not supported by the mock")
		end,
	},
})

local function newInstance(className, parent)
	local cls = Classes[className]
	if not cls then
		error(fmt("Unable to create an Instance of type \"%s\"", tostring(className)), 2)
	end
	local p = {}
	for k, v in pairs(cls.props) do
		if v ~= NIL then
			p[k] = v
		end
	end
	p.Name = className
	local self = setmetatable({ __cls = cls, __p = p, __ch = {}, __attr = {}, __sig = {}, __psig = {}, __asig = {}, __destroyed = false }, InstMT)
	if cls.init then
		cls.init(self)
	end
	if parent then
		self.Parent = parent
	end
	return self
end
Instance = { new = newInstance }

local function make(className, props, parent, attrs)
	local inst = newInstance(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for k, v in pairs(attrs or {}) do
		inst:SetAttribute(k, v)
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
Sim.make = make

for _, n in ipairs({ "Folder", "Configuration", "LocalScript", "Script", "ScreenGui", "BillboardGui", "SurfaceGui", "Frame", "TextLabel", "Camera", "Sound", "Highlight", "Decal", "StarterGear", "Backpack", "PlayerGui", "PlayerScripts" }) do
	defClass(n, "Instance")
end
defClass("ModuleScript", "Instance")
defClass("StringValue", "Instance", { props = { Value = "" } })
defClass("NumberValue", "Instance", { props = { Value = 0 } })
defClass("BoolValue", "Instance", { props = { Value = false } })
defClass("ObjectValue", "Instance", { props = { Value = NIL } })

-- PVInstance / Model / BasePart ---------------------------------------------
local function modelPivot(self)
	local pp = self.__p.PrimaryPart
	if pp then
		return pp.__p.CFrame
	end
	local minX, minY, minZ, maxX, maxY, maxZ
	for _, d in ipairs(descendants(self)) do
		if d.__cls.isa.BasePart then
			local c = d.__p.CFrame
			minX = math.min(minX or c.x, c.x)
			minY = math.min(minY or c.y, c.y)
			minZ = math.min(minZ or c.z, c.z)
			maxX = math.max(maxX or c.x, c.x)
			maxY = math.max(maxY or c.y, c.y)
			maxZ = math.max(maxZ or c.z, c.z)
		end
	end
	if not minX then
		return CFrame.new()
	end
	return CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
end

defClass("PVInstance", "Instance", {
	methods = {
		GetPivot = function(self)
			if self.__cls.isa.BasePart then
				return self.__p.CFrame
			end
			return modelPivot(self)
		end,
		PivotTo = function(self, cf)
			if self.__cls.isa.BasePart then
				self.CFrame = cf
				return
			end
			local delta = cf * modelPivot(self):Inverse()
			for _, d in ipairs(descendants(self)) do
				if d.__cls.isa.BasePart then
					d.CFrame = delta * d.__p.CFrame
				end
			end
		end,
	},
})
defClass("Model", "PVInstance", { props = { PrimaryPart = NIL } })
defClass("Workspace", "Model", {
	props = { CurrentCamera = NIL, Gravity = 196.2, DistributedGameTime = 0 },
	methods = {
		-- Only straight-down rays are supported (that is all the script uses: ground checks).
		-- Hits the top face of every CanQuery BasePart (boxes rotated about Y only).
		Raycast = function(self, origin, direction, params)
			if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
				error("Raycast: Vector3 expected", 2)
			end
			if math.abs(direction.X) > 1e-6 or math.abs(direction.Z) > 1e-6 or direction.Y >= 0 then
				Sim.count("raycastUnsupported")
				return nil
			end
			local filter = params and params.FilterDescendantsInstances or {}
			local include = params and params.FilterType == Enum.RaycastFilterType.Include
			local bestTop, bestPart
			for i = #Parts, 1, -1 do
				local part = Parts[i]
				if part.__destroyed then
					table.remove(Parts, i)
				end
			end
			for _, part in ipairs(Parts) do
				local p = part.__p
				if p.CanQuery and isDescendantOf(part, self) then
					local inFilter = false
					for _, f in ipairs(filter) do
						if part == f or isDescendantOf(part, f) then
							inFilter = true
							break
						end
					end
					if inFilter ~= include then
						-- excluded (Exclude list hit) or not included (Include list miss)
					else
						local c = p.CFrame
						local lx, ly, lz = rotvec(transpose(c.r), origin.X - c.x, origin.Y - c.y, origin.Z - c.z)
						if math.abs(lx) <= p.Size.X / 2 and math.abs(lz) <= p.Size.Z / 2 then
							local top = c.y + p.Size.Y / 2
							if top <= origin.Y and top >= origin.Y + direction.Y and (not bestTop or top > bestTop) then
								bestTop, bestPart = top, part
							end
						end
					end
				end
			end
			if not bestTop then
				return nil
			end
			return setmetatable({
				Position = v3(origin.X, bestTop, origin.Z),
				Instance = bestPart,
				Normal = v3(0, 1, 0),
				Distance = origin.Y - bestTop,
				Material = Enum.Material.Plastic,
			}, { __type = "RaycastResult" })
		end,
		GetServerTimeNow = function()
			return Sim.now
		end,
	},
})
defClass("BasePart", "PVInstance", {
	props = {
		CFrame = CFrame.new(),
		Size = Vector3.new(4, 1, 2),
		Anchored = true,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		Transparency = 0,
		LocalTransparencyModifier = 0,
		AssemblyLinearVelocity = Vector3.zero,
		AssemblyAngularVelocity = Vector3.zero,
		Velocity = Vector3.zero,
		Massless = false,
		Material = NIL,
		Color = NIL,
	},
	events = { "Touched", "TouchEnded" },
	getters = {
		Position = function(self)
			local c = self.__p.CFrame
			return v3(c.x, c.y, c.z)
		end,
	},
	setters = {
		Position = function(self, v)
			local c = self.__p.CFrame
			self.__p.CFrame = cfraw(v.X, v.Y, v.Z, c.r)
			propChanged(self, "CFrame")
			propChanged(self, "Position")
		end,
		CFrame = function(self, v)
			self.__p.CFrame = v
			propChanged(self, "CFrame")
			propChanged(self, "Position")
		end,
	},
})
Classes.BasePart.init = function(self)
	table.insert(Parts, self)
end
defClass("Part", "BasePart")
defClass("MeshPart", "BasePart")
defClass("UnionOperation", "BasePart")

defClass("Attachment", "Instance", {
	props = { CFrame = CFrame.new() },
	getters = {
		Position = function(self)
			return self.__p.CFrame.Position
		end,
		WorldCFrame = function(self)
			local parent = self.__p.Parent
			if parent and parent.__cls.isa.BasePart then
				return parent.__p.CFrame * self.__p.CFrame
			end
			return self.__p.CFrame
		end,
		WorldPosition = function(self)
			local parent = self.__p.Parent
			if parent and parent.__cls.isa.BasePart then
				return parent.__p.CFrame * self.__p.CFrame.Position
			end
			return self.__p.CFrame.Position
		end,
	},
	setters = {
		Position = function(self, v)
			self.__p.CFrame = cfraw(v.X, v.Y, v.Z, self.__p.CFrame.r)
		end,
	},
})

-- Tools, Humanoid, Player ------------------------------------------------------
defClass("Tool", "Instance", {
	props = { RequiresHandle = false, CanBeDropped = false, Enabled = true, ToolTip = "", TextureId = "" },
	events = { "Equipped", "Unequipped", "Activated", "Deactivated" },
	isa = { "BackpackItem" },
})

defClass("Humanoid", "Instance", {
	props = { WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, AutoRotate = true, Health = 100, MaxHealth = 100, HipHeight = 2, Sit = false, PlatformStand = false, Jump = false },
	events = { "Died", "MoveToFinished", "StateChanged", "Running" },
	methods = {
		EquipTool = function(self, tool)
			if not (isInstance(tool) and tool.__cls.isa.Tool) then
				error("EquipTool: Tool expected", 2)
			end
			local char = self.__p.Parent
			local player = Sim.player
			for _, c in ipairs(table.clone(char.__ch)) do
				if c.__cls.isa.Tool and c ~= tool then
					c.Parent = player.Backpack
				end
			end
			if tool.__p.Parent ~= char then
				tool.Parent = char
				fireEvent(tool, "Equipped")
			end
		end,
		UnequipTools = function(self)
			local char = self.__p.Parent
			for _, c in ipairs(table.clone(char.__ch)) do
				if c.__cls.isa.Tool then
					c.Parent = Sim.player.Backpack
					fireEvent(c, "Unequipped")
				end
			end
		end,
		MoveTo = function(self, pos)
			Sim.moveTargets[self] = { pos = pos, t = Sim.now }
			Sim.count("MoveTo")
			if true then
				return
			end
		end,
		ChangeState = function() end,
		GetState = function()
			return Enum.HumanoidStateType.Running
		end,
		LoadAnimation = function()
			return { Play = function() end, Stop = function() end }
		end,
	},
})

defClass("PathfindingService", "Instance", {
	methods = {
		CreatePath = function(self, params)
			return Sim.newPath(params)
		end,
	},
})

defClass("Player", "Instance", {
	props = { UserId = 0, DisplayName = "", Character = NIL, AccountAge = 1000 },
	events = { "CharacterAdded", "CharacterRemoving", "Idled", "OnTeleport" },
	methods = {
		IsInGroup = function(self, groupId)
			return Sim.config and Sim.config.inGroup == true
		end,
		GetMouse = function()
			return { Hit = CFrame.new(), Target = nil }
		end,
		Kick = function(self, msg)
			Sim.note("Player:Kick(" .. tostring(msg) .. ")")
		end,
	},
})

-- Random: deterministic Park-Miller generator (not Roblox's numbers, but the sim
-- server and the script use the same one, so layouts computed on both sides agree)
Random = {}
function Random.new(seed)
	local state = math.floor(tonumber(seed) or 1) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local r = {}
	function r:NextNumber(a, b)
		state = (state * 48271) % 2147483647
		local x = state / 2147483647
		if a and b then
			return a + (b - a) * x
		end
		return x
	end
	function r:NextInteger(a, b)
		return a + math.floor(self:NextNumber() * (b - a + 1))
	end
	return r
end

-- Remotes ----------------------------------------------------------------------
local Net = { queue = {}, up = 0.08, down = 0.04 }
Sim.Net = Net

local function deepcopy(v, seen)
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return v
	end
	seen = seen or {}
	if seen[v] then
		return seen[v]
	end
	local out = {}
	seen[v] = out
	for k, val in pairs(v) do
		out[deepcopy(k, seen)] = deepcopy(val, seen)
	end
	return out
end
Sim.deepcopy = deepcopy

local describe
describe = function(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "Instance" then
		return v:GetFullName()
	elseif t == "Vector3" then
		return fmt("Vector3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
	elseif t == "CFrame" then
		return fmt("CFrame(%.1f, %.1f, %.1f)", v.x, v.y, v.z)
	elseif t == "string" then
		return fmt("%q", v)
	elseif t == "number" then
		return (v == math.floor(v) and math.abs(v) < 1e15) and tostring(math.floor(v)) or fmt("%.3f", v)
	elseif t == "table" then
		if depth > 2 then
			return "{...}"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local parts = {}
		for i, k in ipairs(keys) do
			if i > 10 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. describe(v[k], depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end
Sim.describe = describe

local function describeArgs(args)
	local parts = {}
	for i = 1, args.n do
		parts[i] = describe(args[i])
	end
	return table.concat(parts, ", ")
end

local function checkSerializable(remote, args)
	for i = 1, args.n do
		local t = type(args[i])
		if t == "function" or t == "thread" or t == "userdata" then
			Sim.note(fmt("%s: argument #%d is a %s and cannot be sent over the network", remote.__p.Name, i, t))
		end
	end
end

local function logRemote(remote, kind, args)
	local entry = { t = Sim.now - Sim.T0, name = remote.__p.Name, kind = kind, args = args, text = describeArgs(args) }
	table.insert(Sim.remoteLog, entry)
	if Sim.verbose then
		Sim.log("REMOTE", fmt("%s %s(%s)", kind, remote.__p.Name, entry.text))
	end
	return entry
end

function Net.push(at, fn)
	seq += 1
	table.insert(Net.queue, { at = at, fn = fn, seq = seq })
end
function Net.deliver()
	local due, keep = {}, {}
	for _, m in ipairs(Net.queue) do
		if m.at <= Sim.now + 1e-9 then
			table.insert(due, m)
		else
			table.insert(keep, m)
		end
	end
	Net.queue = keep
	table.sort(due, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.seq < b.seq
	end)
	for _, m in ipairs(due) do
		task.spawn(m.fn)
	end
end

defClass("RemoteEvent", "Instance", {
	events = { "OnClientEvent", "OnServerEvent" },
	methods = {
		FireServer = function(self, ...)
			local args = table.pack(...)
			checkSerializable(self, args)
			local entry = logRemote(self, "FireServer", args)
			local copy = deepcopy(args)
			Net.push(Sim.now + Net.up, function()
				Sim.Server.onEvent(self, copy, entry)
			end)
		end,
		FireClient = function(self, player, ...)
			local copy = deepcopy(table.pack(...))
			Net.push(Sim.now + Net.down, function()
				fireEvent(self, "OnClientEvent", table.unpack(copy, 1, copy.n))
			end)
		end,
		FireAllClients = function(self, ...)
			local copy = deepcopy(table.pack(...))
			Net.push(Sim.now + Net.down, function()
				fireEvent(self, "OnClientEvent", table.unpack(copy, 1, copy.n))
			end)
		end,
	},
})
defClass("RemoteFunction", "Instance", {
	props = { OnClientInvoke = NIL },
	methods = {
		InvokeServer = function(self, ...)
			local co, isMain = coroutine.running()
			if isMain or not co then
				error("InvokeServer must be called from a coroutine", 2)
			end
			local args = table.pack(...)
			checkSerializable(self, args)
			local entry = logRemote(self, "InvokeServer", args)
			local copy = deepcopy(args)
			noteSite(co, 2)
			Net.push(Sim.now + Net.up, function()
				local result = table.pack(pcall(Sim.Server.onInvoke, self, copy, entry))
				local ok = table.remove(result, 1)
				result.n -= 1
				if not ok then
					Sim.log("SERVER-ERROR", tostring(result[1]))
					result = { n = 0 }
				end
				entry.result = describeArgs(result)
				if Sim.verbose then
					Sim.log("REMOTE", fmt("  -> %s returned %s", self.__p.Name, entry.result))
				end
				local back = deepcopy(result)
				Net.push(Sim.now + Net.down, function()
					resume(co, table.unpack(back, 1, back.n))
				end)
			end)
			return coroutine.yield()
		end,
	},
})
defClass("BindableEvent", "Instance", {
	events = { "Event" },
	methods = {
		Fire = function(self, ...)
			fireEvent(self, "Event", ...)
		end,
	},
})

-- ProximityPrompt --------------------------------------------------------------
local PromptEngine -- forward
defClass("ProximityPrompt", "Instance", {
	props = {
		Enabled = true,
		ActionText = "Interact",
		ObjectText = "",
		HoldDuration = 0,
		MaxActivationDistance = 10,
		MaxIndicatorDistance = 0,
		RequiresLineOfSight = true,
		ClickablePrompt = true,
		AutoLocalize = true,
		Style = Enum.ProximityPromptStyle.Default,
		Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		UIOffset = Vector2.zero,
	},
	events = { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" },
	init = function(self)
		table.insert(Prompts, self)
	end,
	methods = {
		InputHoldBegin = function(self)
			PromptEngine.holdBegin(self)
		end,
		InputHoldEnd = function(self)
			PromptEngine.holdEnd(self)
		end,
	},
})

-- Services -----------------------------------------------------------------
defClass("Players", "Instance", {
	props = { LocalPlayer = NIL, MaxPlayers = 8 },
	events = { "PlayerAdded", "PlayerRemoving" },
	methods = {
		GetPlayers = function(self)
			local out = {}
			for _, c in ipairs(self.__ch) do
				if c.__cls.isa.Player then
					table.insert(out, c)
				end
			end
			return out
		end,
		GetPlayerByUserId = function(self, id)
			for _, c in ipairs(self.__ch) do
				if c.__cls.isa.Player and c.__p.UserId == id then
					return c
				end
			end
			return nil
		end,
		GetPlayerFromCharacter = function(self, char)
			for _, c in ipairs(self.__ch) do
				if c.__cls.isa.Player and c.__p.Character == char then
					return c
				end
			end
			return nil
		end,
	},
})
defClass("ReplicatedStorage", "Instance")
defClass("RunService", "Instance", {
	events = { "Heartbeat", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation", "PreRender" },
	methods = {
		IsClient = function()
			return true
		end,
		IsServer = function()
			return false
		end,
		IsStudio = function()
			return false
		end,
		IsRunning = function()
			return true
		end,
		BindToRenderStep = function() end,
		UnbindFromRenderStep = function() end,
	},
})
defClass("ProximityPromptService", "Instance", {
	props = { Enabled = true, MaxPromptsVisible = 16 },
	events = { "PromptShown", "PromptHidden", "PromptTriggered", "PromptTriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
})
defClass("StarterGui", "Instance", {
	methods = {
		SetCore = function(self, name, value)
			Sim.note("StarterGui:SetCore(" .. tostring(name) .. ", " .. describe(value) .. ")")
		end,
		GetCore = function()
			return nil
		end,
		SetCoreGuiEnabled = function() end,
	},
})
defClass("GenericService", "Instance")
defClass("DataModel", "Instance", {
	props = { GameId = 10753751277, PlaceId = 120475074479690, JobId = "56c3b351-110f-4916-b12d-4103a668160b", PlaceVersion = 1, CreatorId = 0 },
	events = { "Loaded", "Close" },
	methods = {
		IsLoaded = function()
			return true
		end,
		GetService = function(self, name)
			local s = Sim.services[name]
			if s then
				return s
			end
			s = findChild(self, name)
			if s then
				return s
			end
			s = newInstance("GenericService")
			s.Name = name
			s.Parent = self
			Sim.services[name] = s
			return s
		end,
		FindService = function(self, name)
			return Sim.services[name]
		end,
		HttpGet = function(self, url)
			Sim.note("game:HttpGet(" .. tostring(url) .. ") was called - the harness has no network")
			error("HttpGet is not available in the offline harness: " .. tostring(url), 2)
		end,
		BindToClose = function() end,
	},
})

---------------------------------------------------------------------------
-- Diagnostics helpers
---------------------------------------------------------------------------
function Sim.warn(msg)
	table.insert(Sim.warnings, msg)
	Sim.log("WARN", msg)
end
warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	Sim.warn(table.concat(parts, " "))
end
function Sim.note(msg)
	table.insert(Sim.notes, { t = Sim.elapsed(), msg = msg })
	Sim.log("NOTE", msg)
end

---------------------------------------------------------------------------
-- Executor globals
---------------------------------------------------------------------------
local GENV = {}
-- writefile keeps files in memory; the harness prints Corvus_SFTR_log.txt at the end
__Files = {}
writefile = function(name, content)
	__Files[name] = content
end
getgenv = function()
	return GENV
end
getrenv = function()
	return GENV
end
identifyexecutor = function()
	return "CorvusHarness", "1.0"
end
cloneref = function(x)
	return x
end
setthreadidentity = nil
fireproximityprompt = nil
firetouchinterest = nil

os = setmetatable({
	clock = function()
		return Sim.now
	end,
	time = function()
		return 1790445373 + math.floor(Sim.now - Sim.T0)
	end,
}, { __index = os })
tick = function()
	return 1790445373 + (Sim.now - Sim.T0)
end
time = function()
	return Sim.now - Sim.T0
end


---------------------------------------------------------------------------
-- DataModel + local player
---------------------------------------------------------------------------
Sim.services = {}
function Sim.createDataModel()
	game = newInstance("DataModel")
	game.Name = "Game"
	Game = game
	local function service(className, name)
		local s = newInstance(className)
		s.Name = name or className
		s.Parent = game
		Sim.services[name or className] = s
		return s
	end
	workspace = service("Workspace")
	Workspace = workspace
	service("Players")
	service("ReplicatedStorage")
	service("RunService")
	service("ProximityPromptService")
	service("StarterGui")
	service("PathfindingService")
	for _, n in ipairs({ "Lighting", "SoundService", "UserInputService", "TweenService", "HttpService", "CoreGui", "VirtualUser", "TeleportService", "TextChatService", "Debris", "MarketplaceService", "GuiService", "Stats", "ContentProvider" }) do
		service("GenericService", n)
	end
	workspace.CurrentCamera = make("Camera", { Name = "Camera" }, workspace)
	return game
end

function Sim.createLocalPlayer(name, userId, position, attrs)
	local Players = Sim.services.Players
	local player = make("Player", { Name = name, DisplayName = name, UserId = userId }, Players)
	Players.LocalPlayer = player
	Sim.player = player
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	make("PlayerScripts", { Name = "PlayerScripts" }, player)
	make("StarterGear", { Name = "StarterGear" }, player)
	for k, v in pairs(attrs or {}) do
		player:SetAttribute(k, v)
	end
	local char = make("Model", { Name = name })
	local hrp = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position), Anchored = false, CanCollide = false })
	hrp.Parent = char
	char.PrimaryPart = hrp
	make("MeshPart", { Name = "Head", Size = Vector3.new(1.2, 1, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) }, char)
	make("Humanoid", { Name = "Humanoid" }, char)
	char.Parent = workspace
	player.Character = char
	return player
end

function Sim.rootPart()
	local player = Sim.player
	local char = player and player.__p.Character
	return char and findChild(char, "HumanoidRootPart")
end

---------------------------------------------------------------------------
-- ProximityPrompt engine
-- Every frame (after scripts moved the character) it shows only the CLOSEST enabled
-- prompt within MaxActivationDistance of the HumanoidRootPart (Exclusivity OnePerButton,
-- all prompts here use E). InputHoldBegin only works on the shown prompt; the prompt
-- triggers once it has been held for HoldDuration while still shown.
---------------------------------------------------------------------------
PromptEngine = { shown = nil, hold = nil }
Sim.PromptEngine = PromptEngine

local function promptWorldPos(prompt)
	local parent = prompt.__p.Parent
	if not parent then
		return nil
	end
	if parent.__cls.isa.Attachment then
		return parent.WorldPosition
	elseif parent.__cls.isa.BasePart then
		local c = parent.__p.CFrame
		return v3(c.x, c.y, c.z)
	end
	return nil -- prompts under Models/Folders are never shown by the engine
end
Sim.promptWorldPos = promptWorldPos

local function promptLabel(prompt)
	return fmt("%q prompt at %s", prompt.__p.ActionText, fullName(prompt.__p.Parent or prompt))
end
Sim.promptLabel = promptLabel

local function endHold(prompt, why)
	local h = PromptEngine.hold
	if not h or h.prompt ~= prompt then
		return
	end
	PromptEngine.hold = nil
	local PPS = Sim.services.ProximityPromptService
	fireEvent(prompt, "PromptButtonHoldEnded", Sim.player)
	fireEvent(PPS, "PromptButtonHoldEnded", prompt, Sim.player)
	if h.triggered then
		fireEvent(prompt, "TriggerEnded", Sim.player)
		fireEvent(PPS, "PromptTriggerEnded", prompt, Sim.player)
	elseif why ~= "released" then
		Sim.log("PROMPT", "hold cancelled (" .. why .. ") on " .. promptLabel(prompt))
	end
end

local function trigger(prompt, how)
	local h = PromptEngine.hold
	if h and h.prompt == prompt then
		h.triggered = true
	end
	local PPS = Sim.services.ProximityPromptService
	Sim.log("PROMPT", "Triggered (" .. how .. ") " .. promptLabel(prompt))
	fireEvent(prompt, "Triggered", Sim.player)
	fireEvent(PPS, "PromptTriggered", prompt, Sim.player)
	local root = Sim.rootPart()
	local rootPos = root and root.Position
	Net.push(Sim.now + Net.up, function()
		if Sim.Server and Sim.Server.onPromptTriggered then
			Sim.Server.onPromptTriggered(prompt, how, rootPos)
		end
	end)
end
PromptEngine.trigger = trigger

local function setShown(new)
	local old = PromptEngine.shown
	if old == new then
		return
	end
	local PPS = Sim.services.ProximityPromptService
	if old then
		endHold(old, "prompt hidden")
		PromptEngine.shown = nil
		fireEvent(old, "PromptHidden")
		fireEvent(PPS, "PromptHidden", old)
	end
	PromptEngine.shown = new
	if new then
		fireEvent(new, "PromptShown", Enum.ProximityPromptInputType.Keyboard)
		fireEvent(PPS, "PromptShown", new, Enum.ProximityPromptInputType.Keyboard)
	end
end

function PromptEngine.step()
	-- prune destroyed prompts
	for i = #Prompts, 1, -1 do
		if Prompts[i].__destroyed then
			table.remove(Prompts, i)
		end
	end
	local root = Sim.rootPart()
	local PPS = Sim.services.ProximityPromptService
	local best, bestD
	if root and PPS.__p.Enabled and not Sim.config.promptsNeverShow then
		local c = root.__p.CFrame
		local rp = v3(c.x, c.y, c.z)
		for _, prompt in ipairs(Prompts) do
			local p = prompt.__p
			if p.Enabled and isDescendantOf(prompt, workspace) then
				local pos = promptWorldPos(prompt)
				if pos then
					local d = (pos - rp).Magnitude
					if d <= p.MaxActivationDistance and (not bestD or d < bestD) then
						best, bestD = prompt, d
					end
				end
			end
		end
	end
	setShown(best)
	local h = PromptEngine.hold
	if h and not h.triggered and h.prompt == PromptEngine.shown and Sim.now - h.t0 >= h.prompt.__p.HoldDuration - 1e-9 then
		trigger(h.prompt, "hold")
	end
end

function PromptEngine.holdBegin(prompt)
	Sim.count("inputHoldBegin")
	if PromptEngine.shown ~= prompt then
		Sim.count("inputHoldBeginIgnored")
		Sim.log("PROMPT", "InputHoldBegin ignored, not the shown prompt: " .. promptLabel(prompt))
		return
	end
	if PromptEngine.hold then
		endHold(PromptEngine.hold.prompt, "new hold started")
	end
	PromptEngine.hold = { prompt = prompt, t0 = Sim.now, triggered = false }
	local PPS = Sim.services.ProximityPromptService
	fireEvent(prompt, "PromptButtonHoldBegan", Sim.player)
	fireEvent(PPS, "PromptButtonHoldBegan", prompt, Sim.player)
	if prompt.__p.HoldDuration <= 0 then
		trigger(prompt, "press")
	end
end

function PromptEngine.holdEnd(prompt)
	local h = PromptEngine.hold
	if not h or h.prompt ~= prompt then
		return
	end
	if not h.triggered and PromptEngine.shown == prompt and Sim.now - h.t0 >= prompt.__p.HoldDuration - 1e-9 then
		trigger(prompt, "hold")
	end
	endHold(prompt, "released")
end

-- Executor-style fireproximityprompt (only installed when a scenario asks for it):
-- fires the trigger directly, like the native implementations do. The server still
-- validates the distance.
function Sim.installFireProximityPrompt()
	fireproximityprompt = function(prompt)
		if not (isInstance(prompt) and prompt.__cls.isa.ProximityPrompt) then
			error("fireproximityprompt: ProximityPrompt expected", 2)
		end
		Sim.count("fireproximityprompt")
		Sim.log("PROMPT", "fireproximityprompt(" .. promptLabel(prompt) .. ")")
		if not prompt.__p.Enabled then
			return
		end
		PromptEngine.hold = nil
		trigger(prompt, "fireproximityprompt")
	end
end

---------------------------------------------------------------------------
-- Frame stepper
---------------------------------------------------------------------------
Sim.counters = {}
function Sim.count(name, n)
	Sim.counters[name] = (Sim.counters[name] or 0) + (n or 1)
end

-- Humanoid:MoveTo walking: WalkSpeed toward the target on the ground, gives up
-- after 8 s like Roblox; walls are enforced by the sim server (Sim.obstacles)
Sim.moveTargets = setmetatable({}, { __mode = "k" })
local WalkRay
local function walkStep(dt)
	for hum, move in pairs(Sim.moveTargets) do
		local char = hum.Parent
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or root.Anchored then
			Sim.moveTargets[hum] = nil
		else
			local pos = root.Position
			local flat = Vector3.new(move.pos.X - pos.X, 0, move.pos.Z - pos.Z)
			local d = flat.Magnitude
			if d <= 0.3 then
				Sim.moveTargets[hum] = nil
				fireEvent(hum, "MoveToFinished", true)
			elseif Sim.now - move.t > 8 then
				Sim.moveTargets[hum] = nil
				fireEvent(hum, "MoveToFinished", false)
			else
				local stepLen = math.min(d, hum.WalkSpeed * dt)
				local nextPos = pos + flat.Unit * stepLen
				WalkRay = WalkRay or RaycastParams.new()
				WalkRay.FilterType = Enum.RaycastFilterType.Exclude
				WalkRay.FilterDescendantsInstances = { char }
				-- a Humanoid steps up about 3 studs, 7.5 with a jump; anything
				-- taller blocks it like a wall
				local lift = root.Size.Y / 2 + hum.HipHeight
				local feet = pos.Y - lift
				local climb = if hum.Jump then 7.5 else 3
				local hit = workspace:Raycast(Vector3.new(nextPos.X, feet + climb + 0.1, nextPos.Z), Vector3.new(0, -80, 0), WalkRay)
				local y = if hit then hit.Position.Y + lift else pos.Y
				hum.Jump = false
				root.CFrame = CFrame.new(nextPos.X, y, nextPos.Z) * root.CFrame.Rotation
			end
		end
	end
end

-- PathfindingService: grid A* (4 stud cells) around Sim.obstacles, the same
-- rectangles the sim server uses as walls
Sim.obstacles = {}
local function obstacleAt(x, z, pad)
	for _, o in ipairs(Sim.obstacles) do
		if x > o.x1 - pad and x < o.x2 + pad and z > o.z1 - pad and z < o.z2 + pad then
			return o
		end
	end
	return nil
end
Sim.obstacleAt = obstacleAt

local function segmentClear(a, b, pad)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local n = math.max(1, math.ceil(d.Magnitude))
	for i = 0, n do
		local p = a + d * (i / n)
		if obstacleAt(p.X, p.Z, pad) then
			return false
		end
	end
	return true
end

function Sim.findPath(from, to, radius)
	local pad = (radius or 2) + 0.5
	if obstacleAt(to.X, to.Z, pad) then
		return nil, "FailFinishNotEmpty"
	end
	if segmentClear(from, to, pad) then
		return { from, to }
	end
	local cell = 4
	local minX, maxX = math.min(from.X, to.X) - 80, math.max(from.X, to.X) + 80
	local minZ, maxZ = math.min(from.Z, to.Z) - 80, math.max(from.Z, to.Z) + 80
	local nx, nz = math.ceil((maxX - minX) / cell) + 1, math.ceil((maxZ - minZ) / cell) + 1
	if nx * nz > 250000 then
		return nil, "NoPath"
	end
	local function center(i, j)
		return minX + i * cell, minZ + j * cell
	end
	local function cellOf(x, z)
		return math.clamp(math.floor((x - minX) / cell + 0.5), 0, nx - 1), math.clamp(math.floor((z - minZ) / cell + 0.5), 0, nz - 1)
	end
	local si, sj = cellOf(from.X, from.Z)
	local gi, gj = cellOf(to.X, to.Z)
	local function key(i, j)
		return i * 100000 + j
	end
	local blockedCache = {}
	local function blocked(i, j)
		local k = key(i, j)
		local b = blockedCache[k]
		if b == nil then
			local x, z = center(i, j)
			b = obstacleAt(x, z, pad) ~= nil
			blockedCache[k] = b
		end
		return b
	end
	local heap, gScore, came, closed = {}, {}, {}, {}
	local function push(item)
		table.insert(heap, item)
		local c = #heap
		while c > 1 do
			local parent = c // 2
			if heap[parent].f <= heap[c].f then
				break
			end
			heap[parent], heap[c] = heap[c], heap[parent]
			c = parent
		end
	end
	local function pop()
		local top = heap[1]
		local last = table.remove(heap)
		if #heap > 0 then
			heap[1] = last
			local c = 1
			while true do
				local l, r, smallest = c * 2, c * 2 + 1, c
				if heap[l] and heap[l].f < heap[smallest].f then
					smallest = l
				end
				if heap[r] and heap[r].f < heap[smallest].f then
					smallest = r
				end
				if smallest == c then
					break
				end
				heap[c], heap[smallest] = heap[smallest], heap[c]
				c = smallest
			end
		end
		return top
	end
	local function h(i, j)
		return math.sqrt((i - gi) ^ 2 + (j - gj) ^ 2)
	end
	gScore[key(si, sj)] = 0
	push({ i = si, j = sj, f = h(si, sj) })
	local found = false
	local expanded = 0
	while #heap > 0 do
		local node = pop()
		local k = key(node.i, node.j)
		if not closed[k] then
			closed[k] = true
			expanded += 1
			if node.i == gi and node.j == gj then
				found = true
				break
			end
			for di = -1, 1 do
				for dj = -1, 1 do
					if di ~= 0 or dj ~= 0 then
						local ni, nj = node.i + di, node.j + dj
						if ni >= 0 and ni < nx and nj >= 0 and nj < nz and not blocked(ni, nj) and not (di ~= 0 and dj ~= 0 and (blocked(node.i + di, node.j) or blocked(node.i, node.j + dj))) then
							local nk = key(ni, nj)
							local g = gScore[k] + (if di ~= 0 and dj ~= 0 then 1.4142 else 1)
							if not closed[nk] and (gScore[nk] == nil or g < gScore[nk]) then
								gScore[nk] = g
								came[nk] = k
								push({ i = ni, j = nj, f = g + h(ni, nj) })
							end
						end
					end
				end
			end
		end
	end
	Sim.count("pathExpanded", expanded)
	if not found then
		return nil, "NoPath"
	end
	local cells = {}
	local k = key(gi, gj)
	while k do
		table.insert(cells, 1, k)
		k = came[k]
	end
	local points = { from }
	for index = 2, #cells - 1 do
		local c = cells[index]
		local x, z = center(c // 100000, c % 100000)
		table.insert(points, Vector3.new(x, from.Y, z))
	end
	table.insert(points, to)
	-- string pulling: drop points that the previous kept point can see past
	local pulled = { points[1] }
	local anchor = 1
	for index = 2, #points do
		if index == #points or not segmentClear(points[anchor], points[index + 1], pad) then
			table.insert(pulled, points[index])
			anchor = index
		end
	end
	return pulled
end

function Sim.newPath(params)
	params = params or {}
	local path = { Status = Enum.PathStatus.NoPath, __waypoints = {} }
	function path:ComputeAsync(from, to)
		Sim.count("pathComputes")
		task.wait()
		local points, why = Sim.findPath(from, to, params.AgentRadius)
		if not points then
			self.Status = Enum.PathStatus[why or "NoPath"]
			self.__waypoints = {}
			return
		end
		local spacing = params.WaypointSpacing or 4
		local list = {}
		for index, point in ipairs(points) do
			if index > 1 then
				local prev = points[index - 1]
				local seg = Vector3.new(point.X - prev.X, 0, point.Z - prev.Z)
				local n = math.max(1, math.ceil(seg.Magnitude / spacing))
				for step = 1, n do
					local p = prev + seg * (step / n)
					table.insert(list, { Position = Vector3.new(p.X, point.Y, p.Z), Action = Enum.PathWaypointAction.Walk, Label = "" })
				end
			else
				table.insert(list, { Position = point, Action = Enum.PathWaypointAction.Walk, Label = "" })
			end
		end
		self.__waypoints = list
		self.Status = Enum.PathStatus.Success
	end
	function path:GetWaypoints()
		return table.clone(self.__waypoints)
	end
	return path
end

function Sim.step()
	Sim.now += Sim.dt
	Sim.frame += 1
	local RS = Sim.services.RunService
	if Sim.clientPin then
		Sim.clientPin()
	end
	fireEvent(RS, "RenderStepped", Sim.dt)
	fireEvent(RS, "PreRender", Sim.dt)
	runDeferred()
	runTimers()
	runDeferred()
	Net.deliver()
	runDeferred()
	-- physics: the treadmill lock runs every frame before the server sees the position
	if Sim.clientPin then
		Sim.clientPin()
	end
	fireEvent(RS, "Stepped", Sim.now - Sim.T0, Sim.dt)
	walkStep(Sim.dt)
	if Sim.serverStep then
		Sim.serverStep(Sim.dt)
	end
	PromptEngine.step()
	runDeferred()
	fireEvent(RS, "Heartbeat", Sim.dt)
	fireEvent(RS, "PostSimulation", Sim.dt)
	runDeferred()
end

function Sim.pendingTimers()
	return timers
end

---------------------------------------------------------------------------
-- Mock UI library (replaces the inlined Corvus/Obsidian library).
-- Elements register in Library.Options / Library.Toggles with their Default values,
-- exactly like the real library does; scenarios then override .Value.
---------------------------------------------------------------------------
local MockLibrary = { Options = {}, Toggles = {}, Labels = {}, Buttons = {}, Unloaded = false, IsMobile = false, Notifications = {}, Windows = {} }
Sim.Library = MockLibrary
__MockLibrary = MockLibrary

local function stubObject(name)
	return setmetatable({ __stub = name }, {
		__index = function(t, k)
			return function()
				return stubObject(name .. "." .. tostring(k))
			end
		end,
	})
end
Sim.stubObject = stubObject

local ElementMethods = {}
ElementMethods.__index = ElementMethods
function ElementMethods:SetValue(v)
	if self.Type == "Dropdown" and self.Multi then
		local map = {}
		if type(v) == "string" then
			map[v] = true
		else
			for k, active in pairs(v or {}) do
				if type(active) ~= "boolean" then
					map[active] = true
				elseif active then
					map[k] = true
				end
			end
		end
		v = map
	end
	self.Value = v
	for _, fn in ipairs(self.__changed) do
		task.spawn(fn, v)
	end
	if self.Callback then
		task.spawn(self.Callback, v)
	end
end
function ElementMethods:OnChanged(fn)
	table.insert(self.__changed, fn)
end
function ElementMethods:SetValues(values)
	self.Values = values
end
function ElementMethods:SetText(t)
	self.Text = t
end
function ElementMethods:SetVisible(v)
	self.Visible = v
end
function ElementMethods:SetDisabled(v)
	self.Disabled = v
end
function ElementMethods:AddKeyPicker(idx, info)
	local e = setmetatable({ Type = "KeyPicker", Value = info and info.Default, __changed = {} }, ElementMethods)
	MockLibrary.Options[idx] = e
	return self
end
function ElementMethods:AddColorPicker(idx, info)
	local e = setmetatable({ Type = "ColorPicker", Value = info and info.Default, __changed = {} }, ElementMethods)
	MockLibrary.Options[idx] = e
	return self
end
function ElementMethods:GetActiveValues()
	local n = 0
	for _ in pairs(type(self.Value) == "table" and self.Value or {}) do
		n += 1
	end
	return n
end

local function resolveDropdownDefault(info)
	local values = info.Values or {}
	local default = info.Default
	local function exists(v)
		for _, x in ipairs(values) do
			if x == v then
				return true
			end
		end
		return false
	end
	local resolved = {}
	if type(default) == "string" then
		if exists(default) then
			table.insert(resolved, default)
		end
	elseif type(default) == "table" then
		for _, v in ipairs(default) do
			if exists(v) then
				table.insert(resolved, v)
			end
		end
	elseif type(default) == "number" and values[default] ~= nil then
		table.insert(resolved, values[default])
	end
	if info.Multi then
		local map = {}
		for _, v in ipairs(resolved) do
			map[v] = true
		end
		return map
	end
	return resolved[1]
end

local GroupboxMethods = {}
local function newGroupbox(tab, name)
	local gb = setmetatable({ Name = name, Tab = tab, BoxHolder = { LayoutOrder = 0, Parent = nil, Visible = true }, Elements = {} }, {
		__index = function(t, k)
			local m = GroupboxMethods[k]
			if m then
				return m
			end
			-- unknown UI element types: accept and return a stub so layout code never breaks
			return function()
				return stubObject("Groupbox." .. tostring(k))
			end
		end,
	})
	return gb
end
function GroupboxMethods:AddToggle(idx, info)
	info = info or {}
	local e = setmetatable({ Type = "Toggle", Idx = idx, Text = info.Text, Value = info.Default == true, Default = info.Default == true, Callback = info.Callback, __changed = {}, Groupbox = self.Name }, ElementMethods)
	MockLibrary.Toggles[idx] = e
	table.insert(self.Elements, e)
	return e
end
GroupboxMethods.AddCheckbox = GroupboxMethods.AddToggle
function GroupboxMethods:AddDropdown(idx, info)
	info = info or {}
	local e = setmetatable({ Type = "Dropdown", Idx = idx, Text = info.Text, Multi = info.Multi == true, Values = info.Values or {}, Callback = info.Callback, __changed = {}, Groupbox = self.Name }, ElementMethods)
	e.Value = resolveDropdownDefault(info)
	e.Default = deepcopy(e.Value)
	MockLibrary.Options[idx] = e
	table.insert(self.Elements, e)
	return e
end
function GroupboxMethods:AddSlider(idx, info)
	info = info or {}
	local e = setmetatable({ Type = "Slider", Idx = idx, Text = info.Text, Value = info.Default, Default = info.Default, Min = info.Min, Max = info.Max, Rounding = info.Rounding, Callback = info.Callback, __changed = {}, Groupbox = self.Name }, ElementMethods)
	MockLibrary.Options[idx] = e
	table.insert(self.Elements, e)
	return e
end
function GroupboxMethods:AddInput(idx, info)
	info = info or {}
	local e = setmetatable({ Type = "Input", Idx = idx, Text = info.Text, Value = info.Default or "", Callback = info.Callback, __changed = {}, Groupbox = self.Name }, ElementMethods)
	MockLibrary.Options[idx] = e
	return e
end
function GroupboxMethods:AddLabel(a, b)
	local text = type(a) == "table" and a.Text or a
	local label = setmetatable({ Type = "Label", Text = text, History = {}, Groupbox = self.Name, __changed = {} }, ElementMethods)
	function label:SetText(t)
		self.Text = t
	end
	table.insert(MockLibrary.Labels, label)
	table.insert(self.Elements, label)
	if self.Name == "Status" and not Sim.statusLabel then
		Sim.statusLabel = label
	end
	return label
end
-- data widgets (Pets Universe analytics): they keep the last data for checks
MockLibrary.Widgets = {}
local function dataWidget(kind, name, info)
	local w = { Type = kind, Info = info or {}, Data = nil, Tiles = {}, Scope = info and info.Scopes and info.Scopes[1] or nil, Metric = info and info.Metric, Range = info and info.Range, SetCount = 0 }
	function w:SetData(data)
		self.Data = data
		self.SetCount += 1
	end
	function w:SetTile(id, data)
		self.Tiles[id] = data
		self.SetCount += 1
	end
	function w:SetVisible() end
	function w:SetValue(v)
		self.Value = v
	end
	function w:SetText(t)
		self.Text = t
	end
	function w:SetProgress(p)
		self.Progress = p
	end
	MockLibrary.Widgets[name or (kind .. #MockLibrary.Labels)] = w
	return w
end
function GroupboxMethods:AddStat(a, b)
	local info = type(a) == "table" and a or b or {}
	return dataWidget("Stat", (info.Text or "Stat") .. "@" .. self.Name, info)
end
function GroupboxMethods:AddStatTiles(info)
	return dataWidget("StatTiles", "StatTiles@" .. self.Name, info)
end
function GroupboxMethods:AddChart(idx, info)
	return dataWidget("Chart", idx, info)
end
function GroupboxMethods:AddBarChart(info)
	return dataWidget("BarChart", "BarChart@" .. self.Name, info)
end
function GroupboxMethods:AddFeed(idx, info)
	return dataWidget("Feed", idx, info)
end
function GroupboxMethods:AddGoals(idx, info)
	return dataWidget("Goals", idx, info)
end

function GroupboxMethods:AddButton(a, b)
	local info = type(a) == "table" and a or { Text = a, Func = b }
	local button = setmetatable({ Type = "Button", Text = info.Text, Func = info.Func or info.Callback, __changed = {} }, ElementMethods)
	function button:AddButton(...)
		return GroupboxMethods.AddButton(self, ...)
	end
	MockLibrary.Buttons[info.Text or ("Button" .. #MockLibrary.Buttons)] = button
	return button
end
function GroupboxMethods:AddDivider()
	return nil
end
function GroupboxMethods:AddKeyPicker(idx, info)
	local e = setmetatable({ Type = "KeyPicker", Value = info and info.Default, __changed = {} }, ElementMethods)
	MockLibrary.Options[idx] = e
	return e
end
function GroupboxMethods:AddDependencyBox()
	return newGroupbox(self.Tab, self.Name .. ".Dependency")
end

local function newTab(window, name)
	local tab = { Name = name, Groupboxes = {}, Sides = { {}, {} }, Window = window }
	function tab:AddLeftGroupbox(n)
		local gb = newGroupbox(self, n)
		self.Groupboxes[n] = gb
		return gb
	end
	tab.AddRightGroupbox = tab.AddLeftGroupbox
	function tab:AddGroupbox(info)
		return self:AddLeftGroupbox(type(info) == "table" and info.Name or info)
	end
	function tab:AddLeftTabbox(n)
		local owner = self
		return {
			AddTab = function(_, tn)
				return owner:AddLeftGroupbox(tn)
			end,
		}
	end
	tab.AddRightTabbox = tab.AddLeftTabbox
	function tab:Show()
		self.Shown = true
	end
	function tab:Hide()
		self.Shown = false
	end
	function tab:UpdateWarningBox() end
	function tab:Resize() end
	return tab
end

function MockLibrary:CreateWindow(info)
	local window = { Info = info, Tabs = {} }
	function window:AddTab(a, icon)
		local name = type(a) == "table" and a.Name or a
		local tab = newTab(self, name)
		self.Tabs[name] = tab
		return tab
	end
	function window:AddInfoTab(i)
		local tab = self:AddTab("Info")
		tab:AddLeftGroupbox("Community")
		return tab
	end
	function window:AddMiscTab(i)
		return self:AddTab("Misc")
	end
	function window:AddSettingsTab(i)
		self.SettingsInfo = i
		return self:AddTab("Settings")
	end
	function window:AddKeyTab(i)
		return self:AddTab("Key")
	end
	function window:AddCommandsTab(i)
		return self:AddTab("Commands")
	end
	function window:AddRemoteSpyTab(i)
		return self:AddTab("Remote Spy")
	end
	for _, k in ipairs({ "SetFooter", "SetFooterLink", "ChangeTitle", "SetCompact", "ShowTabInfo", "HideTabInfo" }) do
		window[k] = function() end
	end
	table.insert(MockLibrary.Windows, window)
	return window
end

function MockLibrary:Notify(info, ...)
	local entry = type(info) == "table" and info or { Title = info, Description = select(1, ...) }
	table.insert(self.Notifications, entry)
	Sim.log("NOTIFY", tostring(entry.Title) .. ": " .. tostring(entry.Description or entry.Content))
	if entry.Title == "Corvus" and tostring(entry.Description):find("^Loaded") then
		Sim.scriptReady = true
	end
end
function MockLibrary:Unload()
	self.Unloaded = true
	for _, fn in ipairs(self.UnloadCallbacks or {}) do
		pcall(fn)
	end
end

-- console commands, quick bar and unload hooks (same shape as the real library)
MockLibrary.Commands = {}
MockLibrary.CommandOutput = {}
function MockLibrary:AddCommand(info)
	assert(type(info) == "table" and type(info.Name) == "string", "AddCommand expects a table with a Name")
	self.Commands[string.lower(info.Name)] = info
	for _, alias in ipairs(info.Aliases or {}) do
		self.Commands[string.lower(alias)] = self.Commands[string.lower(alias)] or info
	end
	return info
end
function MockLibrary:RunCommand(text)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	local name = string.lower(table.remove(words, 1) or "")
	local command = self.Commands[name]
	if not command then
		table.insert(self.CommandOutput, { text = text, ok = false, result = "unknown command" })
		return false
	end
	local ok, result = pcall(command.Callback, words, text)
	table.insert(self.CommandOutput, { text = text, ok = ok, result = result })
	Sim.log("COMMAND", text .. " -> " .. tostring(result))
	return ok, result
end
function MockLibrary:SetQuickBar(items)
	for _, item in ipairs(items) do
		assert(self.Toggles[item.Toggle], "quick bar toggle " .. tostring(item.Toggle) .. " does not exist")
	end
	self.QuickBarItems = items
end
function MockLibrary:OnUnload(fn)
	self.UnloadCallbacks = self.UnloadCallbacks or {}
	table.insert(self.UnloadCallbacks, fn)
end
function MockLibrary:GiveSignal(connection)
	return connection
end

local function addonStub(name)
	return setmetatable({}, {
		__index = function(t, k)
			return function() end
		end,
	})
end
__MockThemeManager = addonStub("ThemeManager")
__MockSaveManager = addonStub("SaveManager")

-- status hook injected into setStatus() by run_sftr.py (observation only)
-- Every change is recorded; a line is printed unless the same text was printed < 5 s ago
-- (keeps flickering statuses readable in the log).
local statusPrinted = {}
function __SimOnStatus(text)
	if Sim.status ~= text then
		Sim.status = text
		Sim.statusSince = Sim.now
		table.insert(Sim.statusHistory, { t = Sim.now - Sim.T0, text = text })
		local key = tostring(text)
		if not statusPrinted[key] or Sim.now - statusPrinted[key] >= 5 then
			statusPrinted[key] = Sim.now
			Sim.log("STATUS", fmt("%q", key))
		end
	end
end
