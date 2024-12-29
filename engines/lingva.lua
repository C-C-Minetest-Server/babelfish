-- babelfish/lingva_engine.lua
-- Copyright (c) 2024 1F616EMO
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

local lingva_state = "init"
local langcode_alias = {}
babel.langcodes = {}

babel.compliance = "Translations are Powered by Lingva"
babel.engine = "Lingva" -- used for tagging messages

local serviceurl = babel.key

local httpapi

local function graphql_fetch(query, ...)
    return httpapi.fetch({
        url = serviceurl,
        method = "POST",
        timeout = 10,
        extra_headers = { "accept: application/graphql-response+json;charset=utf-8, application/json;charset=utf-8" },
        post_data = core.write_json(query),
    }, ...)
end

function babel.register_http(hat)
    httpapi = hat
    babel.register_http = nil

    local valid_alias = {
        ["zh_HANT"] = {
            "zht",
            "zh-tw",
            "zh-hant",
        },
        ["zh"] = {
            "zhs",
            "zh-cn",
            "zh-hans",
        },
    }

    graphql_fetch({
        query = "{languages{code,name}}",
    }, function(responce)
        if not responce.succeeded then
            core.log("error", "Error on requesting language list: " .. dump(responce))
            lingva_state = "error"
            return
        end

        local data = core.parse_json(responce.data)
        if not data then
            core.log("error", "Error on parsing language list: " .. dump(responce))
            lingva_state = "error"
            return
        end

        if data.errors then
            core.log("error", "Error on requesting language list: " .. dump(data.errors))
            lingva_state = "error"
            return
        end

        local langs_got = {}
        local alias_log_strings = {}
        -- We assume all langauge supports bidirectional translation
        for _, langdata in ipairs(data.data.languages) do
            if langdata.code ~= "auto" then
                babel.langcodes[langdata.code] = langdata.name
                langs_got[#langs_got + 1] = langdata.code

                if valid_alias[langdata.code] then
                    for _, alias in ipairs(valid_alias[langdata.code]) do
                        langcode_alias[alias] = langdata.code
                        babel.langcodes[alias] = langdata.name
                        alias_log_strings[#alias_log_strings + 1] =
                            alias .. " -> " .. langdata.code
                    end
                end
            end
        end
        core.log("action", "Got language list: " .. table.concat(langs_got, ", "))
        core.log("action", "Got language alias: " .. table.concat(alias_log_strings, "; "))
        lingva_state = "ready"
    end)
end

function babel.translate(_, phrase, lang, handler)
    if lingva_state ~= "ready" then
        handler("Engine not ready")
        return
    end

    lang = langcode_alias[lang] or lang

    phrase = string.gsub(phrase, "\"", "\\\"")
    graphql_fetch({
        query =
            "{translation(source: \"auto\", target: \"" .. lang .. "\", query: \"" .. phrase .. "\"){target{text}}}",
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

        if data.errors then
            core.log("error", "Error on requesting translation: " .. dump(data.errors))
            handler("Failed request")
            return
        end

        handler(data.data.translation.target.text)
    end)
end
