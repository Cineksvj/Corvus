-- s3. Thunder Machine: 1,600 storm points and two crates in the backpack. Auto Charge Crates must
-- walk to the machine, ask for the state and charge the best crate with the most points allowed (1,500).
Scenario {
	name = "s3_thunder_charge",
	description = "Auto Charge Crates with 1600 StormPoints, an Epic and a Common crate: one mutate on the Epic crate for 1500 points.",
	duration = 40,
	world = {
		stormPoints = 1600,
		backpack = {
			{ kind = "crate", area = "Grandpa", token = "Common" },
			{ kind = "crate", area = "Grandpa", token = "Epic" },
		},
	},
	options = function(Toggles, Options, Sim)
		Toggles.AutoThunder.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.charges == 1, "exactly one accepted charge", #st.charges)
		check(#st.chargeRejected == 0, "no rejected charges", Sim.describe(st.chargeRejected))
		local c = st.charges[1]
		check(c and c.spend == 1500, "spent 1500 points (MAX_CHARGE)", c and c.spend)
		local epic
		for _, t in ipairs(Sim.player.Backpack:GetChildren()) do
			if t:GetAttribute("CrateTier") == "Epic" then
				epic = t:GetAttribute("CrateUid")
			end
		end
		check(c and c.uid == epic, "charged the Epic crate", c and c.uid)
		check((tonumber(Sim.player:GetAttribute("StormPoints")) or 0) == 100, "100 points left", Sim.player:GetAttribute("StormPoints"))
	end,
}
