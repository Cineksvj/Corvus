-- c2. Same as c, but without rf_CRATE_TIMERS, so Auto Open must walk to each ready crate and
-- hold its "Open Crate" prompt (the engine only shows the closest prompt).
local CRATES = 4
Scenario {
	name = "c2_open_by_prompt",
	description = "Auto Place + Auto Open without rf_CRATE_TIMERS: crates are opened through their 'Open Crate' ProximityPrompt "
		.. "once it becomes enabled.",
	duration = 90,
	world = {
		appraiseTime = 20,
		noCrateTimers = true,
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
		check(#st.placed == CRATES, "all crate tools placed", #st.placed)
		check(#st.placeRejected == 0, "the server accepted every placement", Sim.describe(st.placeRejected))
		check(#st.opened >= CRATES + 1, "every crate opened through its prompt once ready", #st.opened)
		local viaPrompt = 0
		for _, o in ipairs(st.opened) do
			if o.how == "hold" then
				viaPrompt += 1
			end
		end
		check(viaPrompt == #st.opened, "opened by holding the prompt like a player", viaPrompt)
		check((Sim.counters.inputHoldBeginIgnored or 0) == 0, "never held a prompt the engine was not showing", Sim.counters.inputHoldBeginIgnored or 0)
		check(#st.promptRejected == 0, "server accepted every prompt trigger", Sim.describe(st.promptRejected))
	end,
}
