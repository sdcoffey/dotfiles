
lvim.leader = "\\"

lvim.keys.insert_mode["jk"] = "<esc>"
lvim.keys.insert_mode["jK"] = "<esc>"
lvim.keys.insert_mode["JK"] = "<esc>"
lvim.keys.insert_mode["Jk"] = "<esc>"

-- Nvim
lvim.keys.normal_mode["<F12>"] = "<cmd>lua vim.lsp.buf.definition()<CR>"

lvim.keys.normal_mode["<LocalLeader>nt"] = ":NvimTreeToggle<CR>"

lvim.plugins = {
    { "nvim-neotest/nvim-nio"},
    { "nvim-neotest/neotest"},
    { "nvim-neotest/neotest-python"},
    { "mfussenegger/nvim-dap-python" }, -- For Python debugging
}


lvim.builtin.dap.active = true
local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")
pcall(function()
  require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
end)

require("neotest").setup({
  adapters = {
    require("neotest-python")({
      -- Extra arguments for nvim-dap configuration
      -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
      dap = {
        justMyCode = false,
        console = "integratedTerminal",
      },
      args = { "--log-level", "DEBUG", "--quiet" },
      runner = "pytest",
    })
  }
})



local dap, dapui = require("dap"), require("dapui")
vim.keymap.set('n', '<Leader>rf', function ()
  require('neotest').run.run()
end)
vim.keymap.set('n', '<Leader>rd', function ()
  require('neotest').run.run({strategy = 'dap'})
end)
vim.keymap.set('n', '<Leader>rb', function()
  require("dap").toggle_breakpoint()
end)

vim.keymap.set("n", "<F5>", dap.continue, { desc = "Start/Continue Debugging" })
vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Step Over" })
vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Step Into" })
vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Step Out" })
vim.keymap.set("n", "<leader>dq", function()
  dap.terminate()
  dapui.close()
end, { desc = "Terminate Debug Session" })

dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

