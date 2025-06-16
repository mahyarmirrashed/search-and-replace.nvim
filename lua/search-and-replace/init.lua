local M = {}

local Float = require("plenary.window.float")

--- Opens a floating terminal window running sad interactively on the supplied arguments.
---
--- @param search string The pattern to search for.
--- @param replace string The replacement text.
--- @param file_regex string|nil Regex/glob for files (passed to fd). Defaults to '.*'.
local function open(search, replace, file_regex)
  file_regex = vim.trim(file_regex or ".*")

  -- Calculate window size and position once
  local columns, lines = vim.o.columns, vim.o.lines
  local width = math.floor(columns * 0.8)
  local height = math.floor(lines * 0.6)
  local row = math.floor(lines * 0.2)
  local col = math.floor(columns * 0.1)

  local float = Float:new({
    width = width,
    height = height,
    row = row,
    col = col,
    border = "single",
  })

  -- Configure buffer before mounting
  vim.api.nvim_buf_set_option(float.bufnr, "filetype", "sad-terminal")
  vim.api.nvim_buf_set_option(float.bufnr, "bufhidden", "wipe")
  float:mount()

  -- Compose the shell command safely
  local cmd = table.concat({
    "fd",
    "--hidden",
    "--no-ignore",
    "--type",
    "f",
    "'" .. file_regex .. "'",
    "|",
    "sad",
    "--",
    "'" .. search .. "'",
    "'" .. replace .. "'",
  }, " ")

  local exited = false
  vim.fn.termopen(cmd, {
    shell = true,
    on_exit = function(_, exit_code)
      if exited then return end
      exited = true
      if exit_code ~= 0 then vim.notify("Search and replace exited with code: " .. exit_code, vim.log.levels.WARN) end
      float:close()
      vim.cmd("checktime")
    end,
  })

  vim.schedule(function() vim.cmd("startinsert") end)
end

--- Sets up the search-and-replace plugin by defining the :SearchAndReplace command.
---
--- Usage:
---   :SearchAndReplace <search> <replace> [file_regex]
--- Example:
---   :SearchAndReplace foo bar         -- Replace 'foo' with 'bar' in all files
---   :SearchAndReplace foo bar .lua    -- Replace only in .lua files
---
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("SearchAndReplace", function(opts)
    local args = vim.tbl_map(vim.trim, vim.split(opts.args, "%s+", { trimempty = true }))
    local search, replace, file_regex = args[1], args[2], args[3]

    if not search or not replace then
      vim.notify("Search string and replacement string are required.", vim.log.levels.ERROR)
      return
    end

    open(search, replace, file_regex)
  end, {
    nargs = "+",
    desc = "Interactive search and replace using fd+sad",
  })
end

return M
