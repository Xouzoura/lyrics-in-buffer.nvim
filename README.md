# Lyrics within the buffer.

This plugin helps me use the genius.com site to get the lyrics of a song within the buffer.

## Requirements

- https://github.com/Xouzoura/lyrics-fetcher to clone it in a directory that you want

## Example setup

```
    return {
        
      "Xouzoura/lyrics-in-buffer.nvim",
      config = function()
        require("lyrics").setup {
          lyrics_fetcher_path = "~/code/python/me/lyrics",
        }
      end,

      keys = {
        {
          "<leader>sn",
          function()
            require("lyrics").get_current_song()
          end,
          desc = "(Lyrics) Search what is playing now",
        },
      },
    }
```
