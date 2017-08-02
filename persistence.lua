-- Functions to implement persistent data

local phrasebank = {}
local phrasebankfile = minetest.get_worldpath().."/phrasebank.ser"

local original = "original"

babel.persist_save = function(id, phrase, langcode)
	if not phrasebank[id] then
		phrasebank[id] = {}
		phrasebank[id][original] = phrase
	end

	if langcode then
		phrasebank[id][langcode] = phrase
	end

	ph_save()
end

babel.persist_get = function(id, langcode)
	if not langcode then
		langcode = original
	end

	if not phrasebank[id] then
		return ""
	end

	if not phrasebank[id][original] then
		return nil
	end

	if not phrasebank[id][langcode] then
		phrasebank[id][langcode] = dotranslate(phrasebank[id][original], langcode)
		ph_save()
	end

	return phrasebank[id][langcode]
end

babel.persist_drop = function(id, langcode)
	if not langcode then
		phrasebank[id] = nil
	else
		phrasebank[id][langcode] = nil
	end
	ph_save()
end

-- File manip

local function ph_save()
	local serdata = minetest.serialize(phrasebank)
	if not serdata then
		minetest.log("info", "[babelfish] Phrasebank serialization failed")
		return
	end
	local file, err = io.open(phrasebankfile, "w")
	if err then
		return err
	end
	file:write(serdata)
	file:close()
end

local function ph_load()
	local file, err = io.open(phrasebankfile, "r")
	if err then
		minetest.log("info", "[babelfish] No phrasebank found")
		return
	end
	phrasebank = minetest.deserialize(file:read("*a"))
	file:close()
end

-- TESTING FUNCTIONS - remove in release

minetest.register_chatcommand("bbp_savehelp",{
	func = function(username, args)
		babel.persist_save("babel-help", args)
		babel.persist_save("babel-help", "Ceci est l'aide forcée en français", "fr")
	end
})

minetest.register_chatcommand("bbp_gethelp",{
	func = function(username, args)
		minetest.chat_send_player(username, dump( babel.persist_get("babel-help", args) ) )
	end
})

minetest.register_chatcommand("bbp_drophelp",{
	func = function(username, args)
		babl.presist_drop("babel-help", args)
	end
})

minetest.register_chatcommand("bbp_listhelp",{
	func = function(username, args)
		minetest.chat_send_player(username, dump(phrasebank["babel-help"]) )
	end
})

-- Runtime

ph_load()
