-- w3. "It keeps running into walls": the Grandpa crates sit inside a house that is open only on
-- the west side, with its east wall facing the safe zone. A straight run hits the wall; Safe mode
-- must plan the way around (PathfindingService) and walk it with the Humanoid.
Scenario {
	name = "w3_walls_around_crates",
	description = "Grandpa crates inside a U-shaped house open to the west: every trip walks around the walls, no wall hits, crates banked.",
	duration = 90,
	world = {
		walls = {
			{ name = "house north", x1 = 2362, x2 = 2396, z1 = -965, z2 = -963 },
			{ name = "house south", x1 = 2362, x2 = 2396, z1 = -997, z2 = -995 },
			{ name = "house east", x1 = 2394, x2 = 2396, z1 = -997, z2 = -963 },
		},
	},
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.banked >= 3, "banked at least 3 crates", #st.banked)
		check(st.wallHits == 0, "never walked into a wall", st.wallHits)
		check((Sim.counters.MoveTo or 0) > 0, "walked with Humanoid:MoveTo", Sim.counters.MoveTo)
		check((Sim.counters.pathComputes or 0) > 0, "planned paths with PathfindingService", Sim.counters.pathComputes)
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
	end,
}
