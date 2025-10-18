-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode.lua

local M = {}
local http = require('nvim-leetcode.http')

local PROBLEMS_API_URL = "https://leetcode.com/api/problems/all/"
local GRAPHQL_API_URL = "https://leetcode.com/graphql"

local QUESTION_QUERY_TEMPLATE = [[
query questionData($titleSlug: String!) {
  question(titleSlug: $titleSlug) {
    content
    questionId
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

local full_problem_list_cache = {}
local displayed_problem_list_cache = {}
local current_filter = "All"

-- FIX: Forward-declare the function so it can be called before it's fully defined.
local fetch_and_show_question

local function get_difficulty(level)
  if level == 1 then return "Easy" end
  if level == 2 then return "Medium" end
  if level == 3 then return "Hard" end
  return "Unknown"
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

  local lines = {
    "Filter: [" .. current_filter .. "] (a:All, e:Easy, m:Medium, h:Hard | q:Quit, <CR>:Select)",
    "--------------------------------------------------------------------------",
  }
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
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', {
      noremap = true,
      silent = true,
      callback = function()
        current_filter = filter_name
        redraw_problem_list(buf)
      end,
    })
  end

  create_filter_keymap('a', "All")
  create_filter_keymap('e', "Easy")
  create_filter_keymap('m', "Medium")
  create_filter_keymap('h', "Hard")
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
    noremap = true,
    silent = true,
    callback = function()
      local line_num = vim.api.nvim_win_get_cursor(0)[1]
      local problem_index = line_num - 2
      if displayed_problem_list_cache[problem_index] then
        local slug = displayed_problem_list_cache[problem_index].stat.question__title_slug
        fetch_and_show_question(slug)
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

local function display_question_in_buffer(data)
  local question = data.question
  if not question then
    vim.notify("Could not find question data in API response.", vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local lines = { "--- LeetCode Problem ---", "ID: " .. question.questionId, "Title: " .. question.title, "Difficulty: " .. question.difficulty, "------------------------", "" }
  if type(question.content) == "string" then
    vim.list_extend(lines, vim.split(question.content, "\n"))
  else
    table.insert(lines, "(No description available - this might be a premium question)")
  end
  table.insert(lines, "")
  table.insert(lines, "--- Code Snippet ---")
  local snippet_to_use = ""
  local snippet_lang = "text"
  if question.codeSnippets then
    for _, snippet in ipairs(question.codeSnippets) do
      if snippet.langSlug == 'lua' then
        snippet_to_use = snippet.code
        snippet_lang = 'lua'
        break
      elseif snippet.langSlug == 'python' then
        snippet_to_use = snippet.code
        snippet_lang = 'python'
      end
    end
  end
  if type(snippet_to_use) == "string" and snippet_to_use ~= "" then
    vim.list_extend(lines, vim.split(snippet_to_use, "\n"))
  else
    table.insert(lines, "(No code snippet available)")
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', snippet_lang)
end

-- The function is now assigned to the pre-declared local variable
fetch_and_show_question = function(title_slug)
  vim.notify("Fetching question: " .. title_slug, vim.log.levels.INFO)
  local body = vim.fn.json_encode({ query = QUESTION_QUERY_TEMPLATE, variables = { titleSlug = title_slug } })
  vim.schedule(function()
    local response_body = http.post(GRAPHQL_API_URL, body)
    if response_body and response_body ~= "" then
      local data = vim.fn.json_decode(response_body)
      if data and data.data then
        display_question_in_buffer(data.data)
      else
        vim.notify("Failed to parse question data. Response might be invalid.", vim.log.levels.ERROR)
        print(vim.inspect(data))
      end
    else
      vim.notify("Failed to fetch question details. Response was empty.", vim.log.levels.ERROR)
    end
  end)
end

function M.list_problems()
  vim.notify("Fetching LeetCode problems...", vim.log.levels.INFO)
  vim.schedule(function()
    local response_body = http.get(PROBLEMS_API_URL)
    if response_body and response_body ~= "" then
      local problems_data = vim.fn.json_decode(response_body)
      if problems_data and problems_data.stat_status_pairs then
        show_problems_in_float(problems_data.stat_status_pairs)
      else
        vim.notify("Failed to parse problem data from LeetCode API.", vim.log.levels.ERROR)
      end
    else
      vim.notify("Failed to fetch data from LeetCode API. Response was empty.", vim.log.levels.ERROR)
    end
  end)
end

function M.setup(opts)
  vim.api.nvim_create_user_command('LeetCodeList', M.list_problems, { nargs = 0, desc = 'Fetch and list LeetCode problems' })
end

return M
