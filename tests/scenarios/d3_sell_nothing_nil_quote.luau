-- d3. Live: rf_SELL_QUOTE answers nil. With nothing sellable in the backpack Auto Sell
-- must not walk to the seller every interval (third live log: pointless sell trips).
local START = Vector3.new(2462, 8, -1060)
Scenario {
	name = "d3_sell_nothing_nil_quote",
	description = "Auto Sell on, rf_SELL_QUOTE -> nil, empty backpack: no re_SELL_DO and the player never leaves the plot.",
	duration = 40,
	world = { position = START },
	setup = function(Sim)
		Sim.Server.sellQuoteNil = true
	end,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSell.Value = true
		Options.SellInterval.Value = 5
	end,
	checks = function(Sim, check)
		check(#Sim.remotes("re_SELL_DO") == 0, "no re_SELL_DO with nothing to sell", #Sim.remotes("re_SELL_DO"))
		local root = Sim.rootPart()
		local moved = (root.Position - START).Magnitude
		check(moved < 5, "player stayed where it was (no trip to the seller)", string.format("%.1f studs away", moved))
		check(not Sim.statusSeen("Selling"), "status never showed Selling")
	end,
}
