-- w2. Live log 5: while Auto Steal was running to a far crate the user pressed "Claim Free Gift".
-- Both trips moved the character at once and it stood still for 30 s. A button must take over,
-- finish, and then the farm must carry on.
Scenario {
	name = "w2_button_during_farm",
	description = "Auto Steal to MafiaBoss, press Claim Free Gift at t=4 s: the gift is claimed, the farm then steals again, no long stall.",
	duration = 90,
	world = { inGroup = false },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Sim.selectZones({ "MafiaBoss" })
		-- joins the group mid-trip, then presses the button while the farm is running
		Sim.at(3, function()
			Sim.config.inGroup = true
		end)
		Sim.at(4, function()
			Sim.Library.Buttons["Claim Free Gift / Join Group"].Func()
		end)
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(st.freeGift == 1, "Free Gift claimed by the button", st.freeGift .. " " .. Sim.describe(st.freeGiftRejected))
		check(#st.banked >= 1, "the farm banked a crate afterwards", #st.banked)
		local seen = Sim.statusSeen("Something blocks the way")
		check(not seen, "no blocked trips")
		local claimedAt
		for _, h in ipairs(Sim.statusHistory) do
			if h.text == "Free Gift claimed" then
				claimedAt = h.t
			end
		end
		check(claimedAt and claimedAt > 4 and claimedAt < 20, "the button claimed it within 16 s of the press", claimedAt)
	end,
}
