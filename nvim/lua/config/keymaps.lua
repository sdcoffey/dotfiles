local map = vim.keymap.set

map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "Y", "y$", { desc = "Yank to end of line" })

local function systemlist(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

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

local function get_line_range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\022" then
    local start_line = vim.fn.getpos("'<")[2]
    local end_line = vim.fn.getpos("'>")[2]
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    return start_line, end_line
  end
  local line = vim.fn.line(".")
  return line, line
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

  local path = vim.fn.expand("%:p")
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

local function normalize_remote(remote)
  if not remote or remote == "" then
    return nil
  end

  local host, repo_path

  if remote:match("^[^@]+@[^:]+:.+$") then
    host, repo_path = remote:match("^[^@]+@([^:]+):(.+)$")
  elseif remote:match("^https?://[^/]+/.+$") then
    host, repo_path = remote:match("^https?://([^/]+)/(.+)$")
  end

  if not host or not repo_path then
    return nil
  end

  repo_path = repo_path:gsub("%.git$", "")

  -- Normalize GitHub SSH aliases like github-public -> github.com.
  if host:match("github") then
    host = "github.com"
  end

  return string.format("https://%s/%s", host, repo_path)
end

local function build_github_permalink()
  local file = vim.api.nvim_buf_get_name(0)
  if not file or file == "" then
    vim.notify("Buffer has no file name", vim.log.levels.WARN)
    return nil
  end

  local file_dir = vim.fn.fnamemodify(file, ":h")
  local root_out = systemlist(string.format("git -C %s rev-parse --show-toplevel", vim.fn.shellescape(file_dir)))
  if not root_out or not root_out[1] then
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
    return nil
  end
  local root = root_out[1]

  local remote_out = systemlist(string.format("git -C %s remote get-url origin", vim.fn.shellescape(root)))
  local commit_out = systemlist(string.format("git -C %s rev-parse HEAD", vim.fn.shellescape(root)))
  if not remote_out or not commit_out or not remote_out[1] or not commit_out[1] then
    vim.notify("Unable to resolve git remote/commit", vim.log.levels.ERROR)
    return nil
  end

  local base = normalize_remote(remote_out[1])
  if not base then
    vim.notify("Remote is not a supported GitHub URL", vim.log.levels.ERROR)
    return nil
  end

  local relpath = file
  local root_prefix = root .. "/"
  if vim.startswith(file, root_prefix) then
    relpath = file:sub(#root_prefix + 1)
  end
  relpath = relpath:gsub(" ", "%%20")

  local line1, line2 = get_line_range()
  local lines_fragment = string.format("#L%d", line1)
  if line2 ~= line1 then
    lines_fragment = string.format("#L%d-L%d", line1, line2)
  end

  local url = string.format("%s/blob/%s/%s%s", base, commit_out[1], relpath, lines_fragment)
  return url
end

local function copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  vim.fn.setreg("*", text)
end

local function copy_github_permalink()
  local url = build_github_permalink()
  if not url then
    return
  end
  copy_to_clipboard(url)
  vim.notify("Copied GitHub permalink", vim.log.levels.INFO)
end

local function open_github_permalink()
  local url = build_github_permalink()
  if not url then
    return
  end
  copy_to_clipboard(url)
  local opener = vim.fn.has("macunix") == 1 and "open" or "xdg-open"
  vim.fn.jobstart({ opener, url }, { detach = true })
  vim.notify("Opened GitHub permalink", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("CopySnippet", copy_formatted_snippet, {
  desc = "Copy visual selection with path and range",
})

vim.api.nvim_create_user_command("OpenGithub", open_github_permalink, {
  desc = "Open GitHub permalink for current line or visual range",
})

vim.api.nvim_create_user_command("CopyGithub", copy_github_permalink, {
  desc = "Copy GitHub permalink for current line or visual range",
})

-- Clear search highlight
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "No highlight" })
map("x", "<leader>ys", "<Esc><Cmd>CopySnippet<CR>", { desc = "Copy formatted snippet" })
map({ "n", "x" }, "<leader>gh", copy_github_permalink, { desc = "Copy GitHub permalink" })
map({ "n", "x" }, "<leader>ogh", open_github_permalink, { desc = "Open GitHub permalink" })

-- Telescope
local function load_lazy_plugin(name)
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { name } })
  end
end

local function ensure_telescope()
  load_lazy_plugin("telescope.nvim")
end

local function ensure_aerial()
  load_lazy_plugin("aerial.nvim")
end

local function run_live_grep(extra_opts)
  ensure_telescope()
  local repo = require("config.telescope")
  local opts = repo.live_grep_opts(extra_opts)

  local ok_telescope, telescope = pcall(require, "telescope")
  if ok_telescope then
    local lga = telescope.extensions and telescope.extensions.live_grep_args
    if lga and type(lga.live_grep_args) == "function" then
      lga.live_grep_args(opts)
      return
    end
  end

  require("telescope.builtin").live_grep(opts)
end

local startup_cwd = (vim.uv or vim.loop).cwd()

local function joinpath(...)
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(...)
  end
  return table.concat({ ... }, "/")
end

local function parse_extension_globs(input)
  local text = vim.trim(input or "")
  if text == "" then
    return {}
  end

  local globs = {}
  for token in text:gmatch("[^,%s]+") do
    local value = vim.trim(token)
    if value ~= "" then
      if value:find("[%*%?%[]") or value:find("/") or value:sub(1, 1) == "!" then
        table.insert(globs, value)
      else
        value = value:gsub("^%*%.", "")
        value = value:gsub("^%.", "")
        if value ~= "" then
          table.insert(globs, "*." .. value)
        end
      end
    end
  end

  return globs
end

local function resolve_search_root(input)
  local text = vim.trim(input or "")
  if text == "" then
    return nil
  end

  local expanded = vim.fn.expand(text)
  local absolute = vim.startswith(expanded, "/")
  local base = startup_cwd or (vim.uv or vim.loop).cwd() or "."
  local candidate = absolute and expanded or joinpath(base, expanded)
  candidate = vim.fn.fnamemodify(candidate, ":p")
  candidate = candidate:gsub("/+$", "")

  if vim.fn.isdirectory(candidate) ~= 1 then
    vim.notify("Directory not found: " .. candidate, vim.log.levels.ERROR)
    return nil, true
  end

  return candidate
end

local function current_base_dir(state)
  return state.cwd or startup_cwd or (vim.uv or vim.loop).cwd() or "."
end

local function parent_dir(path)
  local normalized = vim.fn.fnamemodify(path, ":p")
  normalized = normalized:gsub("/+$", "")
  local parent = vim.fn.fnamemodify(normalized, ":h")
  parent = parent:gsub("/+$", "")
  if parent == "" then
    parent = "/"
  end
  return parent
end

local function format_root_label(state)
  if state.cwd then
    return vim.fn.fnamemodify(state.cwd, ":~")
  end
  if state.scope == "repo" then
    return "repo(auto)"
  end
  return "cwd(auto)"
end

local function format_mask_label(mask)
  local value = vim.trim(mask or "")
  if value == "" then
    return "all files"
  end
  return value
end

local function open_live_grep_advanced(state, default_text)
  local options = {
    scope = state.scope or "auto",
    default_text = default_text,
    prompt_title = string.format(
      "Live Grep [root: %s] [mask: %s]  <C-r> root  <C-f> mask  <C-p> parent  <C-b> clear",
      format_root_label(state),
      format_mask_label(state.mask)
    ),
  }

  if state.cwd then
    options.cwd = state.cwd
  end

  local globs = parse_extension_globs(state.mask)
  if #globs > 0 then
    options.globs = globs
  end

  options.mappings = {
    i = {
      ["<C-r>"] = function(prompt_bufnr)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local query = action_state.get_current_line()
        actions.close(prompt_bufnr)

        vim.schedule(function()
          local default_root = state.cwd and vim.fn.fnamemodify(state.cwd, ":~") or ""
          vim.ui.input({
            prompt = "Search root (blank=auto, relative to startup cwd): ",
            default = default_root,
          }, function(root_input)
            if root_input == nil then
              open_live_grep_advanced(state, query)
              return
            end

            local root, root_error = resolve_search_root(root_input)
            if not root_error then
              state.cwd = root
            end
            open_live_grep_advanced(state, query)
          end)
        end)
      end,
      ["<C-f>"] = function(prompt_bufnr)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local query = action_state.get_current_line()
        actions.close(prompt_bufnr)

        vim.schedule(function()
          vim.ui.input({
            prompt = "File mask (e.g. *.py,py,src/**/*.lua; blank=all): ",
            default = state.mask or "",
          }, function(mask_input)
            if mask_input == nil then
              open_live_grep_advanced(state, query)
              return
            end

            state.mask = vim.trim(mask_input)
            open_live_grep_advanced(state, query)
          end)
        end)
      end,
      ["<C-p>"] = function(prompt_bufnr)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local query = action_state.get_current_line()
        actions.close(prompt_bufnr)

        local base = current_base_dir(state)
        local parent = parent_dir(base)
        if parent == base then
          vim.notify("Already at filesystem root", vim.log.levels.INFO)
        else
          state.cwd = parent
        end

        vim.schedule(function()
          open_live_grep_advanced(state, query)
        end)
      end,
      ["<C-b>"] = function(prompt_bufnr)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local query = action_state.get_current_line()
        actions.close(prompt_bufnr)

        state.cwd = nil
        state.mask = ""

        vim.schedule(function()
          open_live_grep_advanced(state, query)
        end)
      end,
    },
  }

  run_live_grep(options)
end

local function start_live_grep_advanced(scope)
  open_live_grep_advanced({
    scope = scope or "auto",
    cwd = nil,
    mask = "",
  })
end

local function open_live_grep_custom(root_input, ext_input)
  local root, root_error = resolve_search_root(root_input)
  if root_error then
    return
  end

  open_live_grep_advanced({
    scope = "repo",
    cwd = root,
    mask = ext_input or "",
  })
end

local function prompt_live_grep_custom()
  vim.ui.input({ prompt = "Search root (blank=repo, relative to startup cwd): " }, function(root_input)
    if root_input == nil then
      return
    end

    vim.ui.input({ prompt = "Extensions (e.g. py,ts or *.md, blank=all): " }, function(ext_input)
      if ext_input == nil then
        return
      end
      open_live_grep_custom(root_input, ext_input)
    end)
  end)
end

vim.api.nvim_create_user_command("LiveGrepCustom", prompt_live_grep_custom, {
  desc = "Live grep with optional custom root and extension globs",
})

map("n", "<leader>ff", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files()
end, { desc = "Find files" })

map("n", "<leader>fF", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ scope = "repo" })
end, { desc = "Find files (repo)" })

map("n", "<leader>fu", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ include_untracked = true })
end, { desc = "Find files (with untracked)" })

map("n", "<leader>fU", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ scope = "repo", include_untracked = true })
end, { desc = "Find files (repo + untracked)" })

map("n", "<leader>fg", function()
  start_live_grep_advanced("auto")
end, { desc = "Live grep (advanced)" })

map("n", "<leader>fC", prompt_live_grep_custom, { desc = "Live grep (custom root/ext)" })

map("n", "<leader>be", function()
  ensure_telescope()
  require("telescope.builtin").buffers()
end, { desc = "Buffers" })

map("n", "<leader>fs", function()
  ensure_aerial()
  require("aerial").fzf_lua_picker()
end, { desc = "Document symbols" })

map("n", "<leader>fS", function()
  ensure_telescope()
  require("telescope.builtin").lsp_dynamic_workspace_symbols()
end, { desc = "Workspace symbols" })

map("v", "<leader>ce", "<cmd>CodexEditSelection<cr>", { desc = "Codex: edit selection" })

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
