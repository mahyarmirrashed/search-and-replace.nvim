local M = {}

--- Gets the text from the current visual selection in the active buffer.
--- Handles character, line, and block visual modes with multi byte character support.
--- @return string|nil The selected text, or nil if no valid selection exists.
local function get_visual_selection()
  local bufnr = 0
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
  local start_line, start_col = start_pos[1], start_pos[2]
  local end_line, end_col = end_pos[1], end_pos[2]

  -- Get lines in selection (0-indexed, end-exclusive)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines == 0 then return nil end

  -- Helper for multi byte-safe substring
  local function mb_substr(line, col_start, col_end)
    local byte_start = vim.str_byteindex(line, col_start)
    local byte_end = vim.str_byteindex(line, col_end + 1) - 1
    return line:sub(byte_start + 1, byte_end)
  end

  if #lines == 1 then
    -- Single line selection
    return mb_substr(lines[1], start_col, end_col)
  else
    -- Multi-line selection
    lines[1] = mb_substr(lines[1], start_col, #lines[1])
    lines[#lines] = mb_substr(lines[#lines], 0, end_col)
    return table.concat(lines, "\n")
  end
end

--- Sets up the search-and-replace plugin by defining the :SearchAndReplace command.
--- The command uses the visual selection as the search string and accepts a replacement
--- string and optional file regex as arguments.
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("SearchAndReplace", function(opts)
    -- Ensure we're in visual mode or have a selection
    local mode = vim.fn.mode()
    if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
      print("Please make a visual selection first.")
      return
    end

    -- Get visual selection as search string
    local search = get_visual_selection()
    if not search then
      print("No valid selection found.")
      return
    end

    -- Get replacement string and optional file regex from args
    local args = vim.split(opts.args, "%s+")
    local replace = args[1]
    if not replace then
      print("Replacement string required.")
      return
    end
    local file_regex = args[2] or ".*" -- Default to all files if not provided

    local inputs = {
      search = search,
      replace = replace,
      file_regex = file_regex,
    }

    -- Run sad preview and fzf with delta preview
    local utils = require("search-and-replace.utils")
    utils.run_sad_preview(inputs, function(output)
      if #output == 0 then
        vim.notify("No matches found.", vim.log.levels.INFO)
        return
      end
      utils.show_fzf_with_delta_preview(inputs, output, function(selections)
        utils.apply_sad_replacements(inputs, selections, function()
          vim.api.nvim_command("checktime") -- Refresh buffers
        end)
      end)
    end)
  end, {
    nargs = "+", -- At least one arg (replacement), more optional
    range = true, -- Allow visual selection
  })
end

return M
