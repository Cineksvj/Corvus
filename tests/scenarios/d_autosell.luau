-- d. Auto Sell: 3 items worth $1000 in the backpack, the plot's equip slots are already full,
-- so rf_SELL_QUOTE returns {AllCount = 3, AllTotal = 1000}. The player starts on their plot.
local START = Vector3.new(2462, 8, -1060)
Scenario {
	name = "d_autosell",
	description = "Auto Sell (defaults: All, teleport to seller, return, place best first) with 3 items worth $1000. "
		.. "Expect rf_SELL_QUOTE -> {AllCount=3, AllTotal=1000}, re_SELL_DO('all') next to the seller, money +1000, player returns.",
	duration = 45,
	world = {
		position = START,
		backpack = {
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Silver Cup", value = 300 },
			{ kind = "item", name = "Gold Ring", value = 500 },
		},
		floor = {
			{ kind = "stand", x = -15, z = -15, value = 9000 },
			{ kind = "stand", x = -11, z = -15, value = 9000 },
			{ kind = "stand", x = -7, z = -15, value = 9000 },
			{ kind = "stand", x = -3, z = -15, value = 9000 },
			{ kind = "stand", x = 1, z = -15, value = 9000 },
		},
	},
	setup = function(Sim)
		Sim.moneyBefore = Sim.Server.money
	end,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSell.Value = true
		Sim.moneyAtOptions = Sim.Server.money
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		local quotes = Sim.remotes("rf_SELL_QUOTE")
		check(#quotes >= 1, "rf_SELL_QUOTE invoked", #quotes)
		check(quotes[1] and quotes[1].result == "{AllCount=3, AllTotal=1000}", "quote returned AllCount=3, AllTotal=1000", quotes[1] and quotes[1].result)
		local sells = Sim.remotes("re_SELL_DO")
		check(#sells == 1, "re_SELL_DO fired exactly once", #sells)
		check(sells[1] and sells[1].args[1] == "all", "re_SELL_DO fired with \"all\"", sells[1] and sells[1].text)
		check(sells[1] and sells[1].outcome == "accepted", "the server accepted the sale (player next to the seller)", sells[1] and sells[1].outcome)
		check(#st.sold == 1 and st.sold[1].total == 1000, "sold 3 items for $1000", Sim.describe(st.sold))
		local placebest = Sim.remotes("rf_ITEM_LOADOUT")
		check(#placebest >= 1 and placebest[1].t <= sells[1].t, "placebest ran before selling (Place Best Before Selling)", #placebest)
		local root = Sim.rootPart()
		local back = (root.Position - START).Magnitude
		check(back < 5, "player returned to where they were", string.format("%.1f studs away", back))
		check(Sim.statusSeen("Selling"), "status showed Selling")
		check(not Sim.statusSeen("Sell failed"), "no 'Sell failed' status", select(2, Sim.statusSeen("Sell failed")) and select(2, Sim.statusSeen("Sell failed")).text)
	end,
}
