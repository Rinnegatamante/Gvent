--[[
Types:
1 = Unit
2 = Hero

Row:
1 = Melee
2 = Ranged
3 = Machine

Races:
1 = Northern Realms

Abilities:
1 = Tight Bond
2 = Medic
3 = Hero
4 = Morale Boost
5 = Spy
6 = Muster
]]--

-- Setting confirm and cancel buttons
local SCE_CTRL_CONFIRM = Controls.getEnterButton()
local SCE_CTRL_CANCEL = SCE_CTRL_CIRCLE
if SCE_CTRL_CONFIRM == SCE_CTRL_CIRCLE then
	SCE_CTRL_CANCEL = SCE_CTRL_CROSS
end

-- Background Image
local bg = Graphics.loadImage("app0:/assets/bg.jpg")
local bg_x = -75
local new_bg_x = -75
local mov_bg_x = 0

-- Icons
local icons = {
	["machine"] = Graphics.loadImage("app0:/assets/icons/icon_ballista.png"),
	["ranged"] = Graphics.loadImage("app0:/assets/icons/icon_bow.png"),
	["melee"] = Graphics.loadImage("app0:/assets/icons/icon_commando.png"),
	["hero_northern"] = Graphics.loadImage("app0:/assets/icons/icon_northern_hero.png"),
	["hero_nilfgaard"] = Graphics.loadImage("app0:/assets/icons/icon_nilfgaard_hero.png"),
	["hero_scoiatel"] = Graphics.loadImage("app0:/assets/icons/icon_scoiatel_hero.png"),
	["hero_monsters"] = Graphics.loadImage("app0:/assets/icons/icon_noland_hero.png")
}

-- Card Inspect
local ins_card = nil
local deck_idx = 1
local alt_img = 1

-- Fonts
local tfont = Font.load("app0:/assets/gwent.ttf")
local mfont = Font.load("app0:/assets/text.otf")
Font.setPixelSizes(tfont, 38)

-- Colors
local emerald = Color.new(22, 249, 71)
local white = Color.new(255, 255, 255)
local yellow = Color.new(255, 255, 0)
local fade_black = Color.new(0, 0, 0, 100)
local dark_fade_black = Color.new(0, 0, 0, 180)
local card_bg = Color.new(235, 227, 218)

-- Pad stuffs
local oldpad = 0

-- Debug stuffs
local debug_x = 220
local debug_y = 460
local is_debug = true

-- States
local state = 0

-- FPS Counter
local draw_fps = true
local frame = 0
local timer = Timer.new()
local fps = 0

-- Database
local cards = {
	{["name"] = "Ballista", ["race"] = 1, ["type"] = 1, ["row"] = 3, ["strength"] = 6, ["ability"] = 0, ["source"] = "Part of the base deck"},
	{["name"] = "Blue Stripes Commando", ["race"] = 1, ["type"] = 1, ["row"] = 1, ["strength"] = 4, ["ability"] = 1, ["source"] = "1 purchased from Elsa or Bram in White Orchard, 1 purchased from Crow's Perch's quartermaster, 1 purchased from Midcopse's merchant"},
	{["name"] = "Catapult", ["race"] = 1, ["type"] = 1, ["row"] = 3, ["strength"] = 8, ["ability"] = 1, ["source"] = "1 purchased from Elsa or Bram in White Orchard, 1 purchased from Marquise Serenity at the Passiflora"},
	{["name"] = "Crinfrid Reavers Dragon Hunter", ["race"] = 1, ["type"] = 1, ["row"] = 2, ["strength"] = 5, ["ability"] = 1, ["source"] = "1 purchased from Elsa or Bram in White Orchard, 1 purchased from Claywich's merchant, 1 purchased from Midcopse's merchant"},
	{["name"] = "Arachas", ["race"] = 4, ["type"] = 1, ["row"] = 1, ["strength"] = 4, ["ability"] = 6, ["source"] = "1 purchased from Arinbjorn's innkeep, 1 purchased from Urialla Harbor's innkeep, 1 purchased from Svorlag's innkeep"}

}
-- local db = Database.open("ux0:/data/Gvent/database.db") TODO: Check back sqlite3 impl in lpp-vita
local deck = nil
local deck_stats = nil

-- Menus
local menu_idx = 1
local menus = {
	-- Main Menu
	{
	 "Card Database",
	 "Options",
	 "Credits",
	 "Exit to Livearea"
	},
	-- Card Database
	{
	 "Northern Realms",
	 "Nilfgaardian Empire",
	 "Scoia'tel",
	 "Monsters"
	}
}

-- Sound stuffs
Sound.init()
local audiolist = {
	"wolvenstorm.ogg"
}
local bg_song = Sound.open("app0:/musics/" .. audiolist[1])
Sound.play(bg_song, NO_LOOP)
local show_song_state = 0
local song_x = -50
local song_alpha = 255
local song_tmr = Timer.new()
local song_i = 0

-- Function to get proper race name given its index value
local function getRaceName(idx)
	if idx == 0 then
		return "Neutral"
	else -- Hacky way abusing Card Database menu voices
		return menus[2][idx]
	end
end

-- Function to load a specific card image
local function getCardImage(race, name, is_leader)
	if ins_card ~= nil then
		for i, img in pairs(ins_card) do
			Graphics.freeImage(img)
		end
	end
	if is_leader then
		ins_card = {Graphics.loadImage("app0:/assets/cards/" .. getRaceName(race) .. "/leader/" .. name .. ".png")}
	else
		ins_card = {}
		table.insert(ins_card, Graphics.loadImage("app0:/assets/cards/" .. getRaceName(race) .. "/cards/" .. name .. ".png"))
		local j = 2
		while System.doesFileExist("app0:/assets/cards/" .. getRaceName(race) .. "/cards/" .. name .. " " .. j .. ".png") do
			table.insert(ins_card, Graphics.loadImage("app0:/assets/cards/" .. getRaceName(race) .. "/cards/" .. name .. " " .. j .. ".png"))
			j = j + 1
		end
	end
end

-- Function to draw a generic menu
local function drawMenu(x, y, idx)
	local clr = white
	for i, entry in pairs(menus[idx]) do
		if menu_idx == i then
			clr = yellow
		else
			clr = white
		end
		Font.print(mfont, x, y + i * 16, entry, clr)
	end
end

-- Function to get a specific race deck from database
local function getDeck(race)
	local ret = {}
	for i, card in pairs(cards) do
		if card.race == race then
			table.insert(ret, card)
		end
	end
	return ret
	--return Database.execQuery(db, "SELECT * FROM cards WHERE race = '" .. race .. "'")  TODO: Check back sqlite3 impl in lpp-vita
end

-- Function to get generic info about a deck
local function countDeck(deck)
	local tbl = {
		["hero"] = 0,
		["melee"] = 0,
		["ranged"] = 0,
		["machine"] = 0
	}
	for i, card in pairs(deck) do
		if card.type == 2 then
			tbl.hero = tbl.hero + 1
		end
		if card.row == 1 then
			tbl.melee = tbl.melee + 1
		elseif card.row == 2 then
			tbl.ranged = tbl.ranged + 1
		elseif card.row == 3 then
			tbl.machine = tbl.machine + 1
		end
	end
	return tbl
end

-- Function to automatically handle a menu controls
local function handleMenu(input, oldinput, idx)
	if Controls.check(input, SCE_CTRL_UP) and not Controls.check(oldinput, SCE_CTRL_UP) then
		if state ~= 2 then
			menu_idx = menu_idx - 1
			if menu_idx == 0 then
				menu_idx = #menus[idx]
			end
			if state == 1 then -- Card Database
				deck = getDeck(menu_idx)
				deck_stats = countDeck(deck)
			end
		end
	elseif Controls.check(input, SCE_CTRL_DOWN) and not Controls.check(oldinput, SCE_CTRL_DOWN) then
		if state ~= 2 then
			menu_idx = menu_idx + 1
			if menu_idx > #menus[idx] then
				menu_idx = 1
			end
			if state == 1 then -- Card Database
				deck = getDeck(menu_idx)
				deck_stats = countDeck(deck)
			end
		end
	end
	if Controls.check(input, SCE_CTRL_LEFT) and not Controls.check(oldinput, SCE_CTRL_LEFT) then
		if state == 2 then -- Card Inspect
			deck_idx = deck_idx - 1
			if deck_idx == 0 then
				deck_idx = #deck
			end
			getCardImage(menu_idx, deck[deck_idx].name, false)
		end
	elseif Controls.check(input, SCE_CTRL_RIGHT) and not Controls.check(oldinput, SCE_CTRL_RIGHT) then
		if state == 2 then -- Card Inspect
			deck_idx = deck_idx + 1
			if deck_idx > #deck then
				deck_idx = 1
			end
			getCardImage(menu_idx, deck[deck_idx].name, false)
		end
	end
	if Controls.check(input, SCE_CTRL_LTRIGGER) and not Controls.check(oldinput, SCE_CTRL_LTRIGGER) then
		if state == 2 then -- Card Inspect
			alt_img = alt_img - 1
			if alt_img == 0 then
				alt_img = #ins_card
			end
		end
	elseif Controls.check(input, SCE_CTRL_RTRIGGER) and not Controls.check(oldinput, SCE_CTRL_RTRIGGER) then
		if state == 2 then -- Card Inspect
			alt_img = alt_img + 1
			if alt_img > #ins_card then
				alt_img = 1
			end
		end
	end
	if Controls.check(input, SCE_CTRL_CONFIRM) and not Controls.check(oldinput, SCE_CTRL_CONFIRM) then
		if state == 0 then -- Main Menu
			if menu_idx == 1 then
				state = 1
				new_bg_x = -150
				menu_idx = 1
				deck = getDeck(1)
				deck_stats = countDeck(deck)
			elseif menu_idx == 4 then
				System.exit()
			end
		elseif state == 1 then -- Card Database
			state = 2
			deck_idx = 1
			getCardImage(menu_idx, deck[1].name, false)
		end
	end
	if Controls.check(input, SCE_CTRL_TRIANGLE) and not Controls.check(oldinput, SCE_CTRL_TRIANGLE) then
		if state == 1 then -- Card Database
			state = 0
			new_bg_x = - 75
		end
	end
	if new_bg_x ~= bg_x then
		if new_bg_x > bg_x then
			mov_bg_x = 5
		else
			mov_bg_x = -5
		end
	end
end

-- Main loop
while true do
	local pad = Controls.read()
	Graphics.initBlend()
	
	
	if new_bg_x == bg_x then
		if state == 0 then -- Main menu
			Graphics.drawImage(bg_x, 0, bg)
			Font.print(tfont, 425, 12, "Gvent", emerald)
			Graphics.fillRect(356, 604, 80, 300, fade_black)
			drawMenu(360, 66, 1)
			handleMenu(pad, oldpad, 1)
		elseif state == 1 then -- Card Database
			Graphics.drawImage(bg_x, 0, bg)
			Font.print(tfont, 300, 12, "Select Race", emerald)
			Graphics.fillRect(280, 529, 80, 300, fade_black)
			Graphics.fillRect(215, 620, 455, 530, dark_fade_black)
			Graphics.drawImage(220, 460, icons.melee)
			Graphics.drawImage(320, 460, icons.ranged)
			Graphics.drawImage(420, 460, icons.machine)
			if menu_idx == 1 then -- Northern Realms
				Graphics.drawImage(520, 460, icons.hero_northern)
			elseif menu_idx == 2 then -- Nilfgaardian Empire
				Graphics.drawImage(520, 460, icons.hero_nilfgaard)
			elseif menu_idx == 3 then -- Scoia'tel
				Graphics.drawImage(520, 460, icons.hero_scoiatel)
			elseif menu_idx == 4 then -- Monsters
				Graphics.drawImage(520, 460, icons.hero_monsters)
			end
			Font.print(mfont, 290, 480, deck_stats.melee, white)
			Font.print(mfont, 390, 480, deck_stats.ranged, white)
			Font.print(mfont, 490, 480, deck_stats.machine, white)
			Font.print(mfont, 590, 480, deck_stats.hero, white)
			drawMenu(285, 66, 2)
			handleMenu(pad, oldpad, 2)
		elseif state == 2 then -- Card Inspect
			Graphics.drawImage(bg_x, 0, bg)
			Graphics.drawScaleImage(300, 100, ins_card[alt_img], 0.6, 0.6)
			Graphics.fillRect(300, 485, 366, 500, card_bg)
			handleMenu(pad, oldpad, nil) 
		end
	else
		Graphics.drawImage(bg_x, 0, bg)
		bg_x = bg_x + mov_bg_x
	end
	
	-- Song info
	if show_song_state < 3 then
		Graphics.fillRect(song_x, song_x + 250, 475, 525, Color.new(0, 0, 0, song_alpha))
		Font.print(mfont, song_x + 10, 480, Sound.getTitle(bg_song), Color.new(255, 255, 0, song_alpha))
		Font.print(mfont, song_x + 10, 500, Sound.getAuthor(bg_song), Color.new(255, 255, 255, song_alpha))
		if show_song_state == 0 then
			if Timer.getTime(song_tmr) >= 100 then
				song_x = song_x + 2
				Timer.reset(song_tmr)
				if song_x >= 10 then
					show_song_state = 1
				end
			end
		elseif show_song_state == 1 then
			if Timer.getTime(song_tmr) >= 5000 then
				show_song_state = 2
			end
		elseif show_song_state == 2 then
			if Timer.getTime(song_tmr) >= 100 then
				song_alpha = song_alpha - 5
				if song_alpha <= 0 then
					show_song_state = 3
					song_alpha = 255
					song_x = -50
					Timer.destroy(song_tmr)
				end
			end
		end
	elseif not Sound.isPlaying(bg_song) then
		Sound.close(bg_song)
		song_i = (song_i + 1 % #audiolist) + 1
		bg_song = Sound.open("app0:/musics/" .. audiolist[1])
		Sound.play(bg_song, NO_LOOP)
		show_song_state = 0
		song_tmr = Timer.new()
	end
	
	-- Framerate Counter
	if draw_fps then
		frame = frame + 1
		if Timer.getTime(timer) >= 1000 then
			fps = frame
			frame = 0
			Timer.reset(timer)
		end
		Font.print(mfont, 870, 508, "FPS: " .. math.floor(fps), white)
	end
	
	-- Debug stuffs
	if is_debug then
		if Controls.check(pad, SCE_CTRL_UP) and not Controls.check(oldpad, SCE_CTRL_UP) then
			debug_y = debug_y - 1
		end
		if Controls.check(pad, SCE_CTRL_DOWN) and not Controls.check(oldpad, SCE_CTRL_DOWN) then
			debug_y = debug_y + 1
		end
		if Controls.check(pad, SCE_CTRL_LEFT) and not Controls.check(oldpad, SCE_CTRL_LEFT) then
			debug_x = debug_x - 1
		end
		if Controls.check(pad, SCE_CTRL_RIGHT) and not Controls.check(oldpad, SCE_CTRL_RIGHT) then
			debug_x = debug_x + 1
		end
		Font.print(mfont, 0, 0, "Debug Mode", yellow)
		Font.print(mfont, 0, 20, "x: " .. debug_x .. " y: " .. debug_y, yellow)
	end
	
	Graphics.termBlend()
	Screen.flip()
	Screen.waitVblankStart()
	oldpad = pad
end