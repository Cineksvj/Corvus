-- i. Console commands (Commands tab): the Pets Universe style commands drive the same toggles
-- and options as the UI, and the quick bar only points at toggles that exist.
Scenario {
	name = "i_commands",
	description = "Runs steal/zones/farm/status/stop/sell through Library:RunCommand and checks the toggles and options they set.",
	duration = 20,
	options = function(Toggles, Options, Sim)
		local L = Sim.Library
		Sim.cmd = {}
		Sim.cmd.steal = { L:RunCommand("steal on") }
		Sim.cmd.stealOn = Toggles.AutoSteal.Value
		Sim.cmd.zones = { L:RunCommand("zones escape") }
		local count = 0
		for _, v in pairs(Options.StealZones.Value) do
			if v then
				count += 1
			end
		end
		Sim.cmd.zoneCount = count
		Sim.cmd.zoneTotal = #Options.StealZones.Values
		Sim.cmd.smart = Toggles.SmartZones.Value
		Sim.cmd.grandpa = { L:RunCommand("zones grandpa") }
		Sim.cmd.status = { L:RunCommand("status") }
		Sim.cmd.farm = { L:RunCommand("farm on") }
		Sim.cmd.farmOn = Toggles.AutoPlace.Value and Toggles.AutoOpen.Value and Toggles.AutoEquipBest.Value
		Sim.cmd.stop = { L:RunCommand("stop") }
		local anyOn = false
		for _, name in ipairs({ "AutoSteal", "AutoSell", "AutoPlace", "AutoOpen", "AutoEquipBest", "AutoTreadmill", "AutoIndex", "AutoTrails" }) do
			anyOn = anyOn or Toggles[name].Value
		end
		Sim.cmd.anyOnAfterStop = anyOn
		Sim.cmd.alias = { L:RunCommand("tm") }
		Sim.cmd.tmOn = Toggles.AutoTreadmill.Value
		L:RunCommand("tm off")
	end,
	checks = function(Sim, check)
		local c = Sim.cmd
		local L = Sim.Library
		check(L.Commands.steal and L.Commands.sell and L.Commands.zones and L.Commands.stop and L.Commands.safe and L.Commands.plot, "game commands registered")
		check(c.steal[1] and c.stealOn == true, "steal on turns Auto Steal on", c.steal[2])
		check(c.zones[1] and c.zoneCount == c.zoneTotal and c.smart == true, "zones escape selects every zone and Only Zones I Can Escape", string.format("%d/%d smart=%s", c.zoneCount, c.zoneTotal, tostring(c.smart)))
		check(c.grandpa[1] and tostring(c.grandpa[2]):find("1 zone"), "zones grandpa picks only Grandpa", c.grandpa[2])
		check(c.status[1] and type(c.status[2]) == "string" and c.status[2]:find("%$"), "status returns text", c.status[2])
		check(c.farm[1] and c.farmOn, "farm on turns the farm toggles on", c.farm[2])
		check(c.stop[1] and not c.anyOnAfterStop, "stop turns everything off", c.stop[2])
		check(c.alias[1] and c.tmOn == true, "alias tm toggles Auto Treadmill", c.alias[2])
		check(type(L.QuickBarItems) == "table" and #L.QuickBarItems >= 6, "quick bar set", L.QuickBarItems and #L.QuickBarItems)
		check(L.Toggles.KeepOnTeleport ~= nil, "Keep after teleport toggle exists")
	end,
}
