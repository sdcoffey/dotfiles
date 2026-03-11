vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

if vim.islist == nil then
  vim.islist = vim.tbl_islist
end

require("config.options")
require("config.keymaps")
require("config.lazy")
