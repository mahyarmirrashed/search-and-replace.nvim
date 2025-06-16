local M = {}

local Float = require("plenary.window.float")

--- Opens a floating terminal window running sad interactively on the supplied arguments.
---
--- @param search string The pattern to search for.
--- @param replace string The replacement text.
--- @param glob string|nil Regex/glob for files (passed to fd). Defaults to '.*'.
local function open(search, replace, glob)
  local columns, lines = vim.o.columns, vim.o.lines
  local width = math.floor(columns * 0.8)
  local height = math.floor(lines * 0.6)
  local row = math.floor(lines * 0.2)
  local col = math.floor(columns * 0.1)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "single",
    style = "minimal",
  })

  local cmd = string.format(
    "fd --hidden --no-ignore --type f --exclude .git --glob '%s' | sad -- '%s' '%s'",
    glob,
    search,
    replace
  )

  vim.fn.termopen(cmd, {
    shell = true,
    on_exit = function(_, exit_code)
      if exit_code == 130 then
      -- User cancelled, do nothing
      elseif exit_code ~= 0 then
        vim.notify("Search and replace exited with code: " .. exit_code, vim.log.levels.WARN)
      end

      vim.api.nvim_win_close(win, true)
      vim.cmd("checktime")
    end,
  })

  vim.api.nvim_buf_set_option(buf, "filetype", "sad-terminal")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  vim.schedule(function() vim.cmd("startinsert") end)
end

--- Sets up the search-and-replace plugin by defining the :SearchAndReplace command.
---
--- Usage:
---   :SearchAndReplace <search> <replace> [glob]
--- Example:
---   :SearchAndReplace foo bar         -- Replace 'foo' with 'bar' in all files
---   :SearchAndReplace foo bar .lua    -- Replace only in .lua files
---
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("SearchAndReplace", function(opts)
    local args = vim.tbl_map(vim.trim, vim.split(opts.args, "%s+", { trimempty = true }))
    local search, replace, glob = args[1], args[2], args[3]

    if not search or not replace then
      vim.notify("Search string and replacement string are required.", vim.log.levels.ERROR)
      return
    end

    glob = glob or "*"

    open(search, replace, glob)
  end, {
    nargs = "+",
    desc = "Interactive search and replace using fd+sad",
  })
end

return M
