local M = {}

-- load the initial configs
local config_module = require("config")
local keys = require("keys")
M.config = config_module.config
function M.setup(user_config)
	for k, v in pairs(user_config or {}) do
		M.config[k] = v
	end
end
print(M.config.lyrics_fetcher_path)
-- local is_mock = false
local is_mock = M.config.is_mock

-- start
local function log_info(msg)
	vim.notify("[lyrics] " .. msg, vim.log.levels.INFO)
end

local function log_error(msg)
	vim.notify("[lyrics] " .. msg, vim.log.levels.ERROR)
end
local function slugify(str)
	str = str:lower():gsub("^%s+", ""):gsub("%s+$", "")
	str = str:gsub("[^%w]+", "-")
	str = str:gsub("%-+", "-")
	str = str:gsub("^%-", ""):gsub("%-$", "")
	return str
end

local function build_scrape_url(artist, song)
	local a = slugify(artist)
	local s = slugify(song)
	return "https://genius.com/" .. a .. "-" .. s .. "-lyrics"
end

local function reverse_scrape_url(url)
	local slug = url:match("genius%.com/([%w%-]+)%-lyrics")
	if not slug then
		return
	end

	local parts = {}
	for p in slug:gmatch("[^%-]+") do
		table.insert(parts, p)
	end

	if #parts < 2 then
		return
	end

	local song = parts[0]
	local artist = table.concat(vim.list_slice(parts, 1, 2), " ")
	if not song or not artist then
		return
	end
	artist = artist:gsub("(%a)([%w]*)", function(h, t)
		return h:upper() .. t
	end)
	song = song:gsub("(%a)([%w]*)", function(h, t)
		return h:upper() .. t
	end)
	return artist, song
end

local function parse_first_line(buf)
	local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]

	local artist = line:match("Artist:%s*([^|]+)")
	local song = line:match("Song:%s*([^|]+)")
	local url = line:match("URL:%s*([^|]+)")
	return artist and artist:gsub("%s+$", ""), song and song:gsub("%s+$", ""), url and url:gsub("%s+$", "")
end
local function fetch_lyrics(artist, song, url, is_mocked)
	if is_mocked then
		if url then
			if url == "https://genius.com/radiohead-creep-lyrics" then
				return "When you were here before\nCouldn't look you in the eye\nYou're just like an angel\nYour skin makes me cry"
			end

			return "[mock] No lyrics found for " .. url
		else
			if artist == "Radiohead" and song == "Creep" then
				return "When you were here before\nCouldn't look you in the eye\nYou're just like an angel\nYour skin makes me cry"
			end
			return "[mock] No lyrics found for " .. artist .. " - " .. song
		end
	end
	-- local cmd = { "python3", "lyrics_genius_scrape.py", artist, song }
	local cmd
	if url then
		cmd = { "uv", "run", "src/main.py", "--url", url }
	else
		cmd = { "uv", "run", "src/main.py", "--artist", artist, "--title", song }
	end

	print(M.config.lyrics_fetcher_path)
	local result = vim.system(cmd, { text = true, cwd = M.config.lyrics_fetcher_path }):wait()
	-- local result = vim.system(cmd, { text = true, cwd = "/home/xouzoura/code/python/me/lyrics" }):wait()

	if result.code ~= 0 then
		log_error(result.stderr)
		return false, ""
	end

	return true, result.stdout
end

function M.refresh_from_buffer_by_artist_song(buf)
	local artist, song, _ = parse_first_line(buf)
	if not artist or not song then
		log_error(
			"Improper value for first line, should be in the format of Artist: Radiohead | Song: Creep | URL: https://genius.com/radiohead-creep-lyrics"
		)
		return
	end

	local result, metadata = M.get_lyrics_by_artist_song(artist, song)

	M.modify_existing_buffer(buf, metadata, result)
end
function M.refresh_from_buffer_by_url(buf)
	local _, _, url = parse_first_line(buf)
	if not url then
		log_error(
			"Improper value for first line, should be in the format of Artist: Radiohead | Song: Creep | URL: https://genius.com/radiohead-creep-lyrics"
		)
		return
	end

	local result, metadata = M.get_lyrics_by_url(buf, url)

	M.modify_existing_buffer(buf, metadata, result)
end

function M.modify_existing_buffer(buf, metadata, lyrics_lines)
	local new_line = M._first_line(metadata)
	vim.api.nvim_buf_set_lines(buf, 0, 1, false, { new_line })
	local lines_table = vim.split(lyrics_lines or "", "\n", { plain = true })
	local lines = {}
	for _, line in ipairs(lines_table) do
		table.insert(lines, line)
	end

	vim.api.nvim_buf_set_lines(buf, 2, -1, false, lines)
end

function M._first_line(metadata)
	local result =
		string.format("Artist: %s | Song: %s | URL: %s", metadata.artist or "", metadata.song or "", metadata.url or "")
	return result
end

function M.open_buffer(metadata, lyrics_lines)
	local buf = vim.api.nvim_create_buf(false, true)
	keys.set_keys(buf)

	-- write lines: first row = metadata
	local lines = { M._first_line(metadata) }
	table.insert(lines, "----------------------------------------")
	local lines_table = vim.split(lyrics_lines or "", "\n", { plain = true })
	for _, line in ipairs(lines_table) do
		table.insert(lines, line)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_current_buf(buf)

	-- Buffer options to make it ephemeral
	vim.bo[buf].buftype = "" -- normal editable
	vim.bo[buf].bufhidden = "wipe" -- auto-wipe
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].buflisted = false

	return buf
end

function M.get_lyrics_by_artist_song(artist, song)
	local _, lyrics = fetch_lyrics(artist, song, nil, is_mock)
	local url = build_scrape_url(artist, song)
	local metadata = { artist = artist, song = song, url = url }
	return lyrics, metadata
end

function M.get_lyrics_by_url(buf, url)
	local _, lyrics = fetch_lyrics(nil, nil, url, is_mock)
	local artist, song = reverse_scrape_url(url)
	if not artist or not song then
		artist, song, _ = parse_first_line(buf)
	end
	local metadata = { artist = artist, song = song, url = url }
	return lyrics, metadata
end

local function read_cache()
	local cache_file = "/tmp/nowplaying.cache"

	local f = io.open(cache_file, "r")
	if not f then
		return 0, "", ""
	end
	local line = f:read("*l") or ""
	f:close()
	local ts, status, meta = line:match("^(%d+)|([^|]*)|(.*)$")
	return tonumber(ts) or 0, status or "", meta or ""
end

function M.get_playing_song_from_cache()
	local now = os.time()
	local ts, playing, meta = read_cache()
	if playing and (now - ts <= 10) then
		local artist, song = meta:match("^(.-)%s*%-%s*(.+)$")

		if not artist or not song then
			return nil, nil
		end

		artist = artist:gsub("^%s+", ""):gsub("%s+$", "")
		song = song:gsub("^%s+", ""):gsub("%s+$", "")
		return artist, song
	else
		-- return "Radiohead", "Creep" -- #TODO: remove
		return "", ""
	end
end
function M.get_current_song()
	local artist, song = M.get_playing_song_from_cache()
	if not artist or not song then
		log_info("No song found to be playing in the cache.")
	end
	local result, metadata = M.get_lyrics_by_artist_song(artist, song)
	M.open_buffer(metadata, result)
end

return M
