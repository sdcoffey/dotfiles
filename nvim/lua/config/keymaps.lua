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

local function is_visual_mode(mode)
  return mode == "v" or mode == "V" or mode == "\022"
end

local function get_visual_context()
  local mode = vim.fn.mode()
  local vmode
  local start_pos
  local end_pos

  if is_visual_mode(mode) then
    vmode = mode
    start_pos = vim.fn.getpos("v")
    end_pos = vim.fn.getcurpos()
  else
    vmode = vim.fn.visualmode()
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  end

  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]
  if start_line == 0 or end_line == 0 then
    return nil
  end

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_pos, end_pos = end_pos, start_pos
    start_line, end_line = end_line, start_line
  end

  return {
    end_line = end_line,
    end_pos = end_pos,
    start_line = start_line,
    start_pos = start_pos,
    vmode = vmode,
  }
end

local function get_visual_selection()
  local context = get_visual_context()
  if not context then
    return nil
  end

  local lines = vim.fn.getregion(context.start_pos, context.end_pos, { type = context.vmode })
  return table.concat(lines, "\n"), context.start_line, context.end_line
end

local function get_visual_line_range()
  local context = get_visual_context()
  if not context then
    return nil
  end

  return context.start_line, context.end_line
end

local function buffer_line_reference(line1, line2)
  local path = vim.fn.expand("%:p")
  if path == nil or path == "" then
    path = "[No Name]"
  end

  line1 = line1 or vim.fn.line(".")
  line2 = line2 or line1

  if line2 ~= line1 then
    return string.format("%s:%d-%d", path, line1, line2)
  end

  return string.format("%s:%d", path, line1)
end

local function get_line_range()
  if is_visual_mode(vim.fn.mode()) then
    local start_line, end_line = get_visual_line_range()
    if start_line and end_line then
      return start_line, end_line
    end
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

local function formatted_filepath(line1, line2)
  if line1 and line2 then
    return buffer_line_reference(line1, line2)
  end

  if is_visual_mode(vim.fn.mode()) then
    line1, line2 = get_visual_line_range()
    if line1 and line2 then
      return buffer_line_reference(line1, line2)
    end
  end

  return buffer_line_reference()
end

local function copy_to_tmux_buffer(text)
  if not vim.env.TMUX or vim.env.TMUX == "" or vim.fn.executable("tmux") ~= 1 then
    return
  end

  local result = vim.system({ "tmux", "load-buffer", "-w", "/dev/stdin" }, {
    stdin = text,
    text = true,
  }):wait()

  if result.code ~= 0 then
    local err = vim.trim(result.stderr or "")
    if err == "" then
      err = "unknown tmux error"
    end
    vim.notify("Copied, but failed to update tmux buffer: " .. err, vim.log.levels.WARN)
  end
end

local function copy_text(text)
  vim.fn.setreg("+", text)
  vim.fn.setreg("*", text)
  copy_to_tmux_buffer(text)
end

local function copy_formatted_snippet(opts)
  local has_visual_selection = is_visual_mode(vim.fn.mode()) or (opts and opts.range == 2)
  if not has_visual_selection then
    vim.notify("No visual selection found", vim.log.levels.WARN)
    return
  end

  local snippet, line1, line2 = get_visual_selection()
  if snippet == nil or snippet == "" then
    vim.notify("No visual selection found", vim.log.levels.WARN)
    return
  end

  local formatted = string.format("%s\n```%s\n%s\n```", formatted_filepath(line1, line2), lang_ext(), snippet)

  copy_text(formatted)
  vim.notify("Copied formatted snippet", vim.log.levels.INFO)
end

local function copy_absolute_path(opts)
  local formatted
  if opts and opts.range == 2 then
    formatted = formatted_filepath(opts.line1, opts.line2)
  else
    formatted = formatted_filepath()
  end
  copy_text(formatted)
  vim.notify("Copied file reference", vim.log.levels.INFO)
end

local function copy_contextual_reference(opts)
  local has_visual_selection = is_visual_mode(vim.fn.mode()) or (opts and opts.range == 2)
  if has_visual_selection then
    copy_formatted_snippet(opts)
    return
  end

  copy_absolute_path(opts)
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
  copy_text(text)
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
  range = true,
})

vim.api.nvim_create_user_command("CopyPath", copy_absolute_path, {
  desc = "Copy current absolute filepath with line reference",
  range = true,
})

vim.api.nvim_create_user_command("OpenGithub", open_github_permalink, {
  desc = "Open GitHub permalink for current line or visual range",
})

vim.api.nvim_create_user_command("CopyGithub", copy_github_permalink, {
  desc = "Copy GitHub permalink for current line or visual range",
})

-- Clear search highlight
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "No highlight" })

map({ "n", "x" }, "gl", copy_contextual_reference, { desc = "Copy file reference or snippet" })
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

local function scopes()
  return require("config.scopes")
end

local function notify_scope_error(err)
  vim.notify(err or "scope command failed", vim.log.levels.ERROR)
end

local function scope_names_completion()
  return scopes().profile_names()
end

local function active_scope_paths_completion()
  local active = scopes().active()
  return active and active.paths or {}
end

local function select_scope(name)
  local scope = scopes()
  local names = scope.profile_names()

  if name and name ~= "" then
    local ok, err = scope.select(name)
    if not ok then
      notify_scope_error(err)
      return
    end
    vim.notify("Scope: " .. name, vim.log.levels.INFO)
    return
  end

  if #names == 0 then
    vim.notify("No scope profiles found. Add one at " .. scope.profile_file(), vim.log.levels.WARN)
    return
  end

  vim.ui.select(names, { prompt = "Scope profile" }, function(choice)
    if not choice then
      return
    end
    select_scope(choice)
  end)
end

local function show_scope_info()
  local scope = scopes()
  local active = scope.active()
  if not active then
    vim.notify("No active scope. Profiles: " .. scope.profile_file(), vim.log.levels.INFO)
    return
  end

  local dirty = active.dirty and " modified" or ""
  vim.notify("Scope: " .. active.name .. dirty .. "\n" .. table.concat(active.paths, "\n"), vim.log.levels.INFO)
end

local function add_scope_path(path)
  local ok, result = scopes().add(path)
  if not ok then
    notify_scope_error(result)
    return
  end
  vim.notify("Added to scope: " .. result, vim.log.levels.INFO)
end

local function remove_scope_path(path)
  local scope = scopes()
  local active = scope.active()
  if not active then
    vim.notify("No active scope", vim.log.levels.WARN)
    return
  end

  local function remove(choice)
    if not choice or choice == "" then
      return
    end
    local ok, result = scope.remove(choice)
    if not ok then
      notify_scope_error(result)
      return
    end
    vim.notify("Removed from scope: " .. result, vim.log.levels.INFO)
  end

  if path and path ~= "" then
    remove(path)
    return
  end

  vim.ui.select(active.paths, { prompt = "Remove from scope" }, remove)
end

local function save_scope()
  local ok, result = scopes().save()
  if not ok then
    notify_scope_error(result)
    return
  end
  vim.notify("Saved scope: " .. result, vim.log.levels.INFO)
end

local function is_prefix(path, prefix)
  return path == prefix or path:sub(1, #prefix + 1) == (prefix .. "/")
end

local function scope_related(path, scope_path)
  return is_prefix(path, scope_path) or is_prefix(scope_path, path)
end

local function lua_pattern_escape(value)
  return value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function scope_tree_scan_dirs(scope_paths)
  local dirs = { "" }
  local seen = { [""] = true }

  for _, scope_path in ipairs(scope_paths) do
    local current = ""
    for part in scope_path:gmatch("[^/]+") do
      local next_dir = current == "" and part or (current .. "/" .. part)
      if next_dir == scope_path then
        break
      end
      if not seen[next_dir] then
        seen[next_dir] = true
        table.insert(dirs, next_dir)
      end
      current = next_dir
    end
  end

  return dirs
end

local function scope_tree_hide_patterns(root, scope_paths)
  local patterns = {}
  local seen = {}

  for _, dir in ipairs(scope_tree_scan_dirs(scope_paths)) do
    local abs_dir = dir == "" and root or joinpath(root, dir)
    local handle = (vim.uv or vim.loop).fs_scandir(abs_dir)
    if handle then
      while true do
        local name = (vim.uv or vim.loop).fs_scandir_next(handle)
        if not name then
          break
        end

        local rel = dir == "" and name or (dir .. "/" .. name)
        local visible = false
        for _, scope_path in ipairs(scope_paths) do
          if scope_related(rel, scope_path) then
            visible = true
            break
          end
        end

        if not visible then
          local abs = joinpath(root, rel)
          if not seen[abs] then
            seen[abs] = true
            table.insert(patterns, lua_pattern_escape(abs) .. "$")
          end
        end
      end
    end
  end

  return patterns
end

local function apply_scope_tree_filter(root, scope_paths)
  local manager = require("neo-tree.sources.manager")
  local state = manager.get_state("filesystem")

  if not state._scope_tree_base_filtered_items then
    state._scope_tree_base_filtered_items = vim.deepcopy(state.filtered_items or {})
  end

  local filtered_items = vim.deepcopy(state._scope_tree_base_filtered_items)
  filtered_items.hide_by_pattern = filtered_items.hide_by_pattern or {}
  vim.list_extend(filtered_items.hide_by_pattern, scope_tree_hide_patterns(root, scope_paths))
  filtered_items.visible = false

  state.filtered_items = filtered_items
  state.dirty = true
end

local function clear_scope_tree_filter()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return
  end

  local state = manager.get_state("filesystem")
  if not state._scope_tree_base_filtered_items then
    return
  end

  state.filtered_items = state._scope_tree_base_filtered_items
  state._scope_tree_base_filtered_items = nil
  state.dirty = true
end

local function active_scope_tree_context()
  local scope = scopes()
  local active = scope.active()
  if not active then
    return nil
  end

  local root = scope.repo_root()
  local paths = {}
  local missing = {}
  for _, path in ipairs(active.paths) do
    if vim.fn.isdirectory(joinpath(root, path)) == 1 then
      table.insert(paths, path)
    else
      table.insert(missing, path)
    end
  end

  if #paths == 0 then
    vim.notify("No scope paths exist on disk:\n" .. table.concat(missing, "\n"), vim.log.levels.WARN)
    return
  end

  if #missing > 0 then
    vim.notify("Skipping missing scope paths:\n" .. table.concat(missing, "\n"), vim.log.levels.WARN)
  end

  return {
    active = active,
    paths = paths,
    root = root,
  }
end

local function open_scope_tree()
  local context = active_scope_tree_context()
  if not context then
    vim.notify("No active scope", vim.log.levels.WARN)
    return
  end

  load_lazy_plugin("neo-tree.nvim")
  apply_scope_tree_filter(context.root, context.paths)
  vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(context.root))
end

local function scope_tree_toggle()
  local context = active_scope_tree_context()
  load_lazy_plugin("neo-tree.nvim")

  if not context then
    clear_scope_tree_filter()
    vim.cmd("Neotree toggle")
    return
  end

  apply_scope_tree_filter(context.root, context.paths)
  vim.cmd("Neotree toggle dir=" .. vim.fn.fnameescape(context.root))
end

local function path_in_scope(path, root, scope_paths)
  local normalized = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
  local normalized_root = vim.fn.fnamemodify(root, ":p"):gsub("/+$", "")
  if not is_prefix(normalized, normalized_root) then
    return false
  end

  local rel = normalized:sub(#normalized_root + 2)
  for _, scope_path in ipairs(scope_paths) do
    if is_prefix(rel, scope_path) then
      return true
    end
  end
  return false
end

local function scope_tree_reveal()
  local context = active_scope_tree_context()
  load_lazy_plugin("neo-tree.nvim")

  if not context then
    clear_scope_tree_filter()
    vim.cmd("Neotree reveal")
    return
  end

  apply_scope_tree_filter(context.root, context.paths)

  local file = vim.api.nvim_buf_get_name(0)
  if file ~= "" and path_in_scope(file, context.root, context.paths) then
    vim.cmd(
      "Neotree reveal_file="
        .. vim.fn.fnameescape(file)
        .. " dir="
        .. vim.fn.fnameescape(context.root)
    )
    return
  end

  if file ~= "" then
    vim.notify("Current file is outside active scope; opening scoped tree", vim.log.levels.INFO)
  end
  vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(context.root))
end

vim.api.nvim_create_user_command("ScopeSelect", function(opts)
  select_scope(opts.args)
end, {
  nargs = "?",
  complete = scope_names_completion,
  desc = "Select a named scope profile",
})

vim.api.nvim_create_user_command("ScopeInfo", show_scope_info, {
  desc = "Show active scope paths",
})

vim.api.nvim_create_user_command("ScopeAdd", function(opts)
  add_scope_path(opts.args)
end, {
  nargs = "?",
  complete = "dir",
  desc = "Add a directory to the active scope",
})

vim.api.nvim_create_user_command("ScopeRemove", function(opts)
  remove_scope_path(opts.args)
end, {
  nargs = "?",
  complete = active_scope_paths_completion,
  desc = "Remove a directory from the active scope",
})

vim.api.nvim_create_user_command("ScopeClear", function()
  scopes().clear()
  vim.notify("Scope cleared", vim.log.levels.INFO)
end, {
  desc = "Clear active scope for this session",
})

vim.api.nvim_create_user_command("ScopeSave", save_scope, {
  desc = "Persist active scope paths",
})

vim.api.nvim_create_user_command("ScopeReload", function()
  scopes().reload()
  vim.notify("Scope profiles reloaded", vim.log.levels.INFO)
end, {
  desc = "Reload scope profiles",
})

vim.api.nvim_create_user_command("ScopeTree", open_scope_tree, {
  desc = "Open Neo-tree at an active scope root",
})

vim.api.nvim_create_user_command("ScopeTreeToggle", scope_tree_toggle, {
  desc = "Toggle Neo-tree, scoped when a scope is active",
})

vim.api.nvim_create_user_command("ScopeTreeReveal", scope_tree_reveal, {
  desc = "Reveal current file in Neo-tree, scoped when active",
})

vim.api.nvim_create_user_command("ScopeTreeClear", clear_scope_tree_filter, {
  desc = "Clear Neo-tree scope filtering",
})

map("n", "<leader>ff", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ include_untracked = true })
end, { desc = "Find files" })

map("n", "<leader>fF", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ scope = "repo", include_untracked = true })
end, { desc = "Find files (repo)" })

map("n", "<leader>fu", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ include_untracked = true, refresh = true })
end, { desc = "Find files (refresh cache)" })

map("n", "<leader>fU", function()
  ensure_telescope()
  local repo = require("config.telescope")
  repo.git_files({ scope = "repo", include_untracked = true, refresh = true })
end, { desc = "Find files (repo, refresh cache)" })

map("n", "<leader>fg", function()
  start_live_grep_advanced("auto")
end, { desc = "Live grep (advanced)" })

map("n", "<leader>fC", prompt_live_grep_custom, { desc = "Live grep (custom root/ext)" })

map("n", "<leader>sp", function()
  select_scope()
end, { desc = "Scope select" })

map("n", "<leader>si", show_scope_info, { desc = "Scope info" })
map("n", "<leader>sa", function()
  add_scope_path()
end, { desc = "Scope add current dir" })
map("n", "<leader>sr", function()
  remove_scope_path()
end, { desc = "Scope remove path" })
map("n", "<leader>ss", save_scope, { desc = "Scope save" })
map("n", "<leader>st", open_scope_tree, { desc = "Scope tree" })

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

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "*",
  },
  callback = function(args)
    map("i", "<C-l>", " => ", { buffer = args.buf, desc = "Insert =>" })
  end,
})

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
