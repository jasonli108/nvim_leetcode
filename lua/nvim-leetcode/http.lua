-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode/http.lua

local M = {}

local config = {}

function M.setup(opts)
  config = opts
end

function M.get(url)
  local command = "curl -sL " .. vim.fn.shellescape(url)
  local result = vim.fn.system(command)
  return result
end

local function get_cookies_from_browser()
  local python_script = [[
import browser_cookie3
import json
import sys

try:
    cj = browser_cookie3.load(domain_name=".leetcode.com")
    cookies = {}
    for cookie in cj:
        if cookie.name in ["LEETCODE_SESSION", "csrftoken"]:
            cookies[cookie.name] = cookie.value
    if "LEETCODE_SESSION" not in cookies or "csrftoken" not in cookies:
        sys.stderr.write("Could not find LeetCode session cookies.")
        sys.exit(1)
    print(json.dumps(cookies))
except Exception as e:
    sys.stderr.write("Failed to load browser cookies: " + str(e))
    sys.exit(1)
]]

  local python_executable = config.python_executable or "python3"
  local command = python_executable .. " -c " .. vim.fn.shellescape(python_script)

  if config.venv_activate_path then
    command = ". " .. vim.fn.shellescape(config.venv_activate_path) .. " && " .. command
  end

  local result = vim.fn.system(command)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to fetch cookies: " .. result, vim.log.levels.ERROR)
    return nil
  end

  return vim.fn.json_decode(result)
end

-- New function to handle POST requests with a JSON body
function M.post(url, body)
  local LEETCODE_SESSION = config.leetcode_session
  local CSRF_TOKEN = config.csrf_token

  if not LEETCODE_SESSION or LEETCODE_SESSION == "" then
    local browser_cookies = get_cookies_from_browser()
    if browser_cookies then
      LEETCODE_SESSION = browser_cookies.LEETCODE_SESSION
      CSRF_TOKEN = browser_cookies.csrftoken
    else
      vim.notify("Could not automatically fetch cookies. Please configure them manually.", vim.log.levels.ERROR)
      return ""
    end
  end

  if not LEETCODE_SESSION or not CSRF_TOKEN then
    vim.notify("LEETCODE_SESSION and csrf_token are missing.", vim.log.levels.ERROR)
    return ""
  end

  local referer_url = url:gsub("/submit/$", "/")

  local command = string.format(
    "curl -sL -X POST " ..
    "-H 'Content-Type: application/json' " ..
    "-H 'x-csrftoken: %s' " ..
    "-H 'Cookie: LEETCODE_SESSION=%s; csrftoken=%s' " ..
    "-H 'referer: %s' " ..
    "-d %s %s",
    CSRF_TOKEN,
    LEETCODE_SESSION,
    CSRF_TOKEN,
    vim.fn.shellescape(referer_url),
    vim.fn.shellescape(body),
    vim.fn.shellescape(url)
  )
  local result = vim.fn.system(command)
  return result
end

return M
