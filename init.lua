local M = {}

local lyrics = require("lyrics")
lyrics.setup({
	lyrics_fetcher_path = "/custom/path/to/main.py", -- user override}
})
-- M.setup({
-- 	lyrics_fetcher_path = "/custom/path/to/main.py", -- user override
-- })

return M
