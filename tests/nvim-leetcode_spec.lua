-- tests/nvim-leetcode_spec.lua

describe('nvim-leetcode', function()
  it('should have a setup function', function()
    assert.is_function(require('nvim-leetcode').setup)
  end)
end)
