-- b2. A far zone: SpeedLevel 2.5M allows MuseumOwner (X ~760, ~1680 studs from the safe line).
-- Carry mode "Teleport" exercises the teleport-then-run fallback. The trip home takes ~18 s.
Scenario {
	name = "b2_far_zone_teleport_carry",
	description = "Auto Steal, ALL zones, SmartZones ON, SpeedLevel 2,500,000 (MuseumOwner allowed), Carry Crate Home = Teleport. "
		.. "Teleports while carrying must be refused by the server; the script must fall back to running and bank the crate "
		.. "without aborting the long trip.",
	duration = 150,
	world = { attrs = { SpeedLevel = 2500000 } },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Toggles.SmartZones.Value = true
		local all = {}
		for _, label in ipairs(Options.StealZones.Values) do
			all[label] = true
		end
		Options.StealZones.Value = all
		Options.CarryMode.Value = "Teleport"
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(st.steals[1] and st.steals[1].area == "MuseumOwner", "first steal is from MuseumOwner", st.steals[1] and st.steals[1].area)
		check(#st.banked >= 2, "at least 2 far-zone crates banked", #st.banked)
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
		check(st.snapTeleport > 0, "the server refused the carry teleport (expected)", st.snapTeleport)
		local seen, s = Sim.statusSeen("Could not reach")
		check(not seen, "long trip home is not aborted half way ('Could not reach the safe zone')", s and fmt("%s at t=%.1f", s.text, s.t))
		check((st.drops or 0) == 0, "no crate dropped", st.drops or 0)
	end,
}
