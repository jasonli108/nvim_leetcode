-- local http = require('http')

local http = require('nvim-leetcode.http')

local M = {}

local problems_list = {}
local current_problem = {}
local config = {
  preferred_language = 'python3',
  endpoint = 'https://leetcode.com/graphql',
  -- How to get csrf_token and cookie:
  -- 1. Login to LeetCode in your browser
  -- 2. Open the developer tools (F12)
  -- 3. Go to the Network tab
  -- 4. Find a request to the graphql endpoint
  -- 5. In the request headers, find the 'x-csrftoken' and 'cookie' values
  csrf_token = '',
  cookie = '',
}

local function check_submission_status(submission_id)
  local timer = vim.loop.new_timer()
  local check_count = 0
  local function check()
    check_count = check_count + 1
    if check_count > 10 then
      timer:stop()
      print('Timeout checking submission status')
      return
    end

    local url = string.gsub(config.endpoint, 'graphql', 'submissions/' .. submission_id .. '/check')
    http.request({
      method = 'GET',
      url = url,
      headers = {
        ['Content-Type'] = 'application/json',
        ['x-csrftoken'] = config.csrf_token,
        ['Cookie'] = config.cookie,
      },
    }, function(resp, err) 
      if err then
        timer:stop()
        print('Error checking submission status: ' .. err)
        return
      end

      local result = http.json_decode(resp.body)
      if result.state == 'SUCCESS' then
        timer:stop()
        vim.schedule(function() 
          local result_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_option(result_buf, 'bufhidden', 'wipe')
          local lines = {
            'Submission Result:',
            'Status: ' .. result.status_display,
            'Runtime: ' .. result.status_runtime,
            'Memory: ' .. result.status_memory,
          }
          vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, lines)
          local width = 40
          local height = 5
          local row = (vim.o.lines - height) / 2
          local col = (vim.o.columns - width) / 2
          vim.api.nvim_open_win(result_buf, true, {
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
            style = 'minimal',
            border = 'rounded',
          })
        end)
      end
    end)
  end

  timer:start(1000, 1000, check)
end

local function create_solution_buffer(problem_details)
  local code_definitions = http.json_decode(problem_details.data.question.codeDefinition)
  local selected_lang
  local selected_code

  for _, def in ipairs(code_definitions) do
    if def.value == config.preferred_language then
      selected_lang = def.value
      selected_code = def.defaultCode
      break
    end
  end

  if not selected_lang then
    selected_lang = code_definitions[1].value
    selected_code = code_definitions[1].defaultCode
  end


  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(selected_code, '\n'))
  vim.api.nvim_buf_set_option(buf, 'filetype', selected_lang)
  vim.cmd('vsplit')
  vim.api.nvim_set_current_buf(buf)
end

local function display_problem_details(problem_details)
  current_problem = problem_details.data.question
  local content = current_problem.content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 80
  local height = 30
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<Cmd>close<CR>', { noremap = true, silent = true })
  create_solution_buffer(problem_details)
end

local function display_problems(problems)
  problems_list = problems.data.allQuestions
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  local lines = {}
  for _, problem in ipairs(problems_list) do
    table.insert(lines, string.format('%s. %s (%s)', problem.questionId, problem.title, problem.difficulty))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 80
  local height = 20
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<Cmd>close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Enter>', '<Cmd>lua require("nvim-leetcode").select_problem()<CR>', { noremap = true, silent = true })
end

function M.submit_solution()
  local solution = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  local questionId = http.json_decode(current_problem.stats).question_id
  local titleSlug = current_problem.metaData.name
  local lang = vim.bo.filetype

  local url = string.gsub(config.endpoint, 'graphql', 'problems/' .. titleSlug .. '/submit')

  http.request({
    method = 'POST',
    url = url,
    headers = {
      ['Content-Type'] = 'application/json',
      ['x-csrftoken'] = config.csrf_token,
      ['Cookie'] = config.cookie,
    },
    body = http.json_encode({
      question_id = questionId,
      lang = lang,
      typed_code = solution,
    }),
  }, function(resp, err) 
    if err then
      print('Error submitting solution: ' .. err)
      return
    end

    local submission = http.json_decode(resp.body)
    if submission.submission_id then
      check_submission_status(submission.submission_id)
    else
      print('Error submitting solution: ' .. resp.body)
    end
  end)
end

function M.get_problem_details(titleSlug)
  local graphql_query = string.format([[ 
    query { 
      question(titleSlug: "%s") {
        content
        stats
        codeDefinition
        sampleTestCase
        enableRunCode
        metaData
      }
    }
  ]], titleSlug)

  http.request({
    method = 'POST',
    url = config.endpoint,
    headers = {
      ['Content-Type'] = 'application/json',
    },
    body = http.json_encode({ query = graphql_query }),
  }, function(resp, err) 
    if err then
      print('Error fetching problem details: ' .. err)
      return
    end

    local problem_details = http.json_decode(resp.body)
    vim.schedule(function() 
      display_problem_details(problem_details)
    end)
  end)
end

function M.select_problem()
  local line = vim.api.nvim_get_current_line()
  local problem_id_str = line:match('^%d+')
  if not problem_id_str then
    return
  end
  local problem_id = tonumber(problem_id_str)

  local selected_problem
  for _, problem in ipairs(problems_list) do
    if tonumber(problem.questionId) == problem_id then
      selected_problem = problem
      break
    end
  end

  if selected_problem then
    M.get_problem_details(selected_problem.titleSlug)
  end
end

function M.get_problems()
  local graphql_query = [[ 
    query {
      allQuestions {
        questionId
        title
        titleSlug
        difficulty
      }
    }
  ]]

  http.request({
    method = 'POST',
    url = config.endpoint,
    headers = {
      ['Content-Type'] = 'application/json',
    },
    body = http.json_encode({ query = graphql_query }),
  }, function(resp, err) 
    if err then
      print('Error fetching problems: ' .. err)
      return
    end

    local problems = http.json_decode(resp.body)
    vim.schedule(function() 
      display_problems(problems)
    end)
  end)
end




-- The public LeetCode API endpoint for getting all problems
local PROBLEMS_API_URL = "https://leetcode.com/api/problems/all/"

function M.list_problems()
  print("Fetching LeetCode problems, please wait...")

  -- 2. Use vim.schedule to run the network request asynchronously.
  -- This is important to prevent the UI from freezing while waiting for the API.
  vim.schedule(function()
    local response_body = http.get(PROBLEMS_API_URL)

    if response_body and response_body ~= "" then
      -- 3. Decode the JSON response into a Lua table
      local problems_data = vim.fn.json_decode(response_body)

      if problems_data and problems_data.stat_status_pairs then
        local num_problems = #problems_data.stat_status_pairs
        vim.notify("Successfully fetched " .. num_problems .. " problems.", vim.log.levels.INFO)

        -- For now, let's just print the title of the first problem as a test
        local first_problem_title = problems_data.stat_status_pairs[1].stat.question__title
        print("Example problem: " .. first_problem_title)

        -- The next step will be to display this data in a proper list.
      else
        vim.notify("Failed to parse the problem data from LeetCode's API.", vim.log.levels.ERROR)
      end
    else
      vim.notify("Failed to fetch data from LeetCode API. The response was empty.", vim.log.levels.ERROR)
    end
  end)
end

function M.setup(opts)
  -- We can remove the debug message now that we know it's working.
  vim.api.nvim_create_user_command(
    'LeetCodeList',
    M.list_problems,
    {
      nargs = 0,
      desc = 'Fetch and list LeetCode problems',
    }
  )
end

return M
