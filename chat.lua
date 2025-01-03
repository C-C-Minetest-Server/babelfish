-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

local irct = core.get_modpath("irc")

function babel.chat_send_all(message)
	if irct then
		irc:say(message)
	end
	core.chat_send_all(message)
end
