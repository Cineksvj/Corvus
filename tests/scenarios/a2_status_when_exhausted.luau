-- a2. After every Grandpa crate is gone, the Status label should tell the user why nothing happens.
Scenario {
	name = "a2_status_when_exhausted",
	description = "Auto Steal (Grandpa) until the zone is empty; the Status label (refreshed every 0.5 s) must then show "
		.. "'No crate matches your filters' with the arena reset countdown, not 'Idle'.",
	duration = 40,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		check(#Sim.stats.banked == 5, "all 5 Grandpa crates banked", #Sim.stats.banked)
		local shown = Sim.statusLabel and Sim.statusLabel.Text
		check(type(shown) == "string" and shown:find("^No crate matches your filters") ~= nil, "Status label explains why Auto Steal is waiting", shown)
		check(type(shown) == "string" and shown:find("arena resets in %d+m %d%ds") ~= nil, "Status label shows the arena reset countdown", shown)
	end,
}
