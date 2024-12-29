-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

babel = {}

local modpath = core.get_modpath("babelfish")
dofile(modpath .. "/chat.lua")
dofile(modpath .. "/utilities.lua")
dofile(modpath .. "/persistence.lua")

local langprefs = core.get_worldpath() .. "/babel_langprefs"
local engine = core.setting_get("babelfish.engine") or "yandex"
babel.key = core.setting_get("babelfish.key")
babel.defaultlang = core.setting_get("babelfish.defaultlang") or "en"

core.register_privilege("babelmoderator")

local chat_history = {}
local player_pref_language = {}

-- ===== SECURITY ======

if not babel.key then
	core.log("error", "Babelfish engine key undefined. Translations will be unavaliable.")
	engine = "none"
end
dofile(modpath .. "/engines/" .. engine .. ".lua")

babel.register_http(assert(core.request_http_api(),
	"Could not get HTTP API table. Add babelfish to secure.http_mods"))

-- =====================

local function prefsave()
	local serdata = core.serialize(player_pref_language)
	if not serdata then
		core.log("error", "[babelfish] Data serialization failed")
		return
	end
	local file, err = io.open(langprefs, "w")
	if err then
		return err
	end
	file:write(serdata)
	file:close()
end

local function prefload()
	local file, err = io.open(langprefs, "r")
	if err then
		core.log("error", "[babelfish] Data read failed")
		return
	end
	player_pref_language = core.deserialize(file:read("*a")) or {}
	file:close()
end

-- ========================== Language engine and overridable validation

function babel.validate_lang(_, langstring)
	for target, _ in pairs(babel.langcodes) do
		if target == langstring then
			return true
		end
	end

	return tostring(langstring) .. " is not a recognized language"
end

-- =====================================================================/

local function components(mystring)
	local iter = mystring:gmatch("%S+")
	local targetlang = iter() or ""
	local targetphrase = mystring:gsub("^" .. targetlang .. " ", "")

	return targetlang, targetphrase
end

local function validate_player(playername)
	if core.get_player_by_name(playername) then
		return true
	end
	return false
end

local function dotranslate(lang, phrase, handler)
	return babel:translate(phrase, lang, handler)
end

local function check_message(message)
	-- Search for "%" token
	local _, _, targetlang = message:find("%%([a-zA-Z-_]+)")
	if targetlang then
		local targetphrase = message:gsub("%%" .. targetlang, '', 1)
		local validation = babel:validate_lang(targetlang)

		if validation ~= true then
			return false, validation
		end
		return targetlang, targetphrase
	end
	return false
end

local dosend

-- Shortcut translation
-- Send a message like "Hello everyone ! %fr"
-- The message is broadcast in original form, then in French
if core.global_exists("beerchat") then
	dosend = function(name, message, channel)
		if not channel then
			channel = beerchat.get_player_channel(name)
			if not channel then
				beerchat.fix_player_channel(name, true)
			end
		end
		beerchat.send_on_channel({
			name = name,
			channel = channel,
			message = "[" .. babel.engine .. "]: " .. message,
			_supress_babelfish = true,
		})
	end
	beerchat.register_callback("before_send_on_channel", function(name, msg)
		if msg._supress_babelfish then return end
		local message = msg.message
		if msg.channel == beerchat.main_channel_name then
			chat_history[name] = message
		end

		local targetlang, targetphrase = check_message(message)
		if not targetlang then
			if targetphrase then
				core.chat_send_player(name, targetphrase)
			end
		else
			dotranslate(targetlang, targetphrase, function(newphrase)
				dosend(name, newphrase, msg.channel)
			end)
		end
	end)
else
	dosend = function(name, _, message)
		babel.chat_send_all("[" .. babel.engine .. " " .. name .. "]: " .. message)
	end
	core.register_on_chat_message(function(player, message)
		if not core.check_player_privs(player, { shout = true }) then
			return
		end

		chat_history[player] = message

		local targetlang, targetphrase = check_message(message)
		if not targetlang then
			core.chat_send_player(player, targetphrase)
		else
			dotranslate(targetlang, targetphrase, function(newphrase)
				dosend(player, newphrase)
				core.log("action", player .. " CHAT [" .. babel.engine .. "]: " .. newphrase)
			end)
		end
	end)
end

local function f_babel(player, argstring)
	local targetplayer = argstring
	if not player_pref_language[player] then
		player_pref_language[player] = babel.defaultlang
	end

	local targetlang = player_pref_language[player]

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		return false, validation
	end

	if not chat_history[targetplayer] then
		return false, targetplayer .. " has not said anything"
	end

	dotranslate(targetlang, chat_history[targetplayer], function(newphrase)
		core.chat_send_player(player, "[" .. babel.engine .. "]: " .. newphrase)
	end)
	return true
end

if core.global_exists("beerchat") then
	local old_babel = f_babel
	f_babel = function(player, argstring)
		if not beerchat.is_player_subscribed_to_channel(player, beerchat.main_channel_name) then
			return false, "You are not in the main channel!"
		end
		return old_babel(player, argstring)
	end
end

local function f_babelshout(player, argstring)
	-- babel equivalent of shout - broadcast translated message
	local targetlang, targetphrase = components(argstring)

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		return false, validation
	end

	dotranslate(targetlang, targetphrase, function(newphrase)
		dosend(player, newphrase)
		core.log("action", player .. " CHAT [" .. babel.engine .. "]: " .. newphrase)
	end)
	return true
end

local function f_babelmsg(player, argstring)
	-- babel equivalent of private message
	local targetplayer, targetphrase = components(argstring)
	local targetlang = player_pref_language[targetplayer]

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		return false, validation
	end

	if not validate_player(targetplayer) then
		return false, targetplayer .. " is not a connected player"
	end

	dotranslate(targetlang, targetphrase, function(newphrase)
		core.chat_send_player(targetplayer, "[" .. babel.engine .. " PM from " .. player .. "]: " .. newphrase)
		core.log("action", player .. " PM to " .. targetplayer .. " [" .. babel.engine .. "]: " .. newphrase)
		core.chat_send_player(player, "[" .. babel.engine .. " PM to " .. targetplayer .. "]: " .. newphrase)
	end)
	return true
end

local function setplayerlanguage(tplayer, langcode)
	if core.get_player_by_name(tplayer) then
		player_pref_language[tplayer] = langcode
		prefsave()
	end
end

local function getplayerlanguage(tplayer)
	return player_pref_language[tplayer]
end

core.register_chatcommand("bblang", {
	description = "Set your preferred language",
	func = function(player, args)
		local validation = babel:validate_lang(args)
		if validation ~= true then
			return false, validation
		else
			setplayerlanguage(player, args) -- FIXME this should use the above pref functions
			return true, args .. " : OK"
		end
	end
})

core.register_chatcommand("bbcodes", {
	description = "List the available language codes",
	func = function()
		return true, dump(babel.langcodes)
	end
})

core.register_chatcommand("babel", {
	description = "Translate a player's last chat message. Use /bblang to set your language",
	params = "<playername>",
	func = f_babel
})

core.register_chatcommand("bb", {
	description = "Translate a sentence and transmit it to everybody",
	params = "<lang-code> <sentence>",
	func = f_babelshout,
	privs = { shout = true },
})

core.register_chatcommand("bmsg", {
	description = "Send a private message to a player, in their preferred language",
	params = "<player> <sentence>",
	privs = { shout = true },
	func = f_babelmsg
})

-- Admin commands

core.register_chatcommand("bbset", {
	description = "Set a player's preferred language (if they do not know how)",
	params = "<player> <language-code>",
	privs = { babelmoderator = true },
	func = function(_, message)
		local tplayer, langcode = components(message)
		setplayerlanguage(tplayer, langcode)
	end,
})

-- Set player's default language

core.register_on_joinplayer(function(player)
	local playername = player:get_player_name()
	if not getplayerlanguage(playername) then
		setplayerlanguage(playername, babel.defaultlang)
	end
end)

-- Display help string, and compliance if set
dofile(core.get_modpath("babelfish") .. "/compliance.lua")

prefload()
