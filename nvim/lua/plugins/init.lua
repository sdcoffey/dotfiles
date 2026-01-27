return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter.configs")
      if not ok then
        return
      end
      ts.setup({
        ensure_installed = {
          "bash",
          "c",
          "cpp",
          "css",
          "go",
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
          "regex",
          "rust",
          "tsx",
          "typescript",
          "vim",
          "yaml",
        },
        highlight = { enabled = true },
        indent = { enabled = true },
      })
    end,
  },

  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
      {
        "<leader>ff",
        function()
          local repo = require("config.telescope")
          repo.git_files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          local repo = require("config.telescope")
          require("telescope.builtin").live_grep(repo.live_grep_opts())
        end,
        desc = "Live grep",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Buffers",
      },
      {
        "<M-F12>",
        function()
          require("telescope.builtin").lsp_document_symbols()
        end,
        desc = "Document symbols",
      },
      {
        "<leader>fS",
        function()
          require("telescope.builtin").lsp_dynamic_workspace_symbols()
        end,
        desc = "Workspace symbols",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make"
      }
    },
    config = function()
      local telescope = require("telescope");
      telescope.setup({
        defaults = {
          layout_config = { prompt_position = "top" },
          preview = false,
          max_results = 4000,
          sorting_strategy = "ascending",
        },
        fzf = {
          fuzzy = true,                   -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true,
        },
        layout_config = {
          horizontal = {
            width = 0.9,
            heigt = 0.85
          }
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format buffer",
      },
    },
    config = function()
      local conform = require("conform")
      conform.setup({
        formatters_by_ft = {
          python = { "ruff_format" },
          rust = { "rustfmt" },
          go = { "gofmt" },
          typescript = { "prettier" },
          javascript = { "prettier" },
          astro = { "prettier" }
        },
        format_on_save = function(_bufnr)
          return {
            timeout_ms = 2000,
            lsp_fallback = true,
          }
        end,
      })
    end,
  },

  {
    "vim-test/vim-test",
    cmd = { "TestFile", "TestNearest", "TestLast", "TestSuite" },
    keys = {
      { "<leader>tf", ":TestFile<CR>",    desc = "Test file" },
      { "<leader>rf", ":TestNearest<CR>", desc = "Test nearest" },
      { "<leader>tl", ":TestLast<CR>",    desc = "Test last" },
      { "<leader>ts", ":TestSuite<CR>",   desc = "Test suite" },
    },
    config = function()
      vim.g["test#python#runner"] = "pytest"
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup()
    end,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = {
      { "<leader>nt", ":Neotree toggle<CR>", desc = "Neo-tree toggle" },
      { "<leader>nf", ":Neotree reveal<CR>", desc = "Neo-tree reveal file" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        filesystem = {
          follow_current_file = { enabled = true },
          hijack_netrw_behavior = "open_default",
          use_libuv_file_watcher = true,
        },
        window = {
          position = "left",
          width = 36,
        },
      })
    end,
  },

  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "bashls",
          "gopls",
          "jsonls",
          "lua_ls",
          "pyright",
          "ruby_lsp",
          "rust_analyzer",
          "ts_ls",
          "yamlls",
        },
        automatic_enable = false,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded" },
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local python_root_markers = {
        "pyrightconfig.json",
        "pyproject.toml",
        "setup.py",
        "setup.cfg",
        "requirements.txt",
        "Pipfile",
        ".git",
      }

      local default_pyright_on_attach = vim.lsp.config.pyright and vim.lsp.config.pyright.on_attach or nil

      local function venv_from_env()
        local venv = vim.env.VIRTUAL_ENV
        if not venv or venv == "" then
          return nil
        end
        return vim.fn.fnamemodify(venv, ":h"), vim.fn.fnamemodify(venv, ":t")
      end

      local function repo_root_from(root_dir)
        local git_dir = vim.fs.find(".git", { path = root_dir, upward = true })[1]
        return git_dir and vim.fs.dirname(git_dir) or root_dir
      end

      local function venv_from_external(root_dir)
        if not root_dir or root_dir == "" then
          return nil
        end

        local repo_root = repo_root_from(root_dir)
        local repo_name = vim.fn.fnamemodify(repo_root, ":t")
        local override_file = vim.fn.stdpath("config") .. "/venvs/" .. repo_name
        if vim.fn.filereadable(override_file) ~= 1 then
          return nil
        end

        local lines = vim.fn.readfile(override_file)
        local venv_dir = lines[1] and vim.trim(lines[1]) or ""
        if venv_dir == "" or vim.fn.isdirectory(venv_dir) ~= 1 then
          return nil
        end

        return vim.fn.fnamemodify(venv_dir, ":h"), vim.fn.fnamemodify(venv_dir, ":t")
      end

      local function venv_from_root(root_dir)
        local candidates = {
          root_dir .. "/.venv",
          root_dir .. "/venv",
          root_dir .. "/.env",
        }
        for _, path in ipairs(candidates) do
          if vim.fn.isdirectory(path) == 1 then
            return root_dir, vim.fn.fnamemodify(path, ":t")
          end
        end
        return nil
      end

      local function venv_from_virtualenvs(root_dir)
        if not root_dir or root_dir == "" then
          return nil
        end

        local repo_root = repo_root_from(root_dir)
        local repo_name = vim.fn.fnamemodify(repo_root, ":t")
        local path = vim.fn.expand("~/.virtualenvs/" .. repo_name)
        if vim.fn.isdirectory(path) == 1 then
          return vim.fn.expand("~/.virtualenvs"), repo_name
        end
        return nil
      end

      local function resolve_pyright_env(root_dir)
        local venv_path, venv = venv_from_external(root_dir)
        if not venv_path then
          venv_path, venv = venv_from_env()
        end
        if not venv_path then
          venv_path, venv = venv_from_root(root_dir)
        end
        if not venv_path then
          venv_path, venv = venv_from_virtualenvs(root_dir)
        end
        if not venv_path or not venv then
          return nil
        end

        local python_path = venv_path .. "/" .. venv .. "/bin/python"
        if vim.fn.executable(python_path) ~= 1 then
          python_path = nil
        end

        local env = {
          venvPath = venv_path,
          venv = venv,
        }
        if python_path then
          env.pythonPath = python_path
        end
        return env
      end

      local function set_pyright_venv(config, root_dir)
        local env = resolve_pyright_env(root_dir)
        if not env then
          return
        end
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
          python = env,
        })
      end

      local function apply_pyright_settings(client)
        local root_dir = client.config.root_dir or vim.fn.getcwd()
        local env = resolve_pyright_env(root_dir)
        if not env then
          return
        end

        client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
          python = env,
        })

        client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
          python = env,
        })

        client:notify("workspace/didChangeConfiguration", {
          settings = client.config.settings,
        })
      end

      local pyright_cmd = { vim.fn.stdpath("config") .. "/bin/pyright-langserver", "--stdio" }

      local servers = {
        bashls = {},
        gopls = {},
        jsonls = {},
        pyright = {
          cmd = pyright_cmd,
          root_markers = python_root_markers,
          before_init = function(params, config)
            local root_dir
            if params.rootUri and params.rootUri ~= vim.NIL then
              root_dir = vim.uri_to_fname(params.rootUri)
            elseif params.rootPath and params.rootPath ~= vim.NIL then
              root_dir = params.rootPath
            else
              root_dir = vim.fn.getcwd()
            end
            set_pyright_venv(config, root_dir)
          end,
          on_attach = function(client, bufnr)
            if default_pyright_on_attach then
              pcall(default_pyright_on_attach, client, bufnr)
            end
            apply_pyright_settings(client)
          end,
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
              },
            },
          },
        },
        ruby_lsp = {},
        rust_analyzer = {},
        ts_ls = {},
        yamlls = {},
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
      }

      for server_name, server_opts in pairs(servers) do
        local opts = vim.tbl_deep_extend("force", { capabilities = capabilities }, server_opts)
        vim.lsp.config(server_name, opts)
        vim.lsp.enable(server_name)
      end
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
      })
    end,
  },
  {
    "sdcoffey/codex-inline-edits.nvim",
    build = "npm install",
    lazy = false
  }
}
