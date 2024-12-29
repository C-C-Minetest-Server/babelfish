-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

babel.engine = "none"

function babel.register_http() end

babel.langcodes = {}

function babel.validate_lang()
	return "Not configured"
end

function babel.translate(_, _, _, handler)
	handler("Not configured")
end
