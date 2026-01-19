package.preload['nvim-leetcode.http'] = (function()
  local mock = {}
  function mock.get(url)
    if url == "https://leetcode.com/api/problems/all/" then
      return vim.fn.json_encode({
        stat_status_pairs = {
          {
            stat = {
              frontend_question_id = 1,
              question__title = "Two Sum",
              question__title_slug = "two-sum",
            },
            difficulty = {
              level = 1,
            },
          },
        },
      })
    end
    return ""
  end
  function mock.post(url, body)
    if url == "https://leetcode.com/graphql" then
      local decoded_body = vim.fn.json_decode(body)
      if decoded_body.query:match("questionData") then
        return vim.fn.json_encode({
          data = {
            question = {
              content = "mock content",
              questionId = "1",
              questionFrontendId = "1",
              title = "Two Sum",
              difficulty = "Easy",
              codeSnippets = {
                {
                  lang = "Python3",
                  langSlug = "python3",
                  code = "class Solution:\n    def twoSum(self, nums: List[int], target: int) -> List[int]:\n        ",
                },
              },
            },
          },
        })
      end
    elseif url:match("/submit/") then
      return vim.fn.json_encode({ submission_id = 12345 })
    end
    return ""
  end
  function mock.setup()
  end
  return mock
end)()

local spy = require('plenary.spy')
local M = require('nvim-leetcode')

describe('nvim-leetcode', function()
  it('should setup commands', function()
    M.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds['LeetCode'])
    assert.is_not_nil(cmds['LeetCodeSubmit'])
    assert.is_not_nil(cmds['LeetCodeProgress'])
    assert.is_not_nil(cmds['LeetCodeQuestion'])
  end)

  it('should get problems', function()
    -- Create a spy for nvim_open_win
    local nvim_open_win_spy = spy.new(function() return 1 end)
    vim.api.nvim_open_win = nvim_open_win_spy

    -- Create spies for buffer functions
    local nvim_create_buf_spy = spy.new(function() return 1 end)
    vim.api.nvim_create_buf = nvim_create_buf_spy

    local nvim_buf_set_option_spy = spy.new(function() end)
    vim.api.nvim_buf_set_option = nvim_buf_set_option_spy

    local nvim_buf_set_lines_spy = spy.new(function() end)
    vim.api.nvim_buf_set_lines = nvim_buf_set_lines_spy

    local nvim_buf_set_keymap_spy = spy.new(function() end)
    vim.api.nvim_buf_set_keymap = nvim_buf_set_keymap_spy

    M.get_problems()

    -- Wait for the scheduled function to run
    vim.wait(100)

    -- Assert that the spies were called
    assert.spy(nvim_open_win_spy).was.called()
    assert.spy(nvim_create_buf_spy).was.called()
    assert.spy(nvim_buf_set_option_spy).was.called()
    assert.spy(nvim_buf_set_lines_spy).was.called()
    assert.spy(nvim_buf_set_keymap_spy).was.called()

    -- Assert that the buffer was populated with the correct lines
    local lines = nvim_buf_set_lines_spy.calls[1].refs[2]
    assert.are.same(lines[3], "[1] Two Sum (Easy)")

    -- Restore the original functions
    vim.api.nvim_open_win = nvim_open_win_spy.original
    vim.api.nvim_create_buf = nvim_create_buf_spy.original
    vim.api.nvim_buf_set_option = nvim_buf_set_option_spy.original
    vim.api.nvim_buf_set_lines = nvim_buf_set_lines_spy.original
    vim.api.nvim_buf_set_keymap = nvim_buf_set_keymap_spy.original
  end)

  it('should get a question', function()
    -- Create a spy for nvim_buf_set_lines
    local nvim_buf_set_lines_spy = spy.new(function() end)
    vim.api.nvim_buf_set_lines = nvim_buf_set_lines_spy

    M.get_question("two-sum")

    -- Wait for the scheduled function to run
    vim.wait(100)

    -- Assert that the spy was called
    assert.spy(nvim_buf_set_lines_spy).was.called()

    -- Assert that the buffer was populated with the correct lines
    local lines = nvim_buf_set_lines_spy.calls[1].refs[2]
    assert.are.same(lines[2], "ID: 1")
    assert.are.same(lines[3], "Title: Two Sum")

    -- Restore the original function
    vim.api.nvim_buf_set_lines = nvim_buf_set_lines_spy.original
  end)
end)