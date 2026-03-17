local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.mouse = "a"
opt.clipboard = "unnamedplus"
if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")

  vim.g.clipboard = {
    name = "OSC52 SSH",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
    cache_enabled = 0,
  }
end
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 200
opt.timeoutlen = 400
opt.autoread = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

opt.wrap = true
opt.scrolloff = 5
opt.sidescrolloff = 5
opt.splitbelow = true
opt.splitright = true
opt.foldmethod = "expr"
if vim.treesitter and vim.treesitter.foldexpr then
  opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
else
  opt.foldexpr = "nvim_treesitter#foldexpr()"
end
opt.foldenable = true
opt.foldlevel = 99
opt.foldlevelstart = 99

opt.undofile = true
opt.undolevels = 1000
opt.undoreload = 10000
local nvim_undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(nvim_undo_dir, "p")
opt.undodir = nvim_undo_dir

opt.wildignore:append({
  "*.pyc",
  "*.o",
  "*.class",
  "*.lo",
  ".git",
  "vendor/*",
  "node_modules/**",
  "bower_components/**",
  "*/build_gradle/*",
  "*/build_intellij/*",
  "*/build/*",
  "*/cassandra_data/*",
})

-- Highlight on yank
local yank_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = yank_group,
  callback = function()
    vim.highlight.on_yank({ timeout = 120 })
  end,
})

-- Refresh buffers when files change on disk.
local autoread_group = vim.api.nvim_create_augroup("AutoReadChecktime", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = autoread_group,
  callback = function()
    if vim.fn.getcmdwintype() ~= "" then
      return
    end

    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = autoread_group,
  callback = function()
    vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.INFO)
  end,
})
