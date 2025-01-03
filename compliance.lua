-- (C) 2016 Tai "DuCake" Kedzierski
-- This code is conveyed to you under the terms
-- of the GNU Lesser General Public License v3.0
-- You should have received a copy of the license
-- in a LICENSE.txt file
-- If not, please see https://www.gnu.org/licenses/lgpl-3.0.html

local helponjoin = core.setting_getbool("babelfish.helponjoin") or false

core.register_on_joinplayer(function(player)
	local playername = player:get_player_name()

	if babel.compliance then
		core.chat_send_player(playername, babel.compliance)
	end
	if helponjoin then
		core.chat_send_player(playername, "This is an multilingual server!")
		core.chat_send_player(playername, "Type '/help bb' and '/help babel' for more information on translations.")
	end
end)
