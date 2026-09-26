--!nocheck
-- Scenario runner: boots the script under test inside the simulated client, applies the
-- scenario's Toggles/Options, runs simulated time and evaluates checks.
-- Requires mock_roblox.luau and sftr_server.luau to be loaded first.

local fmt = string.format
local ARGS = __SIM_ARGS or {}

local Harness = { checks = {} }
Sim.Harness = Harness

function Scenario(def)
	Harness.def = def
end

---------------------------------------------------------------------------
-- main loop cycle tracking (the worker's `task.wait(0.25)` call site)
---------------------------------------------------------------------------
Sim.mainLoopCycles = 0
function Sim.onMainLoopCycle(co)
	Sim.mainThread = Sim.mainThread or co
	if co ~= Sim.mainThread then
		return
	end
	Sim.mainLoopCycles += 1
	if Sim.optionsAppliedAt then
		local gap = Sim.now - (Sim.lastMainCycle or Sim.now)
		if gap > (Sim.maxMainGap or 0) then
			Sim.maxMainGap = gap
			Sim.maxMainGapAt = Sim.elapsed()
		end
	end
	Sim.lastMainCycle = Sim.now
end

---------------------------------------------------------------------------
-- helpers for scenarios
---------------------------------------------------------------------------
function Sim.countTools(attr)
	local n = 0
	for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("Tool") and c:GetAttribute(attr) then
				n += 1
			end
		end
	end
	return n
end

function Sim.remotes(name)
	local out = {}
	for _, e in ipairs(Sim.remoteLog) do
		if e.name == name then
			table.insert(out, e)
		end
	end
	return out
end

function Sim.remotesAfterOptions()
	local out = {}
	for _, e in ipairs(Sim.remoteLog) do
		if e.t >= (Sim.optionsAppliedAt or Sim.T0) - Sim.T0 - 1e-6 then
			table.insert(out, e)
		end
	end
	return out
end

function Sim.statusSeen(pattern)
	for _, s in ipairs(Sim.statusHistory) do
		if tostring(s.text):find(pattern) then
			return true, s
		end
	end
	return false
end

function Sim.statusCount(pattern)
	local n = 0
	for _, s in ipairs(Sim.statusHistory) do
		if tostring(s.text):find(pattern) then
			n += 1
		end
	end
	return n
end

function Sim.at(seconds, fn)
	Harness.events = Harness.events or {}
	table.insert(Harness.events, { at = seconds, fn = fn, done = false })
end

function Sim.selectZones(ids)
	local map = {}
	for _, label in ipairs(Sim.Library.Options.StealZones.Values) do
		for _, id in ipairs(ids) do
			if label:sub(1, #id + 3) == id .. " - " then
				map[label] = true
			end
		end
	end
	Sim.Library.Options.StealZones.Value = map
	return map
end

function Sim.selectRarities(list)
	local map = {}
	for _, r in ipairs(list) do
		map[r] = true
	end
	Sim.Library.Options.StealRarities.Value = map
	return map
end

local function check(ok, description, detail)
	table.insert(Harness.checks, { ok = ok and true or false, description = description, detail = detail })
end

---------------------------------------------------------------------------
-- reporting
---------------------------------------------------------------------------
local function areaCounts(list)
	local counts, order = {}, {}
	for _, e in ipairs(list) do
		if not counts[e.area] then
			table.insert(order, e.area)
		end
		counts[e.area] = (counts[e.area] or 0) + 1
	end
	local parts = {}
	for _, a in ipairs(order) do
		table.insert(parts, a .. " x" .. counts[a])
	end
	return #parts > 0 and table.concat(parts, ", ") or "-"
end
Sim.areaCounts = areaCounts

local function progressLine()
	local root = Sim.rootPart()
	local p = root and root.Position
	local st = Sim.stats
	Sim.log("PROGRESS", fmt("status=%q pos=(%.0f, %.0f, %.0f) carrying=%s treadmill=%s steals=%d banked=%d caught=%d crateTools=%d itemTools=%d money=%d mainCycles=%d",
		tostring(Sim.status), p and p.X or 0, p and p.Y or 0, p and p.Z or 0,
		tostring(Sim.player:GetAttribute("CarryingStolen")), tostring(Sim.player:GetAttribute("OnTreadmill")),
		#st.steals, #st.banked, #st.caught, Sim.countTools("CrateUid"), Sim.countTools("ItemUid"), math.floor(Sim.Server.money), Sim.mainLoopCycles))
end

local function summary(def)
	local st = Sim.stats
	print("")
	print("==== SUMMARY " .. def.name .. " ====")
	print(fmt("simulated %.0f s after options were applied (%d frames in total)", Sim.now - (Sim.optionsAppliedAt or Sim.now), Sim.frame))
	print(fmt("steals: %d (%s) | banked: %d | guard caught: %d | snapbacks: teleport %d, speed %d", #st.steals, areaCounts(st.steals), #st.banked, #st.caught, st.snapTeleport, st.snapSpeed))
	print(fmt("placed: %d (rejected %d) | opened: %d | sold: %d batch(es) | placebest: %d | trail buys: %d, equips: %d | slot buys: %d | plot upgrades: %d | treadmill upgrades: %d | mounts: %d, dismounts: %d | index claims: %d",
		#st.placed, #st.placeRejected, #st.opened, #st.sold, st.placeBest, #st.trailBuys, #st.trailEquips, st.slotBuys, st.plotUpgrades, st.treadmillUpgrades, st.mounts, st.dismounts, st.indexClaims))
	print(fmt("main loop cycles: %d, longest gap between cycles: %.1f s (at t=%.1f)", Sim.mainLoopCycles, Sim.maxMainGap or 0, Sim.maxMainGapAt or 0))
	local counts, order = {}, {}
	for _, e in ipairs(Sim.remoteLog) do
		local key = e.kind .. " " .. e.name
		if not counts[key] then
			table.insert(order, key)
		end
		counts[key] = (counts[key] or 0) + 1
	end
	local parts = {}
	for _, k in ipairs(order) do
		table.insert(parts, k .. " x" .. counts[k])
	end
	print("remotes: " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
	-- condensed: a status seen among the last 3 entries is counted instead of repeated
	local entries = {}
	for _, s in ipairs(Sim.statusHistory) do
		local found = nil
		for i = #entries, math.max(1, #entries - 2), -1 do
			if entries[i].text == s.text then
				found = entries[i]
				break
			end
		end
		if found then
			found.n += 1
		else
			table.insert(entries, { t = s.t, text = s.text, n = 1 })
		end
	end
	local timeline = {}
	for _, e in ipairs(entries) do
		table.insert(timeline, fmt("%.0fs %q%s", e.t, e.text, e.n > 1 and (" x" .. e.n) or ""))
	end
	if #timeline > 40 then
		local head = { table.unpack(timeline, 1, 20) }
		table.insert(head, "... (" .. (#timeline - 40) .. " more) ...")
		for i = #timeline - 19, #timeline do
			table.insert(head, timeline[i])
		end
		timeline = head
	end
	print("status timeline: " .. table.concat(timeline, " -> "))
	print("final status: " .. fmt("%q", tostring(Sim.status)))
	if #st.placeRejected > 0 then
		print("place rejections: " .. Sim.describe(st.placeRejected))
	end
	if #st.promptRejected > 0 then
		print("prompt rejections: " .. Sim.describe(st.promptRejected))
	end
	if #Sim.notes > 0 then
		for _, n in ipairs(Sim.notes) do
			print(fmt("note @%.1fs: %s", n.t, n.msg))
		end
	end
	print("checks:")
	local allOk = true
	for _, c in ipairs(Harness.checks) do
		print(fmt("  %s  %s%s", c.ok and "PASS" or "FAIL", c.description, c.detail ~= nil and (" [" .. tostring(c.detail) .. "]") or ""))
		allOk = allOk and c.ok
	end
	local debugLog = __Files and __Files["Corvus_SFTR_log.txt"]
	if debugLog then
		print("---- script debug log (Corvus_SFTR_log.txt) ----")
		print(debugLog)
		print("---- end of script debug log ----")
	end
	print("RESULT " .. def.name .. ": " .. (allOk and "PASS" or "FAIL"))
end

---------------------------------------------------------------------------
-- run
---------------------------------------------------------------------------
function Sim.runScenario(source)
	local def = Harness.def or error("the scenario file did not call Scenario{...}")
	def.duration = def.duration or 60
	local stallLimit = def.stallLimit or 45
	print("==== SCENARIO " .. def.name .. " ====")
	if def.description then
		print(def.description)
	end
	Sim.Server.build(def.world or {})
	if def.setup then
		def.setup(Sim)
	end
	local fn, err = loadstring(source, "=" .. (ARGS.scriptName or "script"))
	if not fn then
		check(false, "script compiles", err)
		summary(def)
		return
	end
	Sim.scriptThread = coroutine.create(fn)
	Sim.resume(Sim.scriptThread)
	local bootDeadline = Sim.now + 60
	while coroutine.status(Sim.scriptThread) ~= "dead" and Sim.now < bootDeadline do
		Sim.step()
	end
	local bootFailed = false
	for _, w in ipairs(Sim.warnings) do
		if w:find("failed to start") or w:find("was not started") then
			bootFailed = true
		end
	end
	check(coroutine.status(Sim.scriptThread) == "dead" and Sim.scriptReady and not bootFailed, "script boots and builds its UI", fmt("%.1f s", Sim.elapsed()))
	if not Sim.scriptReady then
		summary(def)
		return
	end

	Sim.optionsAppliedAt = Sim.now
	if def.options then
		def.options(Sim.Library.Toggles, Sim.Library.Options, Sim)
	end
	local on = {}
	for idx, t in pairs(Sim.Library.Toggles) do
		if t.Value then
			table.insert(on, idx)
		end
	end
	table.sort(on)
	Sim.log("OPTIONS", "toggles on: " .. (#on > 0 and table.concat(on, ", ") or "none"))
	for _, idx in ipairs({ "StealZones", "StealRarities", "StealPriority", "TravelMode", "CarryMode", "SellMode", "SellInterval" }) do
		local o = Sim.Library.Options[idx]
		if o then
			local v = o.Value
			if type(v) == "table" then
				local keys = {}
				for k in pairs(v) do
					table.insert(keys, (tostring(k):match("^(%S+)")))
				end
				table.sort(keys)
				v = "{" .. table.concat(keys, ", ") .. "}"
			end
			Sim.log("OPTIONS", idx .. " = " .. tostring(v))
		end
	end

	Sim.lastMainCycle = Sim.now
	local startAt = Sim.now
	local endAt = Sim.now + def.duration
	local nextProgress = Sim.now + 10
	local stallReported = false
	while Sim.now < endAt do
		Sim.step()
		for _, ev in ipairs(Harness.events or {}) do
			if not ev.done and Sim.now - startAt >= ev.at then
				ev.done = true
				ev.fn(Sim)
			end
		end
		if Sim.now >= nextProgress then
			nextProgress += 10
			progressLine()
		end
		if not stallReported and Sim.now - (Sim.lastMainCycle or Sim.now) > stallLimit then
			stallReported = true
			local site = Sim.mainThread and Sim.threadSite[Sim.mainThread]
			local tb = Sim.mainThread and debug.traceback(Sim.mainThread, "main worker stack") or "main worker not found"
			Harness.stall = fmt("main loop made no progress for %.0f s; status %q; waiting at %s:%s since t=%.1f\n%s",
				Sim.now - Sim.lastMainCycle, tostring(Sim.status), site and site.src or "?", site and site.line or "?", site and (site.since - Sim.T0) or -1, tb)
			Sim.log("STALL", Harness.stall)
		end
	end
	progressLine()
	local openGap = Sim.now - (Sim.lastMainCycle or Sim.now)
	if openGap > (Sim.maxMainGap or 0) then
		Sim.maxMainGap = openGap
		Sim.maxMainGapAt = Sim.elapsed()
	end

	-- common checks
	check(#Sim.errors == 0, "no uncaught Lua errors in any thread", #Sim.errors > 0 and Sim.errors[1] or nil)
	local errStatus = nil
	for _, s in ipairs(Sim.statusHistory) do
		if tostring(s.text):find("^Error:") then
			errStatus = s.text
			break
		end
	end
	check(errStatus == nil, "main loop never reported \"Error: ...\"", errStatus)
	check(Harness.stall == nil, fmt("no deadlock: main loop cycles at least every %d s", stallLimit), Harness.stall or fmt("longest gap %.1f s", Sim.maxMainGap or 0))
	local unhandled = {}
	for name, n in pairs(Sim.stats.unhandled) do
		table.insert(unhandled, name .. " x" .. n)
	end
	table.sort(unhandled)
	check(#unhandled == 0, "every remote the script fired is one the game handles", #unhandled > 0 and table.concat(unhandled, ", ") or nil)
	local unsendable = nil
	for _, n in ipairs(Sim.notes) do
		if n.msg:find("cannot be sent over the network") then
			unsendable = n.msg
		end
	end
	check(unsendable == nil, "remote arguments are serializable", unsendable)

	if def.checks then
		local ok, e = pcall(def.checks, Sim, check)
		if not ok then
			check(false, "scenario checks ran without error", e)
		end
	end
	summary(def)
end
