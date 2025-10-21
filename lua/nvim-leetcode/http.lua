-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode/http.lua

local M = {}

local config = {}

function M.setup(opts)
  config = opts
end

function M.get(url)
  local LEETCODE_SESSION = os.getenv("LEETCODE_SESSION")
  local CSRF_TOKEN = os.getenv("CSRF_TOKEN")

  if not LEETCODE_SESSION or LEETCODE_SESSION == "" then
    local browser_cookies = get_cookies_from_browser()
    if browser_cookies then
      LEETCODE_SESSION = browser_cookies.LEETCODE_SESSION
      CSRF_TOKEN = browser_cookies.csrftoken
    end
  end

  if not LEETCODE_SESSION or not CSRF_TOKEN then
    vim.notify("LEETCODE_SESSION and csrf_token are missing.", vim.log.levels.ERROR)
    return ""
  end

  local command = string.format(
    "curl -sL -H 'Cookie: LEETCODE_SESSION=%s; csrftoken=%s' %s",
    LEETCODE_SESSION,
    CSRF_TOKEN,
    vim.fn.shellescape(url)
  )
  local result = vim.fn.system(command)
  return result
end

local function get_cookies_from_browser()
  local python_script = [[
import browser_cookie3
import json
import sys

def get_cookies():
    # List of browser functions to try
    browsers_to_try = [
        browser_cookie3.chrome,
        browser_cookie3.firefox,
        browser_cookie3.brave,
        browser_cookie3.edge,
        browser_cookie3.chromium,
        browser_cookie3.opera,
        browser_cookie3.vivaldi,
        browser_cookie3.safari,
    ]

    for browser_func in browsers_to_try:
        try:
            cj = browser_func(domain_name=".leetcode.com")
            cookies = {}
            for cookie in cj:
                if cookie.name in ["LEETCODE_SESSION", "csrftoken"]:
                    cookies[cookie.name] = cookie.value
            
            if "LEETCODE_SESSION" in cookies and "csrftoken" in cookies:
                return cookies
        except Exception:
            # Ignore exceptions (e.g., browser not found) and try the next one
            continue
    
    return None

try:
    leetcode_cookies = get_cookies()
    if leetcode_cookies:
        print(json.dumps(leetcode_cookies))
    else:
        sys.stderr.write("Automatic cookie detection failed. Please configure cookies manually.")
        sys.exit(1)
except Exception as e:
    sys.stderr.write("An unexpected error occurred: " + str(e))
    sys.exit(1)
]]

  local python_executable
  if config.venv_activate_path and vim.fn.isdirectory(config.venv_activate_path) == 1 then
    python_executable = config.venv_activate_path .. "/bin/python"
  else
    python_executable = config.python_executable or "python3"
  end
  local command = python_executable .. " -c " .. vim.fn.shellescape(python_script)

  local result = vim.fn.system(command)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to fetch cookies: " .. result, vim.log.levels.ERROR)
    return nil
  end

  return vim.fn.json_decode(result)
end

-- New function to handle POST requests with a JSON body
function M.post(url, body)
  local LEETCODE_SESSION = os.getenv("LEETCODE_SESSION")
  local CSRF_TOKEN = os.getenv("CSRF_TOKEN")

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
