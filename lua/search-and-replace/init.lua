local M = {}

--- Retrieves the current visual selection as a string using Neovim's modern Lua API.
--- @return string|nil The selected text as a string, or nil if not in visual mode or selection is empty.
local function get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local start = vim.api.nvim_buf_get_mark(bufnr, "<")
  local finish = vim.api.nvim_buf_get_mark(bufnr, ">")

  -- Convert to 0-based indexing for nvim_buf_get_text
  local start_row = start[1] - 1
  local start_col = start[2]
  local end_row = finish[1] - 1
  local end_col = finish[2] + 1 -- nvim_buf_get_text end_col is exclusive

  local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  if #lines == 0 then return nil end
  return table.concat(lines, "\n")
end

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

  glob = glob and vim.trim(glob) ~= "" and glob or "*"

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

    open(search, replace, glob)
  end, {
    nargs = "+",
    desc = "Search and replace using command mode",
  })

  vim.api.nvim_create_user_command("SearchAndReplaceVisual", function(opts)
    local selection = get_visual_selection()
    if not selection or selection == "" then
      vim.notify("No visual selection found.", vim.log.levels.ERROR)
      return
    end
    selection = vim.trim(selection)

    local args = vim.tbl_map(vim.trim, vim.split(opts.args, "%s+", { trimempty = true }))
    local replace, glob = args[1], args[2]

    if not replace or replace == "" then
      vim.notify("Replacement string required.", vim.log.levels.ERROR)
      return
    end

    open(selection, replace, glob)
  end, {
    nargs = "+",
    range = true,
    desc = "Search and replace using visual selection as search string",
  })
end

return M
