--- Health checks for the sad_replace plugin.
--- @return nil
local function check()
  local health = vim.health

  -- Check external dependencies
  local externals = {
    { name = "sad", url = "https://github.com/ms-jpq/sad" },
    { name = "fzf", url = "https://github.com/junegunn/fzf" },
    { name = "delta", url = "https://github.com/dandavison/delta" },
  }

  for _, dep in ipairs(externals) do
    if vim.fn.executable(dep.name) == 1 then
      health.ok(dep.name .. " is installed.")
    else
      health.error(dep.name .. " is not installed. Install it from " .. dep.url)
    end
  end

  -- Check plenary.nvim
  local ok, _ = pcall(require, "plenary")
  if ok then
    health.ok("plenary.nvim is installed.")
  else
    health.error("plenary.nvim is not installed. Install it via your plugin manager.")
  end
end

return {
  check = check,
}
