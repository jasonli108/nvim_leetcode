local M = require('nvim-leetcode')

-- Mock http module
local http = {
  request = function(opts, cb) 
    if opts.url == 'https://leetcode.cn/graphql' then
      if string.find(opts.body, 'allQuestions') then
        cb({
          body = http.json_encode({
            data = {
              allQuestions = {
                { questionId = '1', title = 'Two Sum', titleSlug = 'two-sum', difficulty = 'Easy' },
                { questionId = '2', title = 'Add Two Numbers', titleSlug = 'add-two-numbers', difficulty = 'Medium' },
              },
            },
          }),
        })
      elseif string.find(opts.body, 'question') then
        cb({
          body = http.json_encode({
            data = {
              question = {
                content = 'mock content',
                stats = '{"question_id": 1}',
                codeDefinition = '[{"value": "python3", "defaultCode": "class Solution:\n    def twoSum(self, nums: List[int], target: int) -> List[int]:\n        "}]',
                metaData = '{"name": "two-sum"}',
              },
            },
          }),
        })
      end
    elseif string.find(opts.url, '/submit') then
      cb({
        body = http.json_encode({
          submission_id = '123',
        }),
      })
    elseif string.find(opts.url, '/check') then
      cb({
        body = http.json_encode({
          state = 'SUCCESS',
          status_display = 'Accepted',
          status_runtime = '100 ms',
          status_memory = '10 MB',
        }),
      })
    end
  end,
  json_encode = function(tbl) 
    return vim.fn.json_encode(tbl)
  end,
  json_decode = function(str) 
    return vim.fn.json_decode(str)
  end,
}

_G.http = http

describe('nvim-leetcode', function() 
  it('should setup commands', function() 
    M.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds['LeetCode'])
    assert.is_not_nil(cmds['LeetCodeSubmit'])
  end)

  it('should get problems', function() 
    M.get_problems()
    -- TODO: assert that the problems are displayed
  end)

  it('should select a problem', function() 
    -- Mock the current line
    vim.api.nvim_set_current_line('1. Two Sum (Easy)')
    M.select_problem()
    -- TODO: assert that the problem details are displayed
  end)

  it('should submit a solution', function() 
    -- Mock the current buffer content
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'class Solution:', '    def twoSum(self, nums, target):', '        return []' })
    M.submit_solution()
    -- TODO: assert that the submission result is displayed
  end)
end)
