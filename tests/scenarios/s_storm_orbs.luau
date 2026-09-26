-- s. Storm orbs: the storm is on, the orb layout comes from StormConfig.computeLayout (the sim's
-- server uses a line-by-line port of the dump's version). The hub must run from orb to orb and
-- every collect must be one the server accepts (within MAGNET_RADIUS).
Scenario {
	name = "s_storm_orbs",
	description = "Auto Collect Storm Orbs during an active storm for 90 s: many orbs collected, StormPoints rise, collects are in range.",
	duration = 90,
	world = { storm = true, stormSeconds = 400 },
	options = function(Toggles, Options, Sim)
		Toggles.AutoOrbs.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.orbs >= 40, "collected at least 40 orbs in 90 s", #st.orbs)
		local points = tonumber(Sim.player:GetAttribute("StormPoints")) or 0
		check(points >= 60, "StormPoints went up", points)
		local far = 0
		for _, r in ipairs(st.orbRejected) do
			if tostring(r.why):find("far") then
				far += 1
			end
		end
		check(far <= 2, "(almost) no out-of-range collects", far)
		check(Sim.statusSeen("Collecting storm orbs"), "status showed Collecting storm orbs")
	end,
}
