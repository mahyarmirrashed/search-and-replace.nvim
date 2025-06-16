local Job = require("plenary.job")
local Float = require("plenary.window.float")

--- Applies sad replacements for selected matches.
--- @param inputs table Contains search and replace strings.
--- @param selections table List of selected match lines from fzf.
--- @param callback function Called after applying replacements.
--- @return nil
local function apply_sad_replacements(inputs, selections, callback)
  if #selections == 0 then
    vim.notify("No matches selected for replacement.", vim.log.levels.INFO)
    callback()
    return
  end

  -- Extract unique file paths from selections (format: file:line:col: matched line)
  local files = {}
  local seen = {}
  for _, match in ipairs(selections) do
    local file = match:match("^[^:]+")
    if file and not seen[file] then
      files[#files + 1] = file
      seen[file] = true
    end
  end

  local args = {
    inputs.search,
    inputs.replace,
    unpack(files), -- Apply to selected files only
  }

  Job:new({
    command = "sad",
    args = args,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Replacements applied successfully to " .. #files .. " files.", vim.log.levels.INFO)
      else
        vim.notify("Failed to apply replacements (exit code " .. code .. ").", vim.log.levels.ERROR)
      end
      callback()
    end,
  }):start()
end

--- Runs sad in preview mode to find matches and captures output.
--- @param inputs table Contains search, replace, and file_regex strings.
--- @param callback function Called with the captured output (table of match lines).
--- @return nil
local function run_sad_preview(inputs, callback)
  local args = {
    "--preview",
    inputs.search,
    inputs.replace,
    "--files",
    inputs.file_regex,
    "--hidden",
  }

  Job:new({
    command = "sad",
    args = args,
    on_exit = function(job, code)
      if code ~= 0 then
        print("sad failed with exit code " .. code)
        return
      end
      local output = job:result()
      callback(output)
    end,
  }):start()
end

--- Shows an fzf picker with a delta diff preview for the highlighted match.
--- @param inputs table Contains search and replace strings from SearchAndReplace.
--- @param sad_output table List of match lines from sad.
--- @param callback function Called with the selected matches (table of strings).
--- @return nil
local function show_fzf_with_delta_preview(inputs, sad_output, callback)
  local float = Float:new({
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.6),
    row = math.floor(vim.o.lines * 0.2),
    col = math.floor(vim.o.columns * 0.1),
    border = "single",
  })

  local args = {
    "--multi",
    "--prompt",
    "Select matches> ",
    "--ansi",
    "--preview",
    "echo {} | cut -d' ' -f1 | xargs -I % sh -c 'delta --side-by-side --line-numbers % "
      .. inputs.search
      .. " "
      .. inputs.replace
      .. "'",
  }

  local job = Job:new({
    command = "fzf",
    args = args,
    writer = sad_output,
    on_exit = function(j, code)
      float:close()
      if code == 0 then
        callback(j:result())
      else
        callback({})
      end
    end,
  })

  float:mount()
  job:start()
  vim.fn.termopen({ "fzf" }, { stdin = job.stdin })
end

return {
  apply_sad_replacements = apply_sad_replacements,
  run_sad_preview = run_sad_preview,
  show_fzf_with_delta_preview = show_fzf_with_delta_preview,
}
