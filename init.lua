-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

babel = {}

local modpath = core.get_modpath("babelfish")
dofile(modpath.."/chat.lua" )
dofile(modpath.."/utilities.lua" )
dofile(modpath.."/persistence.lua" )

local langprefs = core.get_worldpath().."/babel_langprefs"
local engine = core.setting_get("babelfish.engine") or "yandex"
babel.key = core.setting_get("babelfish.key")
babel.defaultlang = core.setting_get("babelfish.defaultlang") or "en"

core.register_privilege("babelmoderator")

local chat_history = {}
local player_pref_language = {}

-- ===== SECURITY ======

if not babel.key then engine = "none" end
dofile(modpath.."/"..engine.."_engine.lua")

local httpapitable = assert(core.request_http_api(),
	"Could not get HTTP API table. Add babelfish to secure.http_mods")
babel.register_http(httpapitable)

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

function babel.validate_lang(self, langstring)
	for target, langname in pairs(babel.langcodes) do
		if target == langstring then
			return true
		end
	end

	return tostring(langstring).." is not a recognized language"
end

-- =====================================================================/

local function components(mystring)
	local iter = mystring:gmatch("%S+")
	local targetlang = iter() or ""
	local targetphrase = mystring:gsub("^"..targetlang.." ", "")

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
	local n,m = message:find("%%..")
	local targetlang = nil
	local targetphrase = message
	if n then
		targetlang = message:sub(n+1, m) -- Removes '%' token
		targetphrase = message:gsub("%%"..targetlang,'',1)
	end

	if not targetlang then
		return false
	end

	-- True, or error string
	local validation = babel:validate_lang(targetlang)

	if validation ~= true then
		return false, validation
	end

	return targetlang, targetphrase
end

-- Shortcut translation
-- Send a message like "Hello everyone ! %fr"
-- The message is broadcast in original form, then in French
if core.global_exists("beerchat") then
	beerchat.register_callback("before_send_on_channel", function(name, msg)
		local message = msg.message
		if msg.channel == beerchat.main_channel_name then
			chat_history[name] = message
		end

		local targetlang, targetphrase = check_message(message)
		if not targetlang then
			if targetphrase then
				babel.chat_send_player(name, targetphrase)
			end
		else
			dotranslate(targetlang, targetphrase, function(newphrase)
				beerchat.send_on_channel({
					name = name,
					channel = msg.channel,
					message = "[" .. babel.engine .. "]: " .. newphrase,
				})
			end)
		end
	end)
else
	core.register_on_chat_message(function(player, message)
		if not core.check_player_privs(player, { shout = true }) then
			return
		end

		chat_history[player] = message

		local targetlang, targetphrase = check_message(message)
		if not targetlang then
			babel.chat_send_player(player, targetphrase)
		else
			dotranslate(targetlang, targetphrase, function(newphrase)
				babel.chat_send_all("[" .. babel.engine .. " " .. player .. "]: " .. newphrase)
				core.log("action", player .. " CHAT [" .. babel.engine .. "]: " .. newphrase)
			end)
		end
	end)
end

local function f_babel(player, argstring)
	if not beerchat.is_player_subscribed_to_channel(player, beerchat.main_channel_name) then
		-- beerchat is present, so we can't use the chat history
		babel.chat_send_player(player, "You are not in the main channel!")
		return
	end
	local targetplayer = argstring
	if not player_pref_language[player] then
		player_pref_language[player] = babel.defaultlang
	end

	local targetlang = player_pref_language[player]

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		babel.chat_send_player(player, validation)
		return
	end

	if not chat_history[targetplayer] then
		babel.chat_send_player(player, targetplayer.." has not said anything")
		return
	end

	dotranslate(targetlang, chat_history[targetplayer], function(newphrase)
		babel.chat_send_player(player, "["..babel.engine.."]: "..newphrase)
	end)
end

local function f_babelshout(player, argstring)
	-- babel equivalent of shout - broadcast translated message
	local targetlang, targetphrase = components(argstring)

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		babel.chat_send_player(player, validation)
		return
	end

	dotranslate(targetlang, targetphrase, function(newphrase)
		babel.chat_send_all("["..babel.engine.." "..player.."]: "..newphrase)
		core.log("action", player.." CHAT ["..babel.engine.."]: "..newphrase)
	end)
end

local function f_babelmsg(player, argstring)
	-- babel equivalent of private message
	local targetplayer, targetphrase = components(argstring)
	local targetlang = player_pref_language[targetplayer]

	local validation = babel:validate_lang(targetlang)
	if validation ~= true then
		babel.chat_send_player(player, validation)
		return
	end

	if not validate_player(targetplayer) then
		babel.chat_send_player(player, targetplayer.." is not a connected player")
		return
	end
	
	dotranslate(targetlang, targetphrase, function(newphrase)
		babel.chat_send_player(targetplayer, "["..babel.engine.." PM from "..player.."]: "..newphrase)
		core.log("action", player.." PM to "..targetplayer.." ["..babel.engine.."]: "..newphrase)
	end)
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
	func = function(player,args)
		local validation = babel:validate_lang(args)
		if validation ~= true then
			babel.chat_send_player(player, validation)
			return
		else
			setplayerlanguage(player, args) -- FIXME this should use the above pref functions
			babel.chat_send_player(player, args.." : OK" )
		end
	end
})

core.register_chatcommand("bbcodes", {
	description = "List the available language codes",
	func = function(player,command)
		core.chat_send_player(player,dump(babel.langcodes))
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
	privs = {shout = true},
})

core.register_chatcommand("bmsg", {
	description = "Send a private message to a player, in their preferred language",
	params = "<player> <sentence>",
	privs = {shout = true},
	func = f_babelmsg
})

-- Admin commands

core.register_chatcommand("bbset", {
	description = "Set a player's preferred language (if they do not know how)",
	params = "<player> <language-code>",
	privs = {babelmoderator = true},
	func = function(player, message)
		local tplayer, langcode = components(message)
		setplayerlanguage(tplayer, langcode)
	end,
})

-- Set player's default language

core.register_on_joinplayer(function(player, ip)
	local playername = player:get_player_name()
	if not getplayerlanguage(playername) then
		setplayerlanguage(playername, babel.defaultlang)
	end
end)

-- Display help string, and compliance if set
dofile(core.get_modpath("babelfish").."/compliance.lua")

prefload()
