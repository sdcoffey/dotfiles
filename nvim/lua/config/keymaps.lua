local map = vim.keymap.set

map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "Y", "y$", { desc = "Yank to end of line" })

-- Clear search highlight
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "No highlight" })

-- Telescope
map("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files" })

map("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "Live grep" })

map("n", "<leader>fb", function()
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

    bufmap("gd", vim.lsp.buf.definition, "Go to definition")
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
