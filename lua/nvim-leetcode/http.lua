-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode/http.lua

local M = {}

local config = {}

function M.setup(opts)
  config = opts
end

-- Tries to get cookies from a browser using a Python script.
local function get_cookies_from_browser()
  local python_script = [[ 
import browser_cookie3
import json
import sys

def get_cookies():
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
            continue
    
    return None

try:
    leetcode_cookies = get_cookies()
    if leetcode_cookies:
        print(json.dumps(leetcode_cookies))
    else:
        sys.stderr.write("Automatic cookie detection failed.")
        sys.exit(1)
except Exception as e:
    sys.stderr.write("An unexpected error occurred: " + str(e))
    sys.exit(1)
]]

  local python_executable = config.python_executable or "python3"
  local command = python_executable .. " -c " .. vim.fn.shellescape(python_script)
  local result = vim.fn.system(command)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to fetch cookies from browser: " .. result, vim.log.levels.ERROR)
    return nil
  end

  return vim.fn.json_decode(result)
end

-- Gets the full cookie string from config, env var, or browser.
local function get_cookie_string()
  -- 1. Prioritize manually configured cookie_string
  if config.cookie_string and config.cookie_string ~= "" then
    return config.cookie_string
  end

  -- 2. Fallback to environment variable
  local cookie_env = os.getenv("LEETCODE_COOKIE_STRING")
  if cookie_env and cookie_env ~= "" then
    return cookie_env
  end

  -- 3. Fallback to automatic browser detection
  local browser_cookies = get_cookies_from_browser()
  if browser_cookies and browser_cookies.LEETCODE_SESSION and browser_cookies.csrftoken then
    return string.format("LEETCODE_SESSION=%s; csrftoken=%s", browser_cookies.LEETCODE_SESSION, browser_cookies.csrftoken)
  end

  return nil
end

function M.get(url)
  local cookie_string = get_cookie_string()
  if not cookie_string then
    vim.notify("LeetCode cookies are not configured. Please set 'cookie_string' in setup.", vim.log.levels.ERROR)
    return ""
  end

  local command = string.format(
    "curl -sL --compressed " ..
    "-H 'accept: */*' " ..
    "-H 'accept-language: en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7' " ..
    "-H 'cache-control: no-cache' " ..
    "--cookie %s " ..
    "-H 'dnt: 1' " ..
    "-H 'pragma: no-cache' " ..
    "-H 'priority: u=1, i' " ..
    "-H 'sec-ch-ua: \"Google Chrome\";v=\"143\", \"Chromium\";v=\"143\", \"Not A(Brand\";v=\"24\"' " ..
    "-H 'sec-ch-ua-mobile: ?0' " ..
    "-H 'sec-ch-ua-platform: \"Linux\"' " ..
    "-H 'sec-fetch-dest: empty' " ..
    "-H 'sec-fetch-mode: cors' " ..
    "-H 'sec-fetch-site: same-origin' " ..
    "-H 'sec-gpc: 1' " ..
    "-H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36' " ..
    "%s",
    vim.fn.shellescape(cookie_string),
    vim.fn.shellescape(url)
  )
  return vim.fn.system(command)
end

function M.post(url, body)
  local cookie_string = get_cookie_string()
  if not cookie_string then
    vim.notify("LeetCode cookies are not configured. Please set 'cookie_string' in setup.", vim.log.levels.ERROR)
    return ""
  end

  -- Extract csrftoken from the cookie string for the x-csrftoken header
  local csrf_token = nil
  if cookie_string then
    csrf_token = string.match(cookie_string, "csrftoken=([^;]+)")
  end

  if not csrf_token then
    vim.notify("Could not find 'csrftoken' in your cookie_string. It is required for submitting.", vim.log.levels.ERROR)
    return ""
  end

  local referer_header = ""
  if url:match("/problems/") then
    local referer_url = url:gsub("/submit/$", "/description/"):gsub("/test/$", "/description/")
    referer_header = string.format("-H 'referer: %s' ", referer_url)
  end

  local command = string.format(
    "curl -sL --compressed -X POST " ..
    "-H 'accept: */*' " ..
    "-H 'accept-language: en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7' " ..
    "-H 'cache-control: no-cache' " ..
    "-H 'content-type: application/json' " ..
    "--cookie %s " ..
    "-H 'dnt: 1' " ..
    "-H 'origin: https://leetcode.com' " ..
    "-H 'pragma: no-cache' " ..
    "-H 'priority: u=1, i' " ..
    referer_header ..
    "-H 'sec-ch-ua: \"Google Chrome\";v=\"143\", \"Chromium\";v=\"143\", \"Not A(Brand\";v=\"24\"' " ..
    "-H 'sec-ch-ua-mobile: ?0' " ..
    "-H 'sec-ch-ua-platform: \"Linux\"' " ..
    "-H 'sec-fetch-dest: empty' " ..
    "-H 'sec-fetch-mode: cors' " ..
    "-H 'sec-fetch-site: same-origin' " ..
    "-H 'sec-gpc: 1' " ..
    "-H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36' " ..
    "-H 'x-csrftoken: %s' " ..
    "-d %s %s",
    vim.fn.shellescape(cookie_string),
    csrf_token,
    vim.fn.shellescape(body),
    vim.fn.shellescape(url)
  )
  return vim.fn.system(command)
end

return M