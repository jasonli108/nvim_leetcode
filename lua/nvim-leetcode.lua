-- /home/yuheng108/CS/nvim_leetcode/lua/nvim-leetcode.lua

local M = {}

local function split_and_insert(lines, text)
	if text then
		if type(text) ~= "string" then
			text = tostring(text)
		end
		for _, line in ipairs(vim.split(text, "\n")) do
			table.insert(lines, line)
		end
	end
end

local function get_lang_extension(lang_name)
	local lang_map = {
		["python3"] = "py",
		["python"] = "py",
		["cpp"] = "cpp",
		["c"] = "c",
		["java"] = "java",
		["javascript"] = "js",
		["typescript"] = "ts",
		["csharp"] = "cs",
		["go"] = "go",
		["ruby"] = "rb",
		["swift"] = "swift",
		["kotlin"] = "kt",
		["rust"] = "rs",
		["php"] = "php",
		["scala"] = "scala",
	}
	return lang_map[lang_name:lower()] or "txt"
end

local function get_comment_prefix(lang_name)
	local comment_map = {
		["python3"] = "#",
		["python"] = "#",
		["cpp"] = "//",
		["c"] = "//",
		["java"] = "//",
		["javascript"] = "//",
		["typescript"] = "//",
		["csharp"] = "//",
		["go"] = "//",
		["ruby"] = "#",
		["swift"] = "//",
		["kotlin"] = "//",
		["rust"] = "//",
		["php"] = "//",
		["scala"] = "//",
		["lua"] = "--", -- Although not expected for submission, good to have.
	}
	return comment_map[lang_name:lower()] or "--" -- Default to Lua comment if unknown
end

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
	username = os.getenv("LEETCODE_USERNAME"),
}

local http = require("nvim-leetcode.http")

local PROBLEMS_API_URL = "https://leetcode.com/api/problems/all/"
local GRAPHQL_API_URL = "https://leetcode.com/graphql"
local SUBMIT_API_URL = "https://leetcode.com/problems/%s/submit/"
local CHECK_API_URL = "https://leetcode.com/submissions/detail/%s/check/"

local QUESTION_QUERY_TEMPLATE = [=[
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
]=]

local PROGRESS_QUERY_TEMPLATE = [=[
query userProblemsSolved($username: String!) {
  allQuestionsCount {
    difficulty
    count
  }
  matchedUser(username: $username) {
    problemsSolvedBeatsStats {
      difficulty
      percentage
    }
    submitStatsGlobal {
      acSubmissionNum {
        difficulty
        count
      }
    }
  }
}
]=]

local HISTORY_QUERY_TEMPLATE = [=[
query submissionList($offset: Int!, $limit: Int!, $questionSlug: String) {
  submissionList(offset: $offset, limit: $limit, questionSlug: $questionSlug) {
    lastKey
    hasNext
    submissions {
      id
      title
      titleSlug
      timestamp
      statusDisplay
    }
  }
}
]=]

local SUBMISSION_DETAILS_QUERY_TEMPLATE = [=[
query submissionDetails($submissionId: Int!) {
  submissionDetails(submissionId: $submissionId) {
    runtimeDisplay
    memoryDisplay
    lang {
      name
    }
    question {
      titleSlug
      title
    }
    runtime
    memory
    code
    timestamp
    totalCorrect
    totalTestcases
    notes
    runtimeError
    compileError
    lastTestcase
    codeOutput
    expectedOutput
    totalCorrect
    totalTestcases
    fullCodeOutput
    testDescriptions
    testBodies
    testInfo
    stdOutput
  }
}
]=]

local function display_history_in_buffer(submissions)
	local lines = { "Practice History", "------------------" }

	local latest_submissions = {}
	for _, submission in ipairs(submissions) do
		local slug = submission.titleSlug
		if
			not latest_submissions[slug]
			or tonumber(submission.timestamp) > tonumber(latest_submissions[slug].timestamp)
		then
			latest_submissions[slug] = submission
		end
	end

	local sorted_submissions = {}
	for _, submission in pairs(latest_submissions) do
		table.insert(sorted_submissions, submission)
	end

	table.sort(sorted_submissions, function(a, b)
		return tonumber(a.timestamp) > tonumber(b.timestamp)
	end)

	for _, submission in ipairs(sorted_submissions) do
		local date = os.date("%Y-%m-%d %H:%M:%S", tonumber(submission.timestamp))
		table.insert(lines, string.format("[%s] %s - %s", date, submission.title, submission.statusDisplay))
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "readonly", true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "Practice History",
	}
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Close window with 'q'
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			local line_num = vim.api.nvim_win_get_cursor(0)[1]
			local submission_index = line_num - 2
			if sorted_submissions[submission_index] then
				local submission_id = sorted_submissions[submission_index].id
				M.get_submission_details(submission_id)
				vim.api.nvim_win_close(win, true)
			end
		end,
	})
end

local function find_buf_by_name(name)
	local bufs = vim.api.nvim_list_bufs()
	for _, buf in ipairs(bufs) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):match(name .. "$") then
			return buf
		end
	end
	return nil
end

local function display_submission_results(details)
	local lines = { "Submission Details", "------------------" }
	table.insert(lines, "Status: " .. details.runtimeDisplay)
	table.insert(lines, "Language: " .. details.lang.name)
	table.insert(lines, "Runtime: " .. details.runtime)
	table.insert(lines, "Memory: " .. details.memory)
	if details.totalCorrect and details.totalTestcases then
		table.insert(lines, string.format("Test Cases: %d / %d", details.totalCorrect, details.totalTestcases))
	end
	if details.runtimeError and details.runtimeError ~= "" then
		table.insert(lines, "------------------")
		table.insert(lines, "Runtime Error:")
		split_and_insert(lines, details.runtimeError)
	end
	if details.notes and details.notes ~= "" then
		table.insert(lines, "------------------")
		table.insert(lines, "Notes:")
		split_and_insert(lines, details.notes)
	end
	if details.lastTestcase and details.lastTestcase ~= "" then
		local success, last_testcase_data = pcall(vim.fn.json_decode, details.lastTestcase)
		if success and last_testcase_data then
			table.insert(lines, "------------------")
			table.insert(lines, "Last Test Case:")
			table.insert(lines, "Input:")
			split_and_insert(lines, last_testcase_data.input)
			table.insert(lines, "Expected:")
			split_and_insert(lines, last_testcase_data.expected_output)
			table.insert(lines, "Actual:")
			split_and_insert(lines, last_testcase_data.code_output)
		else
			table.insert(lines, "------------------")
			table.insert(lines, "Last Test Case (raw):")
			split_and_insert(lines, details.lastTestcase)
		end
	end
	table.insert(lines, "------------------")
	table.insert(lines, "Code:")
	table.insert(lines, "------------------")

	-- Add comments to all lines before the "Code:" section
	local comment_prefix = get_comment_prefix(details.lang.name)
	local code_section_start_index = #lines - 1 -- "Code:" is the second to last element added before this point.
	for i = 1, code_section_start_index do
		lines[i] = comment_prefix .. " " .. lines[i]
	end

	local code_lines = vim.split(details.code, "\n")
	vim.list_extend(lines, code_lines)

	local extension = get_lang_extension(details.lang.name)
	local filename = details.question.titleSlug:gsub("-", "_") .. "." .. extension

	local buf = find_buf_by_name(filename)
	if not buf then
		buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, filename)
	end

	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "readonly", true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.bo[buf].filetype = extension
	vim.cmd("vs | buffer " .. buf)
end

function M.get_submission_details(submission_id)
	vim.notify("Fetching submission details for " .. submission_id .. "...", vim.log.levels.INFO)
	local body = vim.fn.json_encode({
		query = SUBMISSION_DETAILS_QUERY_TEMPLATE,
		variables = { submissionId = tonumber(submission_id) },
	})
	vim.schedule(function()
		local response_body = http.post(GRAPHQL_API_URL, body)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.data and data.data.submissionDetails then
				display_submission_results(data.data.submissionDetails)
			else
				vim.notify("Could not parse submission details from API response.", vim.log.levels.ERROR)
				print(vim.inspect(data))
			end
		else
			vim.notify("Failed to fetch submission details. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

function M.get_practice_history()
	if not config.username then
		vim.notify("LeetCode username is not configured. Please set it in the setup function.", vim.log.levels.ERROR)
		return
	end

	vim.notify("Fetching practice history for " .. config.username .. "...", vim.log.levels.INFO)

	local all_submissions = {}
	local pages_to_fetch = 5
	local submissions_per_page = 20

	local function fetch_page(offset)
		local body = vim.fn.json_encode({
			query = HISTORY_QUERY_TEMPLATE,
			variables = {
				offset = offset,
				limit = submissions_per_page,
				questionSlug = "",
			},
		})

		local response_body = http.post(GRAPHQL_API_URL, body)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.data and data.data.submissionList then
				return data.data.submissionList
			else
				vim.notify("Could not parse practice history from API response.", vim.log.levels.ERROR)
				print(vim.inspect(data))
				return nil
			end
		else
			vim.notify("Failed to fetch practice history. Response was empty.", vim.log.levels.ERROR)
			return nil
		end
	end

	vim.schedule(function()
		for i = 0, pages_to_fetch - 1 do
			local offset = i * submissions_per_page
			local submission_list = fetch_page(offset)
			if submission_list and submission_list.submissions then
				for _, submission in ipairs(submission_list.submissions) do
					table.insert(all_submissions, submission)
				end
				if not submission_list.hasNext then
					break
				end
			else
				break
			end
		end
		display_history_in_buffer(all_submissions)
	end)
end

local function display_progress_in_buffer(data)
	local lines = { "LeetCode Progress", "-------------------" }

	local ac_submission_num = data.matchedUser.submitStatsGlobal.acSubmissionNum
	local all_questions_count = data.allQuestionsCount
	local problems_solved_beats_stats = data.matchedUser.problemsSolvedBeatsStats

	local solved_map = {}
	for _, item in ipairs(ac_submission_num) do
		solved_map[item.difficulty] = item.count
	end

	local total_map = {}
	for _, item in ipairs(all_questions_count) do
		total_map[item.difficulty] = item.count
	end

	local beats_map = {}
	for _, item in ipairs(problems_solved_beats_stats) do
		beats_map[item.difficulty] = item.percentage
	end

	local difficulties = { "All", "Easy", "Medium", "Hard" }
	for _, difficulty in ipairs(difficulties) do
		local solved = solved_map[difficulty] or 0
		local total = total_map[difficulty] or 0
		local beats = tonumber(beats_map[difficulty])
		if beats then
			table.insert(lines, string.format("%s: %d/%d (Beats %%%.2f)", difficulty, solved, total, beats))
		else
			table.insert(lines, string.format("%s: %d/%d", difficulty, solved, total))
		end
	end

	local width = math.floor(vim.o.columns * 0.6)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "readonly", true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "LeetCode Progress",
	}
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Close window with 'q'
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
end

function M.get_progress()
	if not config.username then
		vim.notify("LeetCode username is not configured. Please set it in the setup function.", vim.log.levels.ERROR)
		return
	end

	vim.notify("Fetching LeetCode progress for " .. config.username .. "...", vim.log.levels.INFO)

	local body = vim.fn.json_encode({
		query = PROGRESS_QUERY_TEMPLATE,
		variables = { username = config.username },
	})

	vim.schedule(function()
		local response_body = http.post(GRAPHQL_API_URL, body)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.data then
				display_progress_in_buffer(data.data)
			else
				vim.notify("Could not parse progress data from API response.", vim.log.levels.ERROR)
				print(vim.inspect(data))
			end
		else
			vim.notify("Failed to fetch progress. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

local full_problem_list_cache = {}
local displayed_problem_list_cache = {}
local current_filter = "All"

local function get_difficulty(level)
	if level == 1 then
		return "Easy"
	end
	if level == 2 then
		return "Medium"
	end
	if level == 3 then
		return "Hard"
	end
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
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_option(buf, "readonly", false)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "readonly", true)
end

function M.get_problems()
	vim.notify("Fetching problem list from LeetCode...", vim.log.levels.INFO)
	vim.schedule(function()
		local response_body = http.get(PROBLEMS_API_URL)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.stat_status_pairs then
				full_problem_list_cache = data.stat_status_pairs
				current_filter = "All"

				local width = math.floor(vim.o.columns * 0.8)
				local height = math.floor(vim.o.lines * 0.8)
				local row = math.floor((vim.o.lines - height) / 2)
				local col = math.floor((vim.o.columns - width) / 2)

				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
				vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

				redraw_problem_list(buf)

				local opts = {
					relative = "editor",
					width = width,
					height = height,
					row = row,
					col = col,
					style = "minimal",
					border = "rounded",
				}
				local win = vim.api.nvim_open_win(buf, true, opts)

				local function create_filter_keymap(key, filter_name)
					vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
						noremap = true,
						silent = true,
						callback = function()
							current_filter = filter_name
							redraw_problem_list(buf)
						end,
					})
				end

				create_filter_keymap("a", "All")
				create_filter_keymap("e", "Easy")
				create_filter_keymap("m", "Medium")
				create_filter_keymap("h", "Hard")
				vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
				vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
					noremap = true,
					silent = true,
					callback = function()
						local line_num = vim.api.nvim_win_get_cursor(0)[1]
						local problem_index = line_num - 2
						if displayed_problem_list_cache[problem_index] then
							local slug = displayed_problem_list_cache[problem_index].stat.question__title_slug
							M.get_question(slug)
							vim.api.nvim_win_close(win, true)
						end
					end,
				})
			else
				vim.notify("Could not parse problem list from API response.", vim.log.levels.ERROR)
			end
		else
			vim.notify("Failed to fetch problem list. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

function M.get_question(slug)
	vim.notify("Fetching question: " .. slug, vim.log.levels.INFO)
	local body = vim.fn.json_encode({
		query = QUESTION_QUERY_TEMPLATE,
		variables = { titleSlug = slug },
	})
	vim.schedule(function()
		local response_body = http.post(GRAPHQL_API_URL, body)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.data and data.data.question then
				local question = data.data.question
				local qid = question.questionFrontendId or question.questionId
				local safe_slug = question.titleSlug
				if not safe_slug or type(safe_slug) ~= "string" then
					safe_slug = question.title:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
				end
				local filename = safe_slug:gsub("-", "_") .. ".py"
				local python_snippet = ""
				if question.codeSnippets then
					for _, snippet in ipairs(question.codeSnippets) do
						if snippet.langSlug == "python3" or snippet.langSlug == "python" then
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
				local content = question.content
				content = content:gsub("<p>", ""):gsub("</p>", " ")
				content = content:gsub("<li>", "- "):gsub("</li>", " ")
				content = content:gsub("<strong>", ""):gsub("</strong>", "")
				content = content:gsub("<em>", ""):gsub("</em>", "")
				content = content:gsub("<code>", "`"):gsub("</code>", " ")
				content = content:gsub("<pre>", " "):gsub("</pre>", " ")
				content = content:gsub("<[^>]+>", "")
				content = content:gsub("&nbsp;", " ")
				content = content:gsub("&lt;", "<")
				content = content:gsub("&gt;", ">")
				content = content:gsub("&quot;", '"')
				content = content:gsub("&#39;", "'")
				content = content:gsub("&amp;", "&")
				content = content:gsub("%s+", " ")
				content = content:match("^%s*(.-)%s*$")

				local lines = {}
				local current_line = ""
				for word in content:gmatch("%S+") do
					if #current_line + #word + 1 > 158 then
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
				vim.list_extend(file_content, lines)
				table.insert(file_content, '"""')
				local snippet_lines = vim.split(python_snippet, "\n")
				vim.list_extend(file_content, snippet_lines)
				local bufnr = vim.fn.bufnr("^" .. filename .. "$")
				if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
					vim.api.nvim_set_current_buf(bufnr)
				else
					vim.cmd("enew")
					vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), filename)
				end
				local buf = vim.api.nvim_get_current_buf()
				vim.b[buf].leetcode_question_id = qid
				vim.api.nvim_buf_set_option(buf, "modifiable", true)
				vim.api.nvim_buf_set_option(buf, "readonly", false)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)
				vim.api.nvim_buf_set_option(buf, "filetype", "python")
				vim.b[buf].leetcode_question_id = qid
			else
				vim.notify("Could not parse question data from API response.", vim.log.levels.ERROR)
				print(vim.inspect(data))
			end
		else
			vim.notify("Failed to fetch question. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

local function append_submission_results_to_buffer(submission_id)
	vim.notify("Fetching submission details for " .. submission_id .. "...", vim.log.levels.INFO)
	local body = vim.fn.json_encode({
		query = SUBMISSION_DETAILS_QUERY_TEMPLATE,
		variables = { submissionId = tonumber(submission_id) },
	})
	vim.schedule(function()
		local response_body = http.post(GRAPHQL_API_URL, body)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.data and data.data.submissionDetails then
				local details = data.data.submissionDetails
				local lines_to_insert = { "", string.rep("-", 80), "" }
				table.insert(lines_to_insert, "Submission Details (ID: " .. submission_id .. ")")
				table.insert(lines_to_insert, "------------------")
				table.insert(lines_to_insert, "Status: " .. details.runtimeDisplay)
				table.insert(lines_to_insert, "Language: " .. details.lang.name)
				table.insert(lines_to_insert, "Runtime: " .. details.runtime)
				table.insert(lines_to_insert, "Memory: " .. details.memory)
				if details.totalCorrect and details.totalTestcases then
					table.insert(
						lines_to_insert,
						string.format("Test Cases: %d / %d", details.totalCorrect, details.totalTestcases)
					)
				end
				table.insert(lines_to_insert, "------------------")
				table.insert(lines_to_insert, "Last Test Case:")
				table.insert(lines_to_insert, "Input:")
				split_and_insert(lines_to_insert, details.lastTestcase)
				table.insert(lines_to_insert, "Expected:")
				split_and_insert(lines_to_insert, details.expectedOutput)
				table.insert(lines_to_insert, "Actual:")
				split_and_insert(lines_to_insert, details.codeOutput)
				table.insert(lines_to_insert, "------------------")
				table.insert(lines_to_insert, "compileError:")
				split_and_insert(lines_to_insert, details.compileError)
				table.insert(lines_to_insert, "fullCodeOutput:")
				split_and_insert(lines_to_insert, details.fullCodeOutput)
				table.insert(lines_to_insert, "runtime:")
				split_and_insert(lines_to_insert, details.runtime)
				table.insert(lines_to_insert, "runtimeDisplay:")
				split_and_insert(lines_to_insert, details.runtimeDisplay)
				table.insert(lines_to_insert, "runtimeError:")
				split_and_insert(lines_to_insert, details.runtimeError)
				table.insert(lines_to_insert, "stdOutput:")
				split_and_insert(lines_to_insert, details.stdOutput)

				local buf = vim.api.nvim_get_current_buf()
				local all_buffer_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				local insertion_line = 0
				for i, line in ipairs(all_buffer_lines) do
					if line:match('^"""$') and i > 1 then -- Find the closing triple quote of the docstring
						insertion_line = i
						break
					end
				end

				if insertion_line == 0 then
					-- Fallback to appending at the end if docstring not found
					insertion_line = #all_buffer_lines
				end

				local comment_prefix = get_comment_prefix(vim.bo[buf].filetype)
				for i, line in ipairs(lines_to_insert) do
					lines_to_insert[i] = comment_prefix .. " " .. line
				end
				vim.api.nvim_buf_set_option(buf, "modifiable", true)
				vim.api.nvim_buf_set_lines(buf, insertion_line, insertion_line, false, lines_to_insert)
				vim.notify("Submission results appended to the current buffer.")
			else
				vim.notify("Could not parse submission details from API response.", vim.log.levels.ERROR)
				print(vim.inspect(data))
			end
		else
			vim.notify("Failed to fetch submission details. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

local function poll_submission_status(submission_id)
	local check_url = string.format(CHECK_API_URL, submission_id)
	local timer = vim.loop.new_timer()
	local attempts = 0
	local max_attempts = 60 -- 120 seconds timeout
	local is_finished = false

	local function stop_timer()
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
	end

	local function check_status()
		if is_finished then
			return
		end

		attempts = attempts + 1
		if attempts > max_attempts then
			vim.notify("Timeout waiting for submission result.", vim.log.levels.ERROR)
			is_finished = true
			stop_timer()
			return
		end

		local response_body = http.get(check_url)
		if response_body and response_body ~= "" then
			local data = vim.fn.json_decode(response_body)
			if data and data.state then
				if data.state == "PENDING" or data.state == "STARTED" then
					vim.notify("Submission status: " .. data.state, vim.log.levels.INFO)
				else
					is_finished = true
					stop_timer()
					append_submission_results_to_buffer(submission_id)
				end
			else
				vim.notify("Could not parse submission status.", vim.log.levels.ERROR)
				is_finished = true
				stop_timer()
			end
		else
			vim.notify("Failed to fetch submission status.", vim.log.levels.ERROR)
			is_finished = true
			stop_timer()
		end
	end

	timer:start(0, 2000, vim.schedule_wrap(check_status))
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
		for _, line in ipairs(all_lines) do
			local found_id = line:match("^ID:%s*(%d+)")
			if found_id then
				question_id = found_id
				break
			end
		end
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
					poll_submission_status(data.submission_id)
				else
					vim.notify("Submission failed or is pending. API Response:", vim.log.levels.ERROR)
					print(vim.inspect(data))
				end
			else
				vim.notify(
					"Submission failed. The server returned a non-JSON response (details below).",
					vim.log.levels.ERROR
				)
				print(response_body)
			end
		else
			vim.notify("Failed to submit solution. Response was empty.", vim.log.levels.ERROR)
		end
	end)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	http.setup(config)
	vim.api.nvim_create_user_command("LeetCode", M.get_problems, {})
	vim.api.nvim_create_user_command("LeetCodeSubmit", M.submit_solution, {})
	vim.api.nvim_create_user_command("LeetCodeProgress", M.get_progress, {})
	-- vim.api.nvim_create_user_command("LeetCodeQuestion", function(opts)
	-- 	M.get_question(opts.args)
	-- end, { nargs = 1 })
	vim.api.nvim_create_user_command("LeetCodeHistory", M.get_practice_history, {})
	vim.api.nvim_create_user_command("LeetCodeSubmissionDetails", function(opts)
		M.get_submission_details(opts.args)
	end, { nargs = 1 })
end

return M
