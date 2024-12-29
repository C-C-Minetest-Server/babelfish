-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

babel.compliance = "Translations are Powered by Yandex.Translate"

local httpapi

function babel.register_http(hat)
	httpapi = hat
end

babel.engine = "YANDEX" -- used for tagging messages

babel.langcodes = {
	af = "Afrikaans",
	sq = "Albanian",
	am = "Amharic",
	ar = "Arabic",
	hy = "Armenian",
	az = "Azerbaijan",
	ba = "Bashkir",
	eu = "Basque",
	be = "Belarusian",
	bn = "Bengali",
	bs = "Bosnian",
	bg = "Bulgarian",
	ca = "Catalan",
	ceb = "Cebuano",
	zh = "Chinese",
	hr = "Croatian",
	cs = "Czech",
	da = "Danish",
	nl = "Dutch",
	en = "English",
	eo = "Esperanto",
	et = "Estonian",
	fi = "Finnish",
	fr = "French",
	gl = "Galician",
	ka = "Georgian",
	de = "German",
	el = "Greek",
	gu = "Gujarati",
	ht = "Haitian",
	he = "Hebrew",
	mrj = "Hill",
	hi = "Hindi",
	hu = "Hungarian",
	is = "Icelandic",
	id = "Indonesian",
	ga = "Irish",
	it = "Italian",
	ja = "Japanese",
	jv = "Javanese",
	kn = "Kannada",
	kk = "Kazakh",
	ko = "Korean",
	ky = "Kyrgyz",
	la = "Latin",
	lv = "Latvian",
	lt = "Lithuanian",
	mk = "Macedonian",
	mg = "Malagasy",
	ms = "Malay",
	ml = "Malayalam",
	mt = "Maltese",
	mi = "Maori",
	mr = "Marathi",
	mhr = "Mari",
	mn = "Mongolian",
	ne = "Nepali",
	no = "Norwegian",
	pap = "Papiamento",
	fa = "Persian",
	pl = "Polish",
	pt = "Portuguese",
	pa = "Punjabi",
	ro = "Romanian",
	ru = "Russian",
	gd = "Scottish",
	sr = "Serbian",
	si = "Sinhala",
	sk = "Slovakian",
	sl = "Slovenian",
	es = "Spanish",
	su = "Sundanese",
	sw = "Swahili",
	sv = "Swedish",
	tl = "Tagalog",
	tg = "Tajik",
	ta = "Tamil",
	tt = "Tatar",
	te = "Telugu",
	th = "Thai",
	tr = "Turkish",
	udm = "Udmurt",
	uk = "Ukrainian",
	ur = "Urdu",
	uz = "Uzbek",
	vi = "Vietnamese",
	cy = "Welsh",
	xh = "Xhosa",
	yi = "Yiddish",
}

local serviceurl = "https://translate.api.cloud.yandex.net/translate/v2/translate"

function babel.translate(_, phrase, lang, handler)
	local request_header = {
		"Content-Type: application/json",
		"Authorization: Api-Key " .. babel.key,
	}
	local request_data = {
		texts = { phrase },
		targetLanguageCode = lang,
		speller = true
	}

	httpapi.fetch({
		url = serviceurl,
		timeout = 10,
		method = "POST",
		post_data = core.write_json(request_data),
		extra_headers = request_header,
	}, function(htresponse)
		if htresponse.succeeded then
			local jsontable, jsonerr = core.parse_json(htresponse.data, nil, true)
			if jsonerr then
				core.log("error", "Failed to parse Yandex return: " .. jsonerr)
				handler("Failed request")
				return
			end

			if jsontable.code then
				core.log("error", "Yandex returned error " .. jsontable.code .. ": " .. jsontable.message)
				handler("Failed request")
				return
			end

			return jsontable.translations[1].text
		else
			handler("Failed request") -- FIXME this returns the literal string to the client. Not good.
			core.log("error", "Error on requesting -- " .. dump(htresponse))
		end
	end)
end
