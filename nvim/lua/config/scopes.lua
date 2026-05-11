local M = {}

local uv = vim.uv or vim.loop

local joinpath = (vim.fs and vim.fs.joinpath)
  or function(...)
    return table.concat({ ... }, "/")
  end

local state_by_root = {}

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
  path = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
  root = vim.fn.fnamemodify(root, ":p"):gsub("/+$", "")

  if path == root then
    return nil
  end

  if vim.fs and vim.fs.relative then
    local rel = vim.fs.relative(path, root)
    if rel and rel ~= "." then
      return rel:gsub("/+$", "")
    end
    return nil
  end

  if is_prefix(path, root) then
    return path:sub(#root + 2):gsub("/+$", "")
  end

  return nil
end

local function repo_name(root)
  return vim.fn.fnamemodify(root, ":t")
end

local function private_scopes_dir()
  return joinpath(vim.fn.stdpath("state"), "scopes")
end

local function config_scopes_dir()
  return joinpath(vim.fn.stdpath("config"), "scopes")
end

local function scopes_dirs()
  return {
    private_scopes_dir(),
    config_scopes_dir(),
  }
end

local function basename_profile_file(root, dir)
  return joinpath(dir, repo_name(root) .. ".lua")
end

local function private_basename_profile_file(root)
  return basename_profile_file(root, private_scopes_dir())
end

local function normalize_remote(remote)
  local value = vim.trim(remote or "")
  if value == "" then
    return nil
  end

  value = value:gsub("%.git$", "")

  local host, repo_path = value:match("^[^@]+@([^:]+):(.+)$")
  if not host then
    host, repo_path = value:match("^https?://([^/]+)/(.+)$")
  end
  if not host then
    host, repo_path = value:match("^ssh://[^@]+@([^/]+)/(.+)$")
  end
  if not host then
    host, repo_path = value:match("^([^/]+)/(.*)$")
  end
  if not host or not repo_path then
    return value:lower()
  end

  if host:match("github") then
    host = "github.com"
  end

  return (host .. "/" .. repo_path:gsub("%.git$", "")):lower()
end

local function repo_remote(root)
  local remotes = vim.fn.systemlist({ "git", "-C", root, "remote", "get-url", "origin" })
  if vim.v.shell_error ~= 0 or not remotes[1] then
    return nil
  end
  return normalize_remote(remotes[1])
end

local function normalize_path(path, root, opts)
  opts = opts or {}
  local text = vim.trim(path or "")
  if text == "" then
    return nil, "empty path"
  end

  local expanded = vim.fn.expand(text)
  local absolute = vim.startswith(expanded, "/")
  local candidate = absolute and expanded or joinpath(root, expanded)
  candidate = vim.fn.fnamemodify(candidate, ":p"):gsub("/+$", "")

  if opts.must_exist and vim.fn.isdirectory(candidate) ~= 1 then
    return nil, "directory not found: " .. candidate
  end

  local rel = relative_path(candidate, root)
  if not rel then
    return nil, "path is not inside repo: " .. candidate
  end

  return rel
end

local function copy_list(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    table.insert(out, value)
  end
  return out
end

local function normalize_profiles(data, root)
  local raw_profiles = data
  if type(data) == "table" and type(data.profiles) == "table" then
    raw_profiles = data.profiles
  end

  local profiles = {}
  if type(raw_profiles) ~= "table" then
    return profiles
  end

  for name, paths in pairs(raw_profiles) do
    if type(name) == "string" and type(paths) == "table" then
      profiles[name] = {}
      for _, path in ipairs(paths) do
        if type(path) == "string" then
          local rel = normalize_path(path, root)
          if rel then
            table.insert(profiles[name], rel)
          end
        end
      end
    end
  end

  return profiles
end

local function load_profile_file(file, opts)
  opts = opts or {}
  if vim.fn.filereadable(file) ~= 1 then
    return nil
  end

  local ok, data = pcall(dofile, file)
  if not ok then
    if opts.notify ~= false then
      vim.notify("Failed to load scope profiles: " .. tostring(data), vim.log.levels.ERROR)
    end
    return nil
  end

  return data
end

local function declared_remote(data)
  if type(data) ~= "table" or type(data.remote) ~= "string" then
    return nil
  end
  return normalize_remote(data.remote)
end

local function scope_files()
  local files = {}
  for _, dir in ipairs(scopes_dirs()) do
    local dir_files = vim.fn.globpath(dir, "*.lua", false, true)
    table.sort(dir_files)
    vim.list_extend(files, dir_files)
  end
  return files
end

local function remote_matched_profile_file(remote)
  if not remote then
    return nil
  end

  for _, file in ipairs(scope_files()) do
    local data = load_profile_file(file, { notify = false })
    if declared_remote(data) == remote then
      return file
    end
  end

  return nil
end

local function fallback_profile_file(root, remote)
  for _, dir in ipairs(scopes_dirs()) do
    local file = basename_profile_file(root, dir)
    local data = load_profile_file(file, { notify = false })
    if data then
      local file_remote = declared_remote(data)
      if not remote or not file_remote or file_remote == remote then
        return file
      end

      return joinpath(private_scopes_dir(), repo_name(root) .. "-" .. vim.fn.sha256(remote):sub(1, 8) .. ".lua")
    end
  end

  return private_basename_profile_file(root)
end

local function selected_profile_file(root, remote)
  return remote_matched_profile_file(remote) or fallback_profile_file(root, remote)
end

local function load_profiles(root)
  local remote = repo_remote(root)
  local file = selected_profile_file(root, remote)
  local data = load_profile_file(file)
  if not data then
    return {}, file, remote
  end

  return normalize_profiles(data, root), file, remote or declared_remote(data)
end

local function sorted_profile_names(profiles)
  local names = {}
  for name, _ in pairs(profiles) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

local function state(root)
  root = root or git_root()
  local current = state_by_root[root]
  if current then
    return current
  end

  local profiles, file, remote = load_profiles(root)
  local active_name = profiles.default and "default" or nil
  current = {
    root = root,
    file = file,
    remote = remote,
    profiles = profiles,
    active_name = active_name,
    active_paths = copy_list(active_name and profiles[active_name] or {}),
    dirty = false,
  }
  state_by_root[root] = current
  return current
end

local function current_path()
  local file = vim.api.nvim_buf_get_name(0)
  if file and file ~= "" then
    return vim.fn.fnamemodify(file, ":h")
  end
  return uv.cwd()
end

local function contains(paths, path)
  for _, existing in ipairs(paths) do
    if existing == path then
      return true
    end
  end
  return false
end

local function lua_string(value)
  return string.format("%q", value)
end

local function lua_key(name)
  if name:match("^[%a_][%w_]*$") then
    return name
  end
  return "[" .. lua_string(name) .. "]"
end

local function serialize_profiles(profiles, remote)
  local lines = { "return {" }
  if remote and remote ~= "" then
    table.insert(lines, "  remote = " .. lua_string(remote) .. ",")
    table.insert(lines, "  profiles = {")
  end

  for _, name in ipairs(sorted_profile_names(profiles)) do
    local indent = remote and "    " or "  "
    table.insert(lines, indent .. lua_key(name) .. " = {")
    for _, path in ipairs(profiles[name]) do
      table.insert(lines, indent .. "  " .. lua_string(path) .. ",")
    end
    table.insert(lines, indent .. "},")
    table.insert(lines, "")
  end

  if lines[#lines] == "" then
    table.remove(lines)
  end
  if remote and remote ~= "" then
    table.insert(lines, "  },")
  end
  table.insert(lines, "}")
  table.insert(lines, "")
  return lines
end

function M.repo_root()
  return git_root()
end

function M.profile_file(root)
  return state(root).file
end

function M.profile_names(root)
  return sorted_profile_names(state(root).profiles)
end

function M.active(root)
  local s = state(root)
  if not s.active_name or #s.active_paths == 0 then
    return nil
  end

  return {
    name = s.active_name,
    paths = copy_list(s.active_paths),
    dirty = s.dirty,
    file = s.file,
    remote = s.remote,
  }
end

function M.select(name, root)
  local s = state(root)
  if not s.profiles[name] then
    return false, "unknown scope profile: " .. name
  end

  s.active_name = name
  s.active_paths = copy_list(s.profiles[name])
  s.dirty = false
  return true
end

function M.clear(root)
  local s = state(root)
  s.active_name = nil
  s.active_paths = {}
  s.dirty = false
end

function M.add(path, root)
  local s = state(root)
  if not path or vim.trim(path) == "" then
    path = current_path()
  end
  local rel, err = normalize_path(path, s.root, { must_exist = true })
  if not rel then
    return false, err
  end

  if not s.active_name then
    s.active_name = "scratch"
    s.active_paths = {}
  end

  if contains(s.active_paths, rel) then
    return true, rel
  end

  table.insert(s.active_paths, rel)
  table.sort(s.active_paths)
  s.dirty = true
  return true, rel
end

function M.remove(path, root)
  local s = state(root)
  if not s.active_name then
    return false, "no active scope"
  end

  local target = path
  if target and target ~= "" then
    target = normalize_path(target, s.root) or vim.trim(path)
  end

  for index, existing in ipairs(s.active_paths) do
    if existing == target then
      table.remove(s.active_paths, index)
      s.dirty = true
      return true, existing
    end
  end

  return false, "path is not in active scope: " .. tostring(path)
end

function M.save(root)
  local s = state(root)
  if not s.active_name then
    return false, "no active scope"
  end

  s.profiles[s.active_name] = copy_list(s.active_paths)
  vim.fn.mkdir(vim.fn.fnamemodify(s.file, ":h"), "p")
  vim.fn.writefile(serialize_profiles(s.profiles, s.remote), s.file)
  s.dirty = false
  return true, s.file
end

function M.reload(root)
  root = root or git_root()
  state_by_root[root] = nil
  return state(root)
end

return M
