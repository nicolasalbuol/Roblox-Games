-- Cosmetic catalog. Cosmetics never change gameplay. Colors are {r, g, b} (0-255).
-- unlock.type: "default" | "coins" (price) | "level" (level) | "achievement" (id) | "pass" (pass key)

local Cosmetics = {}

Cosmetics.Inks = {
	{ id = "ink_mint", name = "Mint", color = { 62, 240, 178 }, unlock = { type = "default" } },
	{ id = "ink_sky", name = "Sky", color = { 72, 170, 255 }, unlock = { type = "default" } },
	{ id = "ink_coral", name = "Coral", color = { 255, 104, 104 }, unlock = { type = "default" } },
	{ id = "ink_lemon", name = "Lemon", color = { 255, 224, 72 }, unlock = { type = "coins", price = 250 } },
	{ id = "ink_grape", name = "Grape", color = { 160, 98, 255 }, unlock = { type = "coins", price = 250 } },
	{ id = "ink_tangerine", name = "Tangerine", color = { 255, 150, 50 }, unlock = { type = "coins", price = 400 } },
	{ id = "ink_bubblegum", name = "Bubblegum", color = { 255, 120, 205 }, unlock = { type = "coins", price = 400 } },
	{ id = "ink_lime", name = "Lime", color = { 160, 236, 60 }, unlock = { type = "coins", price = 600 } },
	{ id = "ink_ocean", name = "Ocean", color = { 30, 120, 200 }, unlock = { type = "coins", price = 600 } },
	{ id = "ink_cherry", name = "Cherry", color = { 210, 30, 70 }, unlock = { type = "coins", price = 800 } },
	{ id = "ink_lavender", name = "Lavender", color = { 200, 170, 255 }, unlock = { type = "coins", price = 800 } },
	{ id = "ink_ice", name = "Glacier", color = { 170, 240, 255 }, unlock = { type = "level", level = 10 } },
	{ id = "ink_toxic", name = "Toxic", color = { 110, 255, 40 }, unlock = { type = "coins", price = 1200 } },
	{ id = "ink_ember", name = "Ember", color = { 240, 80, 20 }, unlock = { type = "level", level = 25 } },
	{ id = "ink_gold", name = "Royal Gold", color = { 255, 196, 40 }, unlock = { type = "pass", pass = "VIP" } },
	{ id = "ink_shadow", name = "Midnight", color = { 90, 80, 150 }, unlock = { type = "achievement", id = "land_baron" } },
}

-- kind: "trail" (Roblox Trail), "sparkles", "fire", "smoke", "particles"
Cosmetics.Trails = {
	{ id = "fx_none", name = "None", kind = "none", unlock = { type = "default" } },
	{ id = "fx_glow", name = "Ink Glow", kind = "trail", unlock = { type = "level", level = 3 } },
	{ id = "fx_comet", name = "Comet Tail", kind = "trail", long = true, unlock = { type = "coins", price = 900 } },
	{ id = "fx_sparkle", name = "Sparkle Dust", kind = "sparkles", unlock = { type = "coins", price = 600 } },
	{ id = "fx_smoke", name = "Puff Cloud", kind = "smoke", unlock = { type = "coins", price = 700 } },
	{ id = "fx_flame", name = "Blaze", kind = "fire", unlock = { type = "coins", price = 1500 } },
	{ id = "fx_star", name = "Starfall", kind = "particles", unlock = { type = "level", level = 20 } },
	{ id = "fx_prism", name = "Prism", kind = "trail", rainbow = true, unlock = { type = "pass", pass = "PrismPack" } },
}

Cosmetics.Titles = {
	{ id = "title_none", name = "", unlock = { type = "default" } },
	{ id = "title_rookie", name = "Rookie", unlock = { type = "default" } },
	{ id = "title_artist", name = "Loop Artist", unlock = { type = "coins", price = 500 } },
	{ id = "title_boss", name = "Turf Boss", unlock = { type = "coins", price = 1200 } },
	{ id = "title_snapper", name = "Trail Snapper", unlock = { type = "achievement", id = "trail_cutter" } },
	{ id = "title_champion", name = "Champion", unlock = { type = "achievement", id = "first_win" } },
	{ id = "title_baron", name = "Land Baron", unlock = { type = "achievement", id = "land_baron" } },
	{ id = "title_legend", name = "Legend", unlock = { type = "level", level = 30 } },
	{ id = "title_vip", name = "VIP", unlock = { type = "pass", pass = "VIP" } },
	{ id = "title_prism", name = "Prismatic", unlock = { type = "pass", pass = "PrismPack" } },
}

Cosmetics.Categories = {
	ink = Cosmetics.Inks,
	trail = Cosmetics.Trails,
	title = Cosmetics.Titles,
}

Cosmetics.Defaults = { ink = "ink_mint", trail = "fx_none", title = "title_rookie" }

local byId = {}
for category, list in Cosmetics.Categories do
	for _, item in list do
		assert(byId[item.id] == nil, "duplicate cosmetic id " .. item.id)
		item.category = category
		byId[item.id] = item
	end
end

function Cosmetics.get(id: string)
	return byId[id]
end

-- Can this profile use the item right now (owned or unlocked by level/achievement/pass)?
function Cosmetics.isUnlocked(data, passes: { [string]: boolean }, item): boolean
	local u = item.unlock
	if u.type == "default" then
		return true
	elseif u.type == "coins" then
		return data.owned[item.id] == true
	elseif u.type == "level" then
		return data.level >= u.level
	elseif u.type == "achievement" then
		return data.achievements[u.id] ~= nil
	elseif u.type == "pass" then
		return passes[u.pass] == true
	end
	return false
end

return Cosmetics
