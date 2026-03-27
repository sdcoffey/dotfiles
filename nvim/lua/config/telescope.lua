local M = {}

local uv = vim.uv or vim.loop
local cache = {}
local joinpath = (vim.fs and vim.fs.joinpath)
  or function(...)
    return table.concat({ ... }, "/")
  end

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

local function cache_root_dir()
  local base = vim.env.XDG_CACHE_HOME
  if not base or base == "" then
    base = joinpath(vim.fn.expand("~"), ".cache")
  end
  return joinpath(base, "ff")
end

local function repo_cache_file(root)
  return joinpath(cache_root_dir(), vim.fn.sha256(root) .. ".files")
end

local function mtime(path)
  if not path or path == "" then
    return 0
  end
  local stat = uv.fs_stat(path)
  if not stat or not stat.mtime then
    return 0
  end
  return stat.mtime.sec or 0
end

local function repo_git_dir(root)
  local git_dir = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--git-dir" })[1]
  if vim.v.shell_error ~= 0 or not git_dir or git_dir == "" then
    return nil
  end
  if not git_dir:match("^/") then
    git_dir = joinpath(root, git_dir)
  end
  return git_dir
end

local function repo_cache_token(ctx)
  local git_dir = repo_git_dir(ctx.root)
  return table.concat({
    tostring(mtime(git_dir and joinpath(git_dir, "index") or nil)),
    tostring(mtime(ctx.root_ignore_file)),
    tostring(mtime(ctx.external_ignore_file)),
    tostring(mtime(joinpath(ctx.root, ".gitignore"))),
    tostring(mtime(git_dir and joinpath(git_dir, "info", "exclude") or nil)),
  }, ":")
end

local function tracked_repo_files(ctx, scope_prefix)
  local cmd = {
    "git",
    "-c",
    "core.fsmonitor=false",
    "-C",
    ctx.root,
    "ls-files",
    "--cached",
    "--deduplicate",
  }
  if scope_prefix then
    table.insert(cmd, "--")
    table.insert(cmd, scope_prefix)
  end

  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return lines
end

local function repo_cache_needs_refresh(ctx, cache_file)
  if vim.fn.filereadable(cache_file) ~= 1 or vim.fn.getfsize(cache_file) <= 0 then
    return true
  end

  local ttl_seconds = tonumber(vim.env.FF_CACHE_TTL_SECONDS or "") or 300
  local cache_mtime = mtime(cache_file)
  if os.time() - cache_mtime > ttl_seconds then
    return true
  end

  local git_dir = repo_git_dir(ctx.root)
  if not git_dir then
    return false
  end

  if mtime(joinpath(git_dir, "index")) > cache_mtime then
    return true
  end

  for _, candidate in ipairs({
    joinpath(ctx.root, ".gitignore"),
    ctx.root_ignore_file,
    ctx.external_ignore_file,
    joinpath(git_dir, "info", "exclude"),
  }) do
    if mtime(candidate) > cache_mtime then
      return true
    end
  end

  return false
end

local function load_repo_cache(cache_file)
  if vim.fn.filereadable(cache_file) ~= 1 then
    return nil
  end
  return vim.fn.readfile(cache_file)
end

local function build_repo_cache(ctx, cache_file)
  local dir = vim.fn.fnamemodify(cache_file, ":h")
  local tmp_file = cache_file .. ".tmp." .. tostring(uv.hrtime())
  local lines = vim.fn.systemlist({
    "git",
    "-c",
    "core.quotePath=false",
    "-C",
    ctx.root,
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "--deduplicate",
  })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  vim.fn.mkdir(dir, "p")
  vim.fn.writefile(lines, tmp_file)
  vim.fn.rename(tmp_file, cache_file)
  return lines
end

local function refresh_repo_cache_async(ctx, cache_file)
  vim.fn.mkdir(vim.fn.fnamemodify(cache_file, ":h"), "p")
  local lock_file = cache_file .. ".lock"
  local lock_fd = uv.fs_open(lock_file, "wx", 420)
  if not lock_fd then
    return
  end
  uv.fs_close(lock_fd)

  local shell = vim.o.shell ~= "" and vim.o.shell or "sh"
  local shellescape = vim.fn.shellescape
  local root = shellescape(ctx.root)
  local tmp_file = shellescape(cache_file .. ".tmp." .. tostring(uv.hrtime()))
  local cache_target = shellescape(cache_file)
  local lock_target = shellescape(lock_file)
  local command = table.concat({
    'trap "rm -f ' .. lock_target .. " " .. tmp_file .. '" EXIT',
    "git -c core.quotePath=false -C " .. root .. " ls-files --cached --others --exclude-standard --deduplicate > " .. tmp_file,
    "mv " .. tmp_file .. " " .. cache_target,
  }, " && ")

  local job = vim.fn.jobstart({ shell, "-lc", command }, { detach = true })
  if job <= 0 then
    vim.fn.delete(lock_file)
  end
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
  local include_untracked = opts.include_untracked ~= false
  local force_refresh = opts.refresh == true
  opts.scope = nil
  opts.include_untracked = nil
  opts.refresh = nil
  local cache_file = repo_cache_file(ctx.root)
  local cache_key = table.concat({
    ctx.root,
    scope_prefix or "__repo__",
    include_untracked and "all" or "tracked",
  }, "::")
  local cache_token = repo_cache_token(ctx)
  local cached = cache[cache_key]
  local cache_is_fresh = not include_untracked

  local results
  if cached and cached.token == cache_token and not force_refresh then
    results = cached.results
    cache_is_fresh = true
  elseif not include_untracked then
    results = tracked_repo_files(ctx, scope_prefix)
    if results then
      cache[cache_key] = { token = cache_token, results = results }
    elseif cached and cached.results then
      results = cached.results
      vim.notify("git ls-files failed; showing cached file list", vim.log.levels.WARN)
    else
      vim.notify("git ls-files failed; falling back to find_files", vim.log.levels.WARN)
      local fallback_opts = vim.deepcopy(opts)
      fallback_opts.scope = nil
      fallback_opts.include_untracked = nil
      fallback_opts.cwd = scope_prefix and joinpath(ctx.root, scope_prefix) or ctx.root
      require("telescope.builtin").find_files(M.find_files_opts(fallback_opts))
      return
    end
  else
    local repo_files
    if force_refresh then
      repo_files = build_repo_cache(ctx, cache_file)
      cache_is_fresh = repo_files ~= nil
      if not repo_files then
        repo_files = load_repo_cache(cache_file)
      end
    else
      repo_files = load_repo_cache(cache_file)
      if not repo_files then
        repo_files = build_repo_cache(ctx, cache_file)
        cache_is_fresh = repo_files ~= nil
      elseif repo_cache_needs_refresh(ctx, cache_file) then
        refresh_repo_cache_async(ctx, cache_file)
        cache_is_fresh = false
      else
        cache_is_fresh = true
      end
    end

    if repo_files then
      results = repo_files
    elseif cached and cached.results then
      results = cached.results
      vim.notify("repo file cache refresh failed; showing cached file list", vim.log.levels.WARN)
    else
      vim.notify("repo file cache build failed; falling back to find_files", vim.log.levels.WARN)
      local fallback_opts = vim.deepcopy(opts)
      fallback_opts.scope = nil
      fallback_opts.include_untracked = nil
      fallback_opts.cwd = scope_prefix and joinpath(ctx.root, scope_prefix) or ctx.root
      require("telescope.builtin").find_files(M.find_files_opts(fallback_opts))
      return
    end
  end

  local filtered = {}
  for _, path in ipairs(results) do
    if (not scope_prefix or is_prefix(path, scope_prefix)) and not ctx.should_ignore(path) then
      table.insert(filtered, path)
    end
  end

  if cache_is_fresh then
    cache[cache_key] = { token = cache_token, results = filtered }
  else
    cache[cache_key] = nil
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  pickers
    .new(opts, {
      prompt_title = scope_prefix
          and ((include_untracked and "Git Files + Untracked" or "Git Files") .. " (" .. scope_prefix .. ")")
        or (include_untracked and "Git Files + Untracked" or "Git Files"),
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
  local opts = vim.deepcopy(extra or {})
  local scope = opts.scope or "auto"
  local explicit_cwd = opts.cwd ~= nil
  local globs = opts.globs
  if type(globs) == "string" then
    globs = { globs }
  elseif type(globs) ~= "table" then
    globs = {}
  end

  opts.scope = nil
  opts.globs = nil

  local scope_prefix = explicit_cwd and nil or scope_prefix_for(ctx, scope)
  local joinpath = (vim.fs and vim.fs.joinpath)
    or function(...)
      return table.concat({ ... }, "/")
    end
  local scope_cwd = scope_prefix and joinpath(ctx.root, scope_prefix) or nil

  local function additional_args()
    local args = {}

    if not scope_prefix then
      for _, glob in ipairs(ctx.rg_globs) do
        table.insert(args, "--glob")
        table.insert(args, glob)
      end
    end

    for _, glob in ipairs(globs) do
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
