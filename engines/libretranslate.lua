-- babelfish/libretranslate_engine.lua
-- Copyright (c) 2024 1F616EMO
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

local libretranslate_state = "init"
babel.langcodes = {}

babel.compliance = "Translations are Powered by LibreTranslate"
babel.engine = "LibreTranslate" -- used for tagging messages

local serviceurl, key
do
    local settings_key = babel.key
    local key_data = string.split(settings_key, ";")
    serviceurl = key_data[1]
    key = key_data[2]
end

local httpapi

function babel.register_http(hat)
    httpapi = hat
    babel.register_http = nil

    do
        httpapi.fetch({
            url = serviceurl .. "/languages",
            method = "GET",
            extra_headers = { "accept: application/json" },
        }, function(responce)
            if not responce.succeeded then
                core.log("error", "Error on requesting language list: " .. dump(responce))
                libretranslate_state = "error"
                return
            end

            local data = core.parse_json(responce.data)
            if not data then
                core.log("error", "Error on parsing language list: " .. dump(responce))
                libretranslate_state = "error"
                return
            end

            if data.error then
                core.log("error", "Error on requesting language list: " .. data.error)
                libretranslate_state = "error"
                return
            end

            local langs_got = {}
            -- We assume all langauge supports bidirectional translation
            for _, langdata in ipairs(data) do
                babel.langcodes[langdata.code] = langdata.name
                langs_got[#langs_got + 1] = langdata.code
            end
            core.log("action", "Got language list: " .. table.concat(langs_got, ", "))
            libretranslate_state = "ready"
        end)
    end
end

function babel.translate(_, phrase, lang, handler)
    if libretranslate_state ~= "ready" then
        handler("Engine not ready")
        return
    end

    local form_data = {
        q = phrase,
        source = "auto",
        target = lang,
        api_key = key,
    }
    httpapi.fetch({
        url = serviceurl .. "/translate",
        timeout = 10,
        multipart = true,
        data = form_data,
        method = "POST",
        extra_headers = { "accept: application/json" },
    }, function(responce)
        if not responce.succeeded then
            core.log("error", "Error on requesting translation: " .. dump(responce))
            handler("Failed request")
            return
        end

        local data = core.parse_json(responce.data)
        if not data then
            core.log("error", "Error on parsing translation: " .. dump(responce))
            handler("Failed request")
            return
        end

        if data.error then
            core.log("error", "Error on requesting translation: " .. data.error)
            handler("Failed request")
            return
        end

        handler(data.translatedText)
    end)
end
