-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode/http.lua

local M = {}

function M.get(url)
  local command = "curl -sL " .. vim.fn.shellescape(url)
  local result = vim.fn.system(command)
  return result
end

-- New function to handle POST requests with a JSON body
function M.post(url, body)
  local command = string.format(
    "curl -sL -X POST -H 'Content-Type: application/json' -d %s %s",
    vim.fn.shellescape(body),
    vim.fn.shellescape(url)
  )
  local result = vim.fn.system(command)
  return result
end

return M
