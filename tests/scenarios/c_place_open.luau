-- c. Auto Place + Auto Open with crate tools already in the backpack.
-- The plot floor (rotated 90 degrees) already has an ItemStand where the script's first
-- grid spot is, and a crate that is still appraising.
local CRATES = 4
Scenario {
	name = "c_place_open",
	description = "Auto Place + Auto Open, 4 crate tools in the backpack, rf_CRATE_TIMERS present (the game's Crates panel). "
		.. "Crates must be placed with re_PLACE_AT on free spots (server-validated) and opened once ready.",
	duration = 90,
	world = {
		appraiseTime = 20,
		backpack = {
			{ kind = "crate", area = "Grandpa", token = "Epic" },
			{ kind = "crate", area = "Jeweler", token = "Rare" },
			{ kind = "crate", area = "Archeologist", token = "Common" },
			{ kind = "crate", area = "MafiaBoss", token = "Rare" },
		},
		floor = {
			{ kind = "stand", x = -15, z = -15, value = 9000 },
			{ kind = "crate", x = 10, z = 10, tier = "Rare", readyIn = 35 },
		},
	},
	options = function(Toggles, Options, Sim)
		Toggles.AutoPlace.Value = true
		Toggles.AutoOpen.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.placed == CRATES, "all crate tools placed with re_PLACE_AT", #st.placed)
		check(#st.placeRejected == 0, "the server accepted every placement", Sim.describe(st.placeRejected))
		check(Sim.countTools("CrateUid") == 0, "no crate tools left in the backpack", Sim.countTools("CrateUid"))
		check(#st.opened >= CRATES + 1, "placed crates and the pre-existing one are opened once ready", #st.opened)
		local early = 0
		for _, e in ipairs(Sim.remotes("rf_CRATE_TIMERS")) do
			if e.args[1] == "open" and e.result == "false" then
				early += 1
			end
		end
		check(early == 0, "never asks the server to open a crate that is not ready", early)
		check(Sim.countTools("ItemUid") >= CRATES + 1, "opened crates became item tools", Sim.countTools("ItemUid"))
		local badArgs = 0
		for _, e in ipairs(Sim.remotes("re_PLACE_AT")) do
			if typeof(e.args[1]) ~= "Vector3" or type(e.args[2]) ~= "number" then
				badArgs += 1
			end
		end
		check(badArgs == 0, "re_PLACE_AT args are (Vector3, number)", badArgs)
	end,
}
