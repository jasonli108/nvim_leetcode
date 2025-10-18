-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode/http.lua

local M = {}

-- This function now uses the standard `curl` command-line tool
-- to fetch the content of a URL.
function M.get(url)
  -- The -s flag makes it silent (no progress bar)
  -- The -L flag makes it follow redirects
  local command = "curl -sL " .. vim.fn.shellescape(url)
  local result = vim.fn.system(command)
  return result
end

return M
