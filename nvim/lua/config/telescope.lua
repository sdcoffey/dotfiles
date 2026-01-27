local M = {}

local uv = vim.uv or vim.loop
local cache = {}

local function git_root()
  local cwd = uv.cwd()
  local git_dir = vim.fs.find(".git", { path = cwd, upward = true })[1]
  if not git_dir then
    return cwd
  end
  return vim.fs.dirname(git_dir)
end

local function is_prefix(path, prefix)
  return path == prefix or path:sub(1, #prefix + 1) == (prefix .. "/")
end

local function relative_path(path, root)
  if vim.fs and vim.fs.relative then
    local rel = vim.fs.relative(path, root)
    if rel and rel ~= "." then
      return rel
    end
    return nil
  end
  if is_prefix(path, root) and path ~= root then
    return path:sub(#root + 2)
  end
  return nil
end

local function scope_prefix_for(ctx, scope)
  local cwd = uv.cwd()
  if not cwd or not is_prefix(cwd, ctx.root) then
    return nil
  end

  if scope == "cwd" or (scope == "auto" and cwd ~= ctx.root) then
    return relative_path(cwd, ctx.root)
  end

  return nil
end

local function read_ignore_file(path)
  if vim.fn.filereadable(path) ~= 1 then
    return { excludes = {}, includes = {} }
  end

  local lines = vim.fn.readfile(path)
  local excludes, includes = {}, {}
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      local is_include = trimmed:match("^!")
      local dir = trimmed:gsub("^!", ""):gsub("/+$", "")
      if dir ~= "" then
        if is_include then
          table.insert(includes, dir)
        else
          table.insert(excludes, dir)
        end
      end
    end
  end
  return { excludes = excludes, includes = includes }
end

local function build_repo_context()
  local root = git_root()
  local repo_name = vim.fn.fnamemodify(root, ":t")
  local external_ignore_file = vim.fn.stdpath("config") .. "/telescopeignore/" .. repo_name

  local root_ignore_file = root .. "/.telescopeignore"
  local root_ignores = read_ignore_file(root_ignore_file)
  local external_ignores = read_ignore_file(external_ignore_file)

  local excludes = { ".git" }
  vim.list_extend(excludes, root_ignores.excludes)
  vim.list_extend(excludes, external_ignores.excludes)

  local includes = {}
  vim.list_extend(includes, root_ignores.includes)
  vim.list_extend(includes, external_ignores.includes)

  local function matches_any(path, prefixes)
    for _, prefix in ipairs(prefixes) do
      if is_prefix(path, prefix) then
        return true
      end
    end
    return false
  end

  local function should_ignore(path)
    if not matches_any(path, excludes) then
      return false
    end
    return not matches_any(path, includes)
  end

  local file_ignore_patterns = {}
  for _, dir in ipairs(excludes) do
    table.insert(file_ignore_patterns, dir .. "/")
  end

  local rg_globs = {}
  for _, dir in ipairs(excludes) do
    table.insert(rg_globs, "!" .. dir .. "/**")
  end
  for _, dir in ipairs(includes) do
    table.insert(rg_globs, dir .. "/**")
  end

  return {
    root = root,
    root_ignore_file = root_ignore_file,
    external_ignore_file = external_ignore_file,
    excludes = excludes,
    includes = includes,
    should_ignore = should_ignore,
    file_ignore_patterns = file_ignore_patterns,
    rg_globs = rg_globs,
  }
end

function M.find_files_opts(extra)
  local ctx = build_repo_context()
  return vim.tbl_deep_extend("force", {
    cwd = ctx.root,
    file_ignore_patterns = ctx.file_ignore_patterns,
  }, extra or {})
end

function M.git_files(extra)
  local ctx = build_repo_context()
  local opts = vim.tbl_deep_extend("force", { cwd = ctx.root }, extra or {})
  local scope = opts.scope or "auto"
  local scope_prefix = scope_prefix_for(ctx, scope)

  local function mtime(path)
    local stat = uv.fs_stat(path)
    if not stat or not stat.mtime then
      return 0
    end
    return stat.mtime.sec or 0
  end

  local function cache_key()
    return ctx.root
  end

  local function cache_token()
    local git_index = ctx.root .. "/.git/index"
    return table.concat({
      tostring(mtime(git_index)),
      tostring(mtime(ctx.root_ignore_file)),
      tostring(mtime(ctx.external_ignore_file)),
    }, ":")
  end

  local cmd = {
    "git",
    "-C",
    ctx.root,
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
  }

  local key = cache_key()
  local token = cache_token()
  local cached = cache[key]

  local filtered
  if cached and cached.token == token then
    filtered = cached.results
  else
    local results = vim.fn.systemlist(cmd)
    filtered = {}
    for _, path in ipairs(results) do
      local in_scope = true
      if scope_prefix then
        in_scope = is_prefix(path, scope_prefix)
      end

      if in_scope and not ctx.should_ignore(path) then
        table.insert(filtered, path)
      end
    end
    cache[key] = { token = token, results = filtered }
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local joinpath = (vim.fs and vim.fs.joinpath)
    or function(...)
      return table.concat({ ... }, "/")
    end

  pickers
    .new(opts, {
      prompt_title = scope_prefix and ("Git Files (" .. scope_prefix .. ")") or "Git Files",
      finder = finders.new_table({
        results = filtered,
        entry_maker = function(entry)
          local full_path = joinpath(ctx.root, entry)
          return {
            value = full_path,
            path = full_path,
            ordinal = entry,
            display = entry,
          }
        end,
      }),
      previewer = conf.file_previewer(opts),
      sorter = conf.file_sorter(opts),
    })
    :find()
end

function M.live_grep_opts(extra)
  local ctx = build_repo_context()
  local opts = extra or {}
  local scope = opts.scope or "auto"
  local scope_prefix = scope_prefix_for(ctx, scope)
  local joinpath = (vim.fs and vim.fs.joinpath)
    or function(...)
      return table.concat({ ... }, "/")
    end
  local scope_cwd = scope_prefix and joinpath(ctx.root, scope_prefix) or nil

  local function additional_args()
    if scope_prefix then
      return {}
    end
    local args = {}
    for _, glob in ipairs(ctx.rg_globs) do
      table.insert(args, "--glob")
      table.insert(args, glob)
    end
    return args
  end

  return vim.tbl_deep_extend("force", {
    cwd = scope_cwd or ctx.root,
    file_ignore_patterns = ctx.file_ignore_patterns,
    additional_args = additional_args,
    prompt_title = scope_prefix and ("Live Grep (" .. scope_prefix .. ")") or nil,
  }, opts)
end

return M
