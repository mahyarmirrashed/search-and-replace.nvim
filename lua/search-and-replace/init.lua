local M = {}

--- Escapes special regex characters in a string to treat it as a literal pattern.
--- @param str string The input string to escape.
--- @return string The escaped string.
local function escape_regex(str) return str:gsub("([%.%*+%-%?%^%$%(%)%[%]%{%}%|%\\])", "\\%1") end

--- Sets up the search-and-replace plugin by defining the :SearchAndReplace command.
--- The command requires a search string and replacement string, with an optional file regex.
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("SearchAndReplace", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })

    local search = args[1]
    local replace = args[2]
    if not search or not replace then
      vim.notify("Search string and replacement string are required.", vim.log.levels.ERROR)
      return
    end

    local file_regex = args[3] or ".*" -- Default to all files if not provided

    local inputs = {
      search = escape_regex(search),
      replace = replace,
      file_regex = file_regex,
    }

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
    nargs = "+",
  })
end

return M
