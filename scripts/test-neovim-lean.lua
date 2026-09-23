vim.cmd("edit treesitter-smoke-test.lean")
assert(vim.bo.filetype == "lean", "Expected .lean filetype detection")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "def answer : Nat := 42",
  "",
  "theorem identity (n : Nat) : n = n := by",
  "  rfl",
})

local parser, err = vim.treesitter.get_parser(0, "lean")
assert(parser, err)
local tree = assert(parser:parse()[1], "Expected a Lean syntax tree")
assert(not tree:root():has_error(), "Lean sample contains parse errors")
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()],
  "Expected automatic Tree-sitter highlighting")

for _, name in ipairs({ "highlights", "folds", "indents", "injections", "locals" }) do
  assert(vim.treesitter.query.get("lean", name), "Missing Lean query: " .. name)
end

local highlights = vim.treesitter.query.get("lean", "highlights")
local captures = 0
for _ in highlights:iter_captures(tree:root(), 0) do
  captures = captures + 1
end
assert(captures > 0, "Expected highlighting captures")
print("Lean filetype, parser, queries, and automatic highlighting passed")
vim.cmd("qa!")
