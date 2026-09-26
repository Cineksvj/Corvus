-- a2. After every Grandpa crate is gone, the Status label should tell the user why nothing happens.
Scenario {
	name = "a2_status_when_exhausted",
	description = "Auto Steal (Grandpa) until the zone is empty; the Status label (refreshed every 0.5 s) must then show "
		.. "'No crate matches your filters', not 'Idle'.",
	duration = 40,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		check(#Sim.stats.banked == 5, "all 5 Grandpa crates banked", #Sim.stats.banked)
		local shown = Sim.statusLabel and Sim.statusLabel.Text
		check(shown == "No crate matches your filters", "Status label explains why Auto Steal is waiting", shown)
	end,
}
