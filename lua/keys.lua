local M = {}
function M.set_keys(buf)
	local opts = { buffer = buf, noremap = false, silent = true }
	local M_func = require("lyrics")
	-- jumps
	-- jump to artist
	vim.keymap.set("n", "ga", function()
		M.just_to_field(buf, "Artist")
	end, opts)
	vim.keymap.set("n", "gs", function()
		M.just_to_field(buf, "Song")
	end, opts)
	vim.keymap.set("n", "gu", function()
		M.just_to_field(buf, "URL")
	end, opts)
	-- close
	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(buf, { force = true })
	end, opts)
	-- use what is added by user.
	vim.keymap.set("n", "<leader>sS", function()
		M_func.refresh_from_buffer_by_artist_song(buf)
	end, { desc = "<lyrics> Refresh (artist + song)" })
	vim.keymap.set("n", "<leader>sU", function()
		M_func.refresh_from_buffer_by_url(buf)
	end, { desc = "<lyrics> Refresh (url)" })
end

function M.just_to_field(buf, label)
	local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]

	local s = line:find(label .. ":%s*")
	if not s then
		log_info("Label " .. label .. " not found")
	end

	local col = s + #label + 2
	vim.api.nvim_win_set_cursor(0, { 1, col - 1 })
end
return M
