local map = vim.keymap.set

map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "Y", "y$", { desc = "Yank to end of line" })

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3] - 1

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local vmode = vim.fn.visualmode()
  local lines

  if vmode == "V" or vmode == "\022" then
    lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  else
    lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col + 1, {})
  end

  return table.concat(lines, "\n"), start_row + 1, end_row + 1
end

local function lang_ext()
  local ext = vim.fn.expand("%:e")
  if ext == nil or ext == "" then
    ext = vim.bo.filetype
  end
  if ext == nil or ext == "" then
    ext = "text"
  end
  return ext
end

local function copy_formatted_snippet()
  local snippet, line1, line2 = get_visual_selection()
  if snippet == nil or snippet == "" then
    vim.notify("No visual selection found", vim.log.levels.WARN)
    return
  end

  local path = vim.fn.expand("%:.")
  if path == nil or path == "" then
    path = "[No Name]"
  end

  local range = tostring(line1)
  if line2 ~= line1 then
    range = string.format("%d-%d", line1, line2)
  end

  local formatted = string.format("%s:%s\n```%s\n%s\n```", path, range, lang_ext(), snippet)

  vim.fn.setreg("+", formatted)
  vim.fn.setreg("*", formatted)
  vim.notify("Copied formatted snippet", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("CopySnippet", copy_formatted_snippet, {
  desc = "Copy visual selection with path and range",
})

-- Clear search highlight
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "No highlight" })
map("x", "<leader>ys", "<Esc><Cmd>CopySnippet<CR>", { desc = "Copy formatted snippet" })

-- Telescope
map("n", "<leader>ff", function()
  local repo = require("config.telescope")
  repo.git_files()
end, { desc = "Find files" })

map("n", "<leader>fg", function()
  local repo = require("config.telescope")
  require("telescope.builtin").live_grep(repo.live_grep_opts())
end, { desc = "Live grep" })

map("n", "<leader>be", function()
  require("telescope.builtin").buffers()
end, { desc = "Buffers" })

map("n", "<leader>fs", function()
  require("telescope.builtin").lsp_document_symbols()
end, { desc = "Document symbols" })

map("n", "<leader>fS", function()
  require("telescope.builtin").lsp_dynamic_workspace_symbols()
end, { desc = "Workspace symbols" })

-- LSP keymaps (attached per-buffer)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufmap = function(lhs, rhs, desc)
      map("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end

    bufmap("<F12>", vim.lsp.buf.definition, "Go to definition")
    bufmap("gD", vim.lsp.buf.declaration, "Go to declaration")
    bufmap("gr", vim.lsp.buf.references, "References")
    bufmap("gi", vim.lsp.buf.implementation, "Implementation")
    bufmap("K", vim.lsp.buf.hover, "Hover docs")
    bufmap("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    bufmap("<leader>ca", vim.lsp.buf.code_action, "Code action")
    bufmap("<leader>fd", vim.diagnostic.open_float, "Line diagnostics")
    bufmap("[d", vim.diagnostic.goto_prev, "Prev diagnostic")
    bufmap("]d", vim.diagnostic.goto_next, "Next diagnostic")
  end,
})
