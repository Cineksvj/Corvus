-- x. Analytics (Pets Universe style): the Live Steals feed, rate tiles, the trend chart, crates by
-- rarity/zone and a goal with its ETA must all get data while the farm runs.
Scenario {
	name = "x_analytics",
	description = "Auto Steal Grandpa for 70 s with a goal of 3 crates: feed rows, tiles, chart, bars and the goal get filled; the goal is reached.",
	duration = 70,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Options.GoalKind.Value = "Crates stolen"
		Options.GoalTarget.Value = "3"
		Sim.at(1, function()
			Sim.Library.Buttons["Add goal"].Func()
		end)
	end,
	checks = function(Sim, check)
		local W = Sim.Library.Widgets
		local feed = W.StealFeed
		check(feed and type(feed.Data) == "table" and #feed.Data >= 3, "Live Steals feed has the banked crates", feed and feed.Data and #feed.Data)
		check(feed and feed.Data and feed.Data[1] and tostring(feed.Data[1].Title):find("crate") ~= nil, "feed rows name the crate", feed and feed.Data and feed.Data[1] and feed.Data[1].Title)
		local tiles = W["StatTiles@Live Rates"]
		check(tiles and tiles.Tiles.Crates and tiles.Tiles.Crates.Value ~= "-", "Crates rate tile shows a rate", tiles and tiles.Tiles.Crates and tiles.Tiles.Crates.Value)
		local chart = W.TrendChart
		check(chart and chart.Data and #chart.Data.Values == 60, "trend chart got 60 points", chart and chart.Data and #chart.Data.Values)
		local bars = W["BarChart@Crates by Rarity"]
		check(bars and type(bars.Data) == "table" and #bars.Data >= 1, "crates by rarity has bars", bars and bars.Data and #bars.Data)
		local zones = W["BarChart@Crates by Zone"]
		check(zones and zones.Data and zones.Data[1] and tostring(zones.Data[1].Label):find("Grandpa") ~= nil, "crates by zone shows Grandpa's House", zones and zones.Data and zones.Data[1] and zones.Data[1].Label)
		local goals = W.GoalCards
		check(goals and goals.Data and goals.Data[1] and goals.Data[1].Done == true, "the 3 crate goal is reached", goals and goals.Data and goals.Data[1] and Sim.describe(goals.Data[1]))
		local toast = false
		for _, n in ipairs(Sim.Library.Notifications) do
			if n.Title == "Goal reached" then
				toast = true
			end
		end
		check(toast, "Goal reached notification shown")
	end,
}
