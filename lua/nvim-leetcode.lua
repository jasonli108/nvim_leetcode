-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode.lua

local M = {}

local last_fetched_question_id = nil

local function get_plugin_root()
  local str = debug.getinfo(1, "S").source
  if str:sub(1, 1) == "@" then
    str = str:sub(2)
  end
  return vim.fn.fnamemodify(str, ":p:h:h")
end

local config = {
  python_executable = "python3",
  venv_activate_path = get_plugin_root() .. "/.venv",
}

local http = require('nvim-leetcode.http')

local PROBLEMS_API_URL = "https://leetcode.com/api/problems/all/"
local GRAPHQL_API_URL = "https://leetcode.com/graphql"
local SUBMIT_API_URL = "https://leetcode.com/problems/%s/submit/"
local CHECK_API_URL = "https://leetcode.com/submissions/detail/%s/check/"

local QUESTION_QUERY_TEMPLATE = [[
query questionData($titleSlug: String!) {
  question(titleSlug: $titleSlug) {
    content
    questionId
    questionFrontendId
    title
    difficulty
    codeSnippets {
      lang
      langSlug
      code
    }
  }
}
]]

local function check_submission_status(submission_id)
  local check_url = string.format(CHECK_API_URL, submission_id)
  local timer = vim.loop.new_timer()

  local function check()
    local response_body = http.get(check_url)
    if response_body and response_body ~= "" and string.sub(response_body, 1, 1) == "{" then
      local data = vim.fn.json_decode(response_body)
      if not data then
        vim.notify("Failed to parse submission status.", vim.log.levels.ERROR)
        timer:close()
        return
      end

      -- FIX: Handle cases where status_display might be nil
      local status_msg = data.status_display or data.state or "Pending..."

      if data.state == "SUCCESS" then
        vim.notify("Submission finished: " .. status_msg, vim.log.levels.INFO)
        timer:close()
      elseif data.state == "FAILURE" then
        vim.notify("Submission failed: " .. status_msg, vim.log.levels.ERROR)
        timer:close()
      else
        vim.notify("Submission status: " .. status_msg, vim.log.levels.INFO)
      end
    else
      vim.notify("Failed to check submission status.", vim.log.levels.ERROR)
      timer:close()
    end
  end

  timer:start(0, 2000, vim.schedule_wrap(check))
end

function M.submit_solution()
  local buf = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(buf)
  local title_slug = vim.fn.fnamemodify(filename, ":t:r"):gsub("_", "-")

  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local start_line = -1
  for i, line in ipairs(all_lines) do
    if line:match("^class Solution:") then
      start_line = i - 1 -- 0-indexed
      break
    end
  end

  if start_line == -1 then
    vim.notify("Could not find 'class Solution:' in the buffer.", vim.log.levels.ERROR)
    return
  end

  local code_lines = vim.api.nvim_buf_get_lines(buf, start_line, -1, false)
  local source_code = table.concat(code_lines, "\n")

  local submit_url = string.format(SUBMIT_API_URL, title_slug)

  local question_id = vim.b[buf].leetcode_question_id

  if not question_id then
    vim.notify("Warning: Could not find question ID on buffer. Using last opened question ID as a fallback.", vim.log.levels.WARN)
    question_id = last_fetched_question_id
  end

  if not question_id then
    vim.notify("Could not determine Question ID. Please open a problem first.", vim.log.levels.ERROR)
    return
  end

  local body = vim.fn.json_encode({
    lang = "python3",
    question_id = question_id,
    typed_code = source_code,
  })

  vim.notify("Submitting solution for: " .. title_slug, vim.log.levels.INFO)
  vim.schedule(function()
    local response_body = http.post(submit_url, body)
    if response_body and response_body ~= "" then
      if string.sub(response_body, 1, 1) == "{" then
        local data = vim.fn.json_decode(response_body)
        if data and data.submission_id then
          vim.notify("Submission ID: " .. data.submission_id, vim.log.levels.INFO)
          check_submission_status(data.submission_id)
        else
          vim.notify("Submission failed or is pending. API Response:", vim.log.levels.ERROR)
          print(vim.inspect(data))
        end
      else
        vim.notify("Submission failed. The server returned a non-JSON response (details below).", vim.log.levels.ERROR)
        print(response_body)
      end
    else
      vim.notify("Failed to submit solution. Response was empty.", vim.log.levels.ERROR)
    end
  end)
end

local full_problem_list_cache = {}
local displayed_problem_list_cache = {}
local current_filter = "All"
local fetch_and_show_question

local function clean_html(html_string)
  if type(html_string) ~= "string" then
    return ""
  end
  local s = html_string
  s = s:gsub("<p>", ""):gsub("</p>", " ")
  s = s:gsub("<li>", "- "):gsub("</li>", " ")
  s = s:gsub("<strong>", ""):gsub("</strong>", "")
  s = s:gsub("<em>", ""):gsub("</em>", "")
  s = s:gsub("<code>", "`"):gsub("</code>", " ")
  s = s:gsub("<pre>", " "):gsub("</pre>", " ")
  s = s:gsub("<[^>]+>", "")
  s = s:gsub("&nbsp;", " "); s = s:gsub("&lt;", "<"); s = s:gsub("&gt;", ">")
  s = s:gsub("&quot;", "\""); s = s:gsub("&#39;", "'"); s = s:gsub("&amp;", "&")
  s = s:gsub("%s+", " ")
  return s:match("^%s*(.-)%s*$")
end

local function word_wrap(text, line_width)
  line_width = line_width or 158
  local lines = {}
  local current_line = ""

  for word in text:gmatch("%S+") do
    if #current_line + #word + 1 > line_width then
      table.insert(lines, current_line)
      current_line = word
    else
      if current_line == "" then
        current_line = word
      else
        current_line = current_line .. " " .. word
      end
    end
  end
  if current_line ~= "" then
    table.insert(lines, current_line)
  end
  return lines
end

  local function get_difficulty(level)
    if level == 1 then return "Easy" end
    if level == 2 then return "Medium" end
    if level == 3 then return "Hard" end
    return "Unknown"
  end

  local function display_question_in_buffer(data)
    local question = data.question
    if not question then
      vim.notify("Could not find question data in API response.", vim.log.levels.ERROR)
      return
    end

    local qid = question.questionFrontendId or question.questionId

    if not qid then
      vim.notify("Could not extract a valid Question ID from LeetCode's response.", vim.log.levels.ERROR)
      return
    end

    last_fetched_question_id = qid

    local safe_slug = question.titleSlug
    if not safe_slug or type(safe_slug) ~= "string" then
      safe_slug = question.title:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
    end

    local filename = safe_slug:gsub("-", "_") .. ".py"

    local python_snippet = ""
    if question.codeSnippets then
      for _, snippet in ipairs(question.codeSnippets) do
        if snippet.langSlug == 'python3' or snippet.langSlug == 'python' then
          python_snippet = snippet.code
          break
        end
      end
    end
    if python_snippet == "" then
      vim.notify("No Python code snippet found for this problem.", vim.log.levels.WARN)
    end

    local file_content = { '"""' }
    local description_header = {
      "ID: " .. qid,
      "Title: " .. question.title,
      "Difficulty: " .. question.difficulty,
      "URL: https://leetcode.com/problems/" .. safe_slug,
      "--------------------------------------------------------------------------",
      "",
    }
    vim.list_extend(file_content, description_header)
    local wrapped_content = word_wrap(clean_html(question.content))
    vim.list_extend(file_content, wrapped_content)
    table.insert(file_content, '"""')
    local snippet_lines = vim.split(python_snippet, "\n")
    vim.list_extend(file_content, snippet_lines)

    local bufnr = vim.fn.bufnr('^' .. filename .. '$')
    if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_set_current_buf(bufnr)
    else
      vim.cmd('enew')
      vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), filename)
    end

    local buf = vim.api.nvim_get_current_buf()
    vim.b[buf].leetcode_question_id = qid

    vim.api.nvim_buf_set_option(buf, 'readonly', false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'python')
  end

  local function redraw_problem_list(buf)
    displayed_problem_list_cache = {}
    if current_filter == "All" then
      displayed_problem_list_cache = full_problem_list_cache
    else
      for _, problem in ipairs(full_problem_list_cache) do
        if get_difficulty(problem.difficulty.level) == current_filter then
          table.insert(displayed_problem_list_cache, problem)
        end
      end
    end
    local lines = { "Filter: [" .. current_filter .. "] (a:All, e:Easy, m:Medium, h:Hard | q:Quit, <CR>:Select)", "--------------------------------------------------------------------------" }
    for _, problem in ipairs(displayed_problem_list_cache) do
      local stat = problem.stat
      local difficulty = get_difficulty(problem.difficulty.level)
      local line = string.format("[%d] %s (%s)", stat.frontend_question_id, stat.question__title, difficulty)
      table.insert(lines, line)
    end
    vim.api.nvim_buf_set_option(buf, 'readonly', false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)
  end

  local function show_problems_in_float(problems)
    full_problem_list_cache = problems
    current_filter = "All"
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    redraw_problem_list(buf)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    local opts = { relative = 'editor', width = width, height = height, row = row, col = col, style = 'minimal', border = 'rounded' }
    local win = vim.api.nvim_open_win(buf, true, opts)
    local function create_filter_keymap(key, filter_name)
      vim.api.nvim_buf_set_keymap(buf, 'n', key, '', { noremap = true, silent = true, callback = function() current_filter = filter_name; redraw_problem_list(buf) end })
    end
    create_filter_keymap('a', "All")
    create_filter_keymap('e', "Easy")
    create_filter_keymap('m', "Medium")
    create_filter_keymap('h', "Hard")
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', { noremap = true, silent = true, callback = function()
      local line_num = vim.api.nvim_win_get_cursor(0)[1]
      local problem_index = line_num - 2
      if displayed_problem_list_cache[problem_index] then
        local slug = displayed_problem_list_cache[problem_index].stat.question__title_slug
        fetch_and_show_question(slug)
        vim.api.nvim_win_close(win, true)
      end
    end })
  end

  function M.get_problems()
    vim.notify("Fetching problem list from LeetCode...", vim.log.levels.INFO)
    vim.schedule(function()
      local response_body = http.get(PROBLEMS_API_URL)
      if response_body and response_body ~= "" then
        local data = vim.fn.json_decode(response_body)
        if data and data.stat_status_pairs then
          show_problems_in_float(data.stat_status_pairs)
        else
          vim.notify("Could not parse problem list from API response.", vim.log.levels.ERROR)
        end
      else
        vim.notify("Failed to fetch problem list. Response was empty.", vim.log.levels.ERROR)
      end
    end)
  end

  fetch_and_show_question = function(slug)
    vim.notify("Fetching question: " .. slug, vim.log.levels.INFO)
    local body = vim.fn.json_encode({
      query = QUESTION_QUERY_TEMPLATE,
      variables = { titleSlug = slug },
    })
    vim.schedule(function()
      local response_body = http.post(GRAPHQL_API_URL, body)
      if response_body and response_body ~= "" then
        local data = vim.fn.json_decode(response_body)
        if data and data.data then
          display_question_in_buffer(data.data)
        else
          vim.notify("Could not parse question data from API response.", vim.log.levels.ERROR)
          print(vim.inspect(data))
        end
      else
        vim.notify("Failed to fetch question. Response was empty.", vim.log.levels.ERROR)
      end
    end)
  end

  function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
    http.setup(config)
    vim.api.nvim_create_user_command('LeetCode', M.get_problems, {})
    vim.api.nvim_create_user_command('LeetCodeSubmit', M.submit_solution, {})
  end

  return M
