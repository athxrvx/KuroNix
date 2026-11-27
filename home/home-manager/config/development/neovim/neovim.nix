# ─────────────────────────────────────────────────────────────────────────────
# Neovim (single-file) — Home Manager module, plugins managed by lazy.nvim
#
#   Nix        -> neovim, LSP servers, formatters, linters, compilers, wl-clipboard
#   lazy.nvim  -> plugins (cloned on first launch into ~/.local/share/nvim/lazy)
#
# Import from your Home Manager config:
#   home-manager.users.<you> = { imports = [ ./home.nix ]; };
#
# Theme: ~/.config/nvim/colors/kuro.lua is written by kurogen itself; this module
# does not create, link or manage it. Neovim just loads `colorscheme kuro`.
#
# Leader = Space.
#   ff files · fg grep · fb buffers · fr recent · fh help · fd diagnostics
#   fG git files · fc cmd history · e Oil · E nvim-tree · w save · q quit
#   ca code action · rn rename · d diagnostics float · f format
#   gg Fugitive · gd Diffview · tt TODOs · xx Trouble
#   ha harpoon add · hh harpoon menu · 1-4 harpoon select
#   y/Y yank to system clipboard (wl-clipboard) · ts/tv terminal
#   bd delete buffer · bo only buffer · uw wrap · uf format-on-save · uk reload Kuro
# Plugin manager UI: :Lazy
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;

    # Tools visible to Neovim only (no Mason needed; Mason binaries break on NixOS).
    extraPackages = with pkgs; [
      # lazy.nvim + plugin builds (treesitter parsers, telescope-fzf-native)
      git
      gcc
      gnumake
      curl

      # utilities
      ripgrep
      fd
      wl-clipboard

      # Nix
      nil
      (pkgs.nixfmt or pkgs.nixfmt-rfc-style)

      # Lua
      lua-language-server
      stylua

      # Python
      pyright
      ruff

      # TypeScript / JavaScript
      (pkgs.typescript-language-server or pkgs.nodePackages.typescript-language-server)
      (pkgs.prettier or pkgs.nodePackages.prettier)
      (pkgs.eslint or pkgs.nodePackages.eslint)

      # Rust
      rust-analyzer
      rustfmt

      # C / C++
      clang-tools

      # HTML / CSS / JSON
      vscode-langservers-extracted

      # Bash
      bash-language-server
      shfmt
      shellcheck

      # YAML / Markdown
      yaml-language-server
      marksman
    ];

    extraLuaConfig = ''
      -- ═══════════════════════════════════════════════════════════════════
      -- Prelude
      -- ═══════════════════════════════════════════════════════════════════
      local function notify(msg, level)
        vim.schedule(function()
          vim.notify(msg, level or vim.log.levels.WARN, { title = "nvim" })
        end)
      end

      local function safe(label, fn)
        local ok, err = pcall(fn)
        if not ok then notify(label .. ": " .. tostring(err), vim.log.levels.ERROR) end
        return ok
      end

      local function map(mode, lhs, rhs, desc, opts)
        opts = opts or {}
        opts.desc = desc
        if opts.silent == nil then opts.silent = true end
        vim.keymap.set(mode, lhs, rhs, opts)
      end

      -- lazy.nvim `keys` entry helper
      local function k(lhs, rhs, desc, mode)
        return { lhs, rhs, desc = desc, mode = mode }
      end

      local uv = vim.uv or vim.loop
      local augroup = vim.api.nvim_create_augroup("NixNvim", { clear = true })
      local function au(event, opts)
        opts.group = augroup
        vim.api.nvim_create_autocmd(event, opts)
      end

      -- ═══════════════════════════════════════════════════════════════════
      -- Editor options
      -- ═══════════════════════════════════════════════════════════════════
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local o = vim.opt
      o.termguicolors = true
      o.number = true
      o.relativenumber = true
      o.cursorline = true
      o.signcolumn = "yes"
      o.scrolloff = 8
      o.sidescrolloff = 8
      o.showmode = false
      o.laststatus = 3
      o.pumheight = 12
      o.fillchars = { eob = " " }
      o.list = true
      o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
      o.wrap = false
      o.linebreak = true
      o.breakindent = true
      pcall(function() vim.o.winborder = "rounded" end) -- Neovim 0.11+

      o.tabstop = 2
      o.shiftwidth = 2
      o.softtabstop = 2
      o.expandtab = true
      o.smartindent = true
      o.undofile = true
      o.swapfile = false
      o.backup = false
      o.ignorecase = true
      o.smartcase = true
      o.inccommand = "split"
      o.autoread = true
      o.confirm = true
      o.completeopt = { "menu", "menuone", "noselect" }
      o.shortmess:append("cI")
      if vim.fn.executable("rg") == 1 then
        o.grepprg = "rg --vimgrep --smart-case"
        o.grepformat = "%f:%l:%c:%m"
      end

      o.mouse = "a"
      o.splitright = true
      o.splitbelow = true
      o.updatetime = 250
      o.timeoutlen = 300
      o.ttimeoutlen = 10
      o.wildmode = "longest:full,full"
      o.wildoptions = "pum"

      -- ═══════════════════════════════════════════════════════════════════
      -- Clipboard (wl-clipboard)
      -- ═══════════════════════════════════════════════════════════════════
      if vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1
          and vim.fn.executable("wl-paste") == 1 then
        vim.g.clipboard = {
          name = "wl-clipboard",
          copy = {
            ["+"] = { "wl-copy", "--foreground", "--type", "text/plain" },
            ["*"] = { "wl-copy", "--foreground", "--primary", "--type", "text/plain" },
          },
          paste = {
            ["+"] = { "wl-paste", "--no-newline" },
            ["*"] = { "wl-paste", "--no-newline", "--primary" },
          },
          cache_enabled = 0,
        }
      end
      o.clipboard = "unnamedplus"

      -- ═══════════════════════════════════════════════════════════════════
      -- Kuro colour helpers (derive from Kuro groups; no own palette)
      -- ═══════════════════════════════════════════════════════════════════
      local function hl_get(group)
        local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
        return (ok and h) or {}
      end
      local function hex(n) return n and string.format("#%06x", n) or nil end
      local function fg(group, default) return hex(hl_get(group).fg) or default end
      local function bgc(group, default) return hex(hl_get(group).bg) or default end

      local function blend(a, b, t)
        if not (a and b) then return a or b end
        local function rgb(h)
          return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)
        end
        local ar, ag, ab = rgb(a)
        local br, bg_, bb = rgb(b)
        local function mix(x, y) return math.floor(x + (y - x) * t + 0.5) end
        return string.format("#%02x%02x%02x", mix(ar, br), mix(ag, bg_), mix(ab, bb))
      end

      local kuro_file = vim.fn.stdpath("config") .. "/colors/kuro.lua"

      -- Groups the generator defines; we never override those.
      local function generated_groups()
        local set = {}
        local file = vim.api.nvim_get_runtime_file("colors/kuro.lua", false)[1]
        if file then
          local ok, lines = pcall(vim.fn.readfile, file)
          for _, line in ipairs(ok and lines or {}) do
            local n = line:match("^%s*([%w_%.@]+)%s*=%s*{")
              or line:match('^%s*%["([^"]+)"%]%s*=%s*{')
            if n then set[n] = true end
          end
        end
        return set
      end

      -- ═══════════════════════════════════════════════════════════════════
      -- Plugin highlight customisation (links + colours derived from Kuro)
      -- ═══════════════════════════════════════════════════════════════════
      local function apply_highlights()
        local generated = generated_groups()
        local function set(name, spec) vim.api.nvim_set_hl(0, name, spec) end
        local function link(name, to) vim.api.nvim_set_hl(0, name, { link = to }) end
        local function links(tbl) for name, to in pairs(tbl) do link(name, to) end end
        local function fallback(name, spec) if not generated[name] then set(name, spec) end end

        fallback("SignColumn", { link = "Normal" })
        fallback("EndOfBuffer", { fg = bgc("Normal") })
        fallback("MsgArea", { link = "Normal" })
        fallback("Directory", { link = "Function" })
        fallback("Title", { link = "Keyword" })
        fallback("FloatTitle", { link = "Keyword" })
        fallback("MatchParen", { link = "IncSearch" })
        fallback("NonText", { link = "Comment" })
        fallback("SpecialKey", { link = "Comment" })
        fallback("Whitespace", { link = "Comment" })
        fallback("Folded", { link = "Comment" })
        fallback("ColorColumn", { bg = bgc("CursorLine") })
        fallback("ErrorMsg", { link = "DiagnosticError" })
        fallback("WarningMsg", { link = "DiagnosticWarn" })
        fallback("MoreMsg", { link = "String" })
        fallback("Question", { link = "String" })
        fallback("PmenuSbar", { bg = bgc("NormalFloat") })
        fallback("PmenuThumb", { bg = fg("LineNr") })
        fallback("WinBar", { link = "Normal" })
        fallback("WinBarNC", { link = "Comment" })
        fallback("Delimiter", { link = "Operator" })
        fallback("DiffText", { bg = blend(bgc("Normal"), fg("DiffChange"), 0.3) })
        fallback("DiagnosticOk", { link = "String" })

        for _, s in ipairs({
          { "Error", "DiagnosticError" }, { "Warn", "DiagnosticWarn" },
          { "Info", "DiagnosticInfo" }, { "Hint", "DiagnosticHint" },
        }) do
          local colour = fg(s[2])
          fallback("DiagnosticUnderline" .. s[1], { undercurl = true, sp = colour })
          fallback("DiagnosticVirtualText" .. s[1],
            { fg = colour, bg = blend(bgc("Normal"), colour, 0.12) })
          fallback("DiagnosticSign" .. s[1], { link = s[2] })
        end

        links({
          -- Telescope
          TelescopeNormal = "NormalFloat", TelescopeBorder = "FloatBorder",
          TelescopeTitle = "Keyword",
          TelescopePromptNormal = "NormalFloat", TelescopePromptBorder = "FloatBorder",
          TelescopePromptTitle = "Keyword", TelescopePromptPrefix = "Function",
          TelescopePromptCounter = "Comment",
          TelescopeResultsNormal = "NormalFloat", TelescopeResultsBorder = "FloatBorder",
          TelescopeResultsTitle = "Comment",
          TelescopePreviewNormal = "NormalFloat", TelescopePreviewBorder = "FloatBorder",
          TelescopePreviewTitle = "String",
          TelescopeSelection = "PmenuSel", TelescopeSelectionCaret = "PmenuSel",
          TelescopeMultiSelection = "Visual", TelescopeMatching = "Search",
          -- nvim-cmp
          CmpItemAbbr = "Pmenu", CmpItemMenu = "Comment",
          CmpItemKindFunction = "Function", CmpItemKindMethod = "Function",
          CmpItemKindConstructor = "Function",
          CmpItemKindField = "Identifier", CmpItemKindProperty = "Identifier",
          CmpItemKindVariable = "Identifier",
          CmpItemKindClass = "Type", CmpItemKindInterface = "Type",
          CmpItemKindStruct = "Type", CmpItemKindEnum = "Type",
          CmpItemKindTypeParameter = "Type", CmpItemKindModule = "Type",
          CmpItemKindKeyword = "Keyword", CmpItemKindSnippet = "Special",
          CmpItemKindText = "String", CmpItemKindConstant = "Constant",
          CmpItemKindValue = "Constant", CmpItemKindEnumMember = "Constant",
          CmpItemKindOperator = "Operator", CmpItemKindFile = "Special",
          CmpItemKindFolder = "Special", CmpItemKindUnit = "Number",
          -- Noice
          NoiceCmdlinePopup = "NormalFloat", NoiceCmdlinePopupBorder = "FloatBorder",
          NoiceCmdlinePopupTitle = "Keyword", NoiceCmdlineIcon = "Function",
          NoiceConfirm = "NormalFloat", NoiceConfirmBorder = "FloatBorder",
          NoicePopup = "NormalFloat", NoicePopupBorder = "FloatBorder",
          NoicePopupmenu = "Pmenu", NoicePopupmenuBorder = "FloatBorder",
          NoicePopupmenuSelected = "PmenuSel", NoiceMini = "NormalFloat",
          NoiceCursor = "Cursor",
          -- Trouble
          TroubleNormal = "Normal", TroubleNormalNC = "Normal", TroubleText = "Normal",
          TroublePreview = "Visual", TroubleCount = "Number",
          -- Which-Key
          WhichKey = "Function", WhichKeyGroup = "Keyword", WhichKeyDesc = "NormalFloat",
          WhichKeyNormal = "NormalFloat", WhichKeyBorder = "FloatBorder",
          WhichKeyTitle = "Keyword", WhichKeySeparator = "Comment", WhichKeyValue = "Comment",
          -- Oil
          OilDir = "Function", OilDirIcon = "Function", OilLink = "Special",
          OilLinkTarget = "Comment", OilFile = "Normal",
          OilCreate = "GitSignsAdd", OilCopy = "GitSignsAdd", OilRestore = "GitSignsAdd",
          OilChange = "GitSignsChange", OilMove = "GitSignsChange",
          OilDelete = "GitSignsDelete", OilPurge = "GitSignsDelete",
          OilTrash = "Comment", OilTrashSourcePath = "Comment",
          -- nvim-tree, flash, indent guides, lazy UI
          NvimTreeNormal = "Normal", NvimTreeFolderIcon = "Function",
          NvimTreeRootFolder = "Keyword",
          FlashMatch = "Search", FlashCurrent = "IncSearch", FlashLabel = "IncSearch",
          FlashBackdrop = "Comment",
          IblScope = "Keyword",
          LazyNormal = "NormalFloat", LazyButton = "Pmenu", LazyButtonActive = "PmenuSel",
          LazyH1 = "PmenuSel", LazyH2 = "Keyword", LazyProp = "Comment",
          LazyReasonPlugin = "Function", LazyReasonEvent = "Constant",
        })
        link("GitSignsCurrentLineBlame", "Comment")
        for _, kind in ipairs({ "Add", "Change", "Delete" }) do
          link("GitSigns" .. kind .. "Nr", "GitSigns" .. kind)
          link("GitSigns" .. kind .. "Ln", "GitSigns" .. kind)
        end

        -- nvim-notify
        for level, to in pairs({
          ERROR = "DiagnosticError", WARN = "DiagnosticWarn", INFO = "DiagnosticInfo",
          DEBUG = "Comment", TRACE = "DiagnosticHint",
        }) do
          links({
            ["Notify" .. level .. "Border"] = to,
            ["Notify" .. level .. "Icon"] = to,
            ["Notify" .. level .. "Title"] = to,
            ["Notify" .. level .. "Body"] = "NormalFloat",
          })
        end
        link("NotifyBackground", "NormalFloat")

        set("CmpItemAbbrDeprecated", { fg = fg("Comment"), strikethrough = true })
        set("CmpItemAbbrMatch", { fg = fg("Function"), bold = true })
        set("CmpItemAbbrMatchFuzzy", { fg = fg("Function"), bold = true })
        set("IblIndent", { fg = blend(bgc("Normal"), fg("Comment"), 0.25) })
        set("IblWhitespace", { fg = blend(bgc("Normal"), fg("Comment"), 0.25) })
      end

      -- ═══════════════════════════════════════════════════════════════════
      -- Statusline / bufferline built from Kuro groups
      -- ═══════════════════════════════════════════════════════════════════
      local function lualine_theme()
        local text = fg("StatusLine", "NONE")
        local function mode(colour)
          return { fg = text, bg = colour or fg("Keyword", "NONE"), gui = "bold" }
        end
        local b = { fg = fg("Normal", "NONE"), bg = bgc("NormalFloat", "NONE") }
        local c = { fg = fg("Comment", "NONE"), bg = bgc("Normal", "NONE") }
        return {
          normal   = { a = mode(), b = b, c = c },
          insert   = { a = mode(fg("String")), b = b, c = c },
          visual   = { a = mode(bgc("Visual")), b = b, c = c },
          replace  = { a = mode(fg("DiagnosticError")), b = b, c = c },
          command  = { a = mode(bgc("IncSearch")), b = b, c = c },
          terminal = { a = mode(fg("Type")), b = b, c = c },
          inactive = { a = c, b = c, c = c },
        }
      end

      local function setup_lualine()
        safe("lualine", function()
          require("lualine").setup({
            options = {
              theme = lualine_theme(),
              globalstatus = true,
              component_separators = { left = "", right = "" },
              section_separators = { left = "", right = "" },
            },
            sections = {
              lualine_a = { "mode" },
              lualine_b = {
                "branch",
                { "diff", symbols = { added = "+", modified = "~", removed = "-" } },
              },
              lualine_c = {
                { "filename", path = 1,
                  symbols = { modified = " [+]", readonly = " [RO]", unnamed = "[No Name]" } },
              },
              lualine_x = {
                { "diagnostics", sources = { "nvim_diagnostic" } },
                "filetype",
              },
              lualine_y = { "progress" },
              lualine_z = { "location" },
            },
          })
        end)
      end

      local function setup_bufferline()
        safe("bufferline", function()
          local fill = bgc("NormalFloat")
          local base = bgc("Normal")
          local dim = fg("Comment")
          local text = fg("Normal")
          local accent = fg("Keyword")
          local function item(f, b, extra)
            return vim.tbl_extend("force", { fg = f, bg = b }, extra or {})
          end
          local inactive = item(dim, fill)
          local visible = item(dim, fill)
          local selected = item(text, base, { bold = true, italic = false })
          require("bufferline").setup({
            options = {
              mode = "buffers",
              diagnostics = "nvim_lsp",
              separator_style = "thin",
              show_buffer_close_icons = true,
              show_close_icon = false,
              always_show_bufferline = false,
              close_command = function(n) require("mini.bufremove").delete(n, false) end,
              right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,
              offsets = {
                { filetype = "NvimTree", text = "Explorer", highlight = "Directory", separator = true },
              },
            },
            highlights = {
              fill = item(dim, fill),
              background = inactive,
              buffer_visible = visible,
              buffer_selected = selected,
              close_button = inactive,
              close_button_visible = visible,
              close_button_selected = item(accent, base),
              modified = item(fg("GitSignsChange"), fill),
              modified_visible = item(fg("GitSignsChange"), fill),
              modified_selected = item(fg("GitSignsChange"), base),
              separator = item(base, fill),
              separator_visible = item(base, fill),
              separator_selected = item(base, base),
              indicator_selected = item(accent, base),
              indicator_visible = item(fill, fill),
              diagnostic = inactive, diagnostic_visible = visible,
              diagnostic_selected = item(text, base),
              error = inactive, error_visible = visible,
              error_selected = item(fg("DiagnosticError"), base, { bold = true }),
              warning = inactive, warning_visible = visible,
              warning_selected = item(fg("DiagnosticWarn"), base, { bold = true }),
              info = inactive, info_visible = visible,
              info_selected = item(fg("DiagnosticInfo"), base, { bold = true }),
              hint = inactive, hint_visible = visible,
              hint_selected = item(fg("DiagnosticHint"), base, { bold = true }),
              tab = inactive,
              tab_selected = selected,
              tab_close = inactive,
              duplicate = inactive, duplicate_visible = visible,
              duplicate_selected = item(dim, base, { italic = true }),
              numbers = inactive, numbers_visible = visible, numbers_selected = selected,
              offset_separator = item(base, base),
            },
          })
        end)
      end

      -- Plugins are lazy: only refresh the ones already loaded.
      local function ui_refresh()
        apply_highlights()
        if package.loaded["lualine"] then setup_lualine() end
        if package.loaded["bufferline"] then setup_bufferline() end
      end

      -- ═══════════════════════════════════════════════════════════════════
      -- Core keybindings
      -- ═══════════════════════════════════════════════════════════════════
      map("n", "<leader>w", "<cmd>write<cr>", "Save file")
      map("n", "<leader>q", "<cmd>quit<cr>", "Quit")
      map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")
      map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down (wrapped lines)", { expr = true })
      map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up (wrapped lines)", { expr = true })
      map("x", "<", "<gv", "Indent left (keep selection)")
      map("x", ">", ">gv", "Indent right (keep selection)")
      map("x", "p", '"_dP', "Paste without clobbering register")

      map({ "n", "x" }, "<leader>y", '"+y', "Yank to system clipboard")
      map("n", "<leader>Y", '"+Y', "Yank line to system clipboard")

      map("n", "<C-h>", "<C-w>h", "Window left")
      map("n", "<C-j>", "<C-w>j", "Window down")
      map("n", "<C-k>", "<C-w>k", "Window up")
      map("n", "<C-l>", "<C-w>l", "Window right")
      map("n", "<C-Up>", "<cmd>resize +2<cr>", "Increase height")
      map("n", "<C-Down>", "<cmd>resize -2<cr>", "Decrease height")
      map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", "Decrease width")
      map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", "Increase width")
      map("n", "<leader>|", "<cmd>vsplit<cr>", "Split vertical")
      map("n", "<leader>-", "<cmd>split<cr>", "Split horizontal")
      map("n", "<leader>=", "<C-w>=", "Equalize windows")

      map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
      map("n", "<S-l>", "<cmd>bnext<cr>", "Next buffer")
      map("n", "[b", "<cmd>bprevious<cr>", "Previous buffer")
      map("n", "]b", "<cmd>bnext<cr>", "Next buffer")
      map("n", "<leader>bd", function() require("mini.bufremove").delete(0, false) end, "Delete buffer")
      map("n", "<leader>bo", "<cmd>%bdelete|edit #|bdelete #<cr>", "Delete other buffers")

      map("n", "<leader>ts", "<cmd>split | terminal<cr>", "Terminal (horizontal)")
      map("n", "<leader>tv", "<cmd>vsplit | terminal<cr>", "Terminal (vertical)")
      map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal mode")
      map("t", "<C-h>", "<C-\\><C-n><C-w>h", "Window left")
      map("t", "<C-j>", "<C-\\><C-n><C-w>j", "Window down")
      map("t", "<C-k>", "<C-\\><C-n><C-w>k", "Window up")
      map("t", "<C-l>", "<C-\\><C-n><C-w>l", "Window right")

      map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, "Toggle wrap")

      -- ═══════════════════════════════════════════════════════════════════
      -- Autocommands
      -- ═══════════════════════════════════════════════════════════════════
      au("TextYankPost", {
        callback = function() (vim.hl or vim.highlight).on_yank({ timeout = 150 }) end,
      })

      au("BufReadPost", {
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "gitcommit" then return end
          local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
          if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      au("BufWritePre", {
        callback = function(ev)
          if ev.match:match("^%w+://") then return end
          vim.fn.mkdir(vim.fn.fnamemodify(ev.match, ":p:h"), "p")
        end,
      })

      vim.g.trim_on_save = false
      local function trim_whitespace()
        local view = vim.fn.winsaveview()
        vim.cmd([[keeppatterns %s/\s\+$//e]])
        vim.fn.winrestview(view)
      end
      vim.api.nvim_create_user_command("TrimWhitespace", trim_whitespace, {})
      au("BufWritePre", { callback = function() if vim.g.trim_on_save then trim_whitespace() end end })

      au("FileType", {
        pattern = { "python", "rust", "c", "cpp" },
        callback = function()
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
        end,
      })
      au("FileType", {
        pattern = { "go", "make" },
        callback = function()
          vim.opt_local.expandtab = false
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
        end,
      })
      au("FileType", {
        pattern = { "help", "qf", "man", "notify", "checkhealth", "lspinfo", "startuptime", "query", "fugitive", "lazy" },
        callback = function(ev)
          vim.bo[ev.buf].buflisted = false
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, desc = "Close window" })
        end,
      })

      au({ "FocusGained", "TermClose", "TermLeave" }, {
        callback = function() if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end end,
      })
      au("VimResized", { callback = function() vim.cmd("tabdo wincmd =") end })
      au("TermOpen", {
        callback = function()
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
          vim.cmd("startinsert")
        end,
      })

      -- ═══════════════════════════════════════════════════════════════════
      -- Diagnostics + LSP attach keymaps (servers are started in the lspconfig spec)
      -- ═══════════════════════════════════════════════════════════════════
      local sev = vim.diagnostic.severity
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = { spacing = 2, prefix = "●", severity = { min = sev.WARN } },
        float = { border = "rounded", source = true, header = "" },
        signs = {
          text = { [sev.ERROR] = "✘", [sev.WARN] = "▲", [sev.INFO] = "●", [sev.HINT] = "◆" },
        },
      })

      local function diag_jump(count, severity)
        if vim.diagnostic.jump then
          vim.diagnostic.jump({ count = count, severity = severity, float = true })
        elseif count > 0 then
          vim.diagnostic.goto_next({ severity = severity })
        else
          vim.diagnostic.goto_prev({ severity = severity })
        end
      end
      map("n", "<leader>d", vim.diagnostic.open_float, "Show diagnostics")
      map("n", "]d", function() diag_jump(1) end, "Next diagnostic")
      map("n", "[d", function() diag_jump(-1) end, "Previous diagnostic")
      map("n", "]e", function() diag_jump(1, sev.ERROR) end, "Next error")
      map("n", "[e", function() diag_jump(-1, sev.ERROR) end, "Previous error")

      -- Neovim 0.11 gr* defaults would make plain `gr` wait; drop them
      for _, lhs in ipairs({ "grn", "grr", "gri", "grt" }) do pcall(vim.keymap.del, "n", lhs) end
      pcall(vim.keymap.del, { "n", "x" }, "gra")

      au("LspAttach", {
        callback = function(ev)
          local function b(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
          end
          b("n", "gd", vim.lsp.buf.definition, "Go to definition")
          b("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          b("n", "gr", vim.lsp.buf.references, "Go to references")
          b("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
          b("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
          b("n", "K", vim.lsp.buf.hover, "Hover documentation")
          b({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, "Signature help")
          b({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          b("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          b("n", "<leader>ss", "<cmd>Telescope lsp_document_symbols<cr>", "Document symbols")
          b("n", "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", "Workspace symbols")
          if vim.lsp.inlay_hint then
            b("n", "<leader>uh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
            end, "Toggle inlay hints")
          end
        end,
      })

      -- LSP servers: name (nvim-lspconfig) -> executable (from Nix) + settings
      local servers = {
        nil_ls = { exe = "nil", settings = { ["nil"] = { formatting = { command = { "nixfmt" } } } } },
        lua_ls = {
          exe = "lua-language-server",
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        pyright = { exe = "pyright-langserver" },
        ts_ls = { exe = "typescript-language-server" },
        rust_analyzer = { exe = "rust-analyzer" },
        clangd = { exe = "clangd" },
        html = { exe = "vscode-html-language-server" },
        cssls = { exe = "vscode-css-language-server" },
        jsonls = { exe = "vscode-json-language-server" },
        bashls = { exe = "bash-language-server" },
        yamlls = { exe = "yaml-language-server" },
        marksman = { exe = "marksman" },
      }

      vim.g.format_on_save = false
      vim.api.nvim_create_user_command("FormatOnSaveToggle", function()
        vim.g.format_on_save = not vim.g.format_on_save
        notify("Format on save: " .. tostring(vim.g.format_on_save), vim.log.levels.INFO)
      end, {})
      vim.api.nvim_create_user_command("TrimOnSaveToggle", function()
        vim.g.trim_on_save = not vim.g.trim_on_save
        notify("Trim on save: " .. tostring(vim.g.trim_on_save), vim.log.levels.INFO)
      end, {})
      map("n", "<leader>uf", "<cmd>FormatOnSaveToggle<cr>", "Toggle format on save")

      -- ═══════════════════════════════════════════════════════════════════
      -- lazy.nvim bootstrap
      -- ═══════════════════════════════════════════════════════════════════
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not uv.fs_stat(lazypath) then
        local out = vim.fn.system({
          "git", "clone", "--filter=blob:none", "--branch=stable",
          "https://github.com/folke/lazy.nvim.git", lazypath,
        })
        if vim.v.shell_error ~= 0 then
          vim.api.nvim_echo({
            { "Failed to clone lazy.nvim (network?):\n", "ErrorMsg" },
            { out, "WarningMsg" },
          }, true, {})
        end
      end
      vim.opt.rtp:prepend(lazypath)

      -- ═══════════════════════════════════════════════════════════════════
      -- Plugins
      -- ═══════════════════════════════════════════════════════════════════
      local plugins = {
        -- shared dependencies
        { "nvim-lua/plenary.nvim", lazy = true },
        { "MunifTanjim/nui.nvim", lazy = true },
        { "nvim-tree/nvim-web-devicons", lazy = true, opts = { default = true } },

        -- ── editor enhancements ──────────────────────────────────────────
        {
          "nvim-treesitter/nvim-treesitter",
          branch = "master",
          build = ":TSUpdate",
          event = { "BufReadPost", "BufNewFile" },
          cmd = { "TSUpdate", "TSInstall", "TSInstallInfo" },
          config = function()
            require("nvim-treesitter.configs").setup({
              ensure_installed = {
                "lua", "vim", "vimdoc", "query", "regex", "nix", "python", "javascript",
                "typescript", "tsx", "rust", "c", "cpp", "html", "css", "json", "bash",
                "yaml", "toml", "markdown", "markdown_inline",
              },
              auto_install = true,
              highlight = { enable = true },
              indent = { enable = true },
            })
          end,
        },
        { "windwp/nvim-autopairs", event = "InsertEnter", opts = { check_ts = true } },
        { "numToStr/Comment.nvim", event = { "BufReadPost", "BufNewFile" }, opts = {} },
        { "kylechui/nvim-surround", version = "*", event = "VeryLazy", opts = {} },
        {
          "lukas-reineke/indent-blankline.nvim",
          main = "ibl",
          event = { "BufReadPost", "BufNewFile" },
          opts = {
            indent = { char = "│", highlight = "IblIndent" },
            whitespace = { highlight = "IblWhitespace" },
            scope = { enabled = true, show_start = false, show_end = false, highlight = "IblScope" },
          },
        },
        {
          "folke/flash.nvim",
          event = "VeryLazy",
          opts = {},
          keys = {
            k("s", function() require("flash").jump() end, "Flash jump", { "n", "x", "o" }),
            k("S", function() require("flash").treesitter() end, "Flash treesitter", { "n", "o" }),
            k("r", function() require("flash").remote() end, "Flash remote", "o"),
            k("R", function() require("flash").treesitter_search() end, "Flash treesitter search", { "o", "x" }),
            k("<C-s>", function() require("flash").toggle() end, "Toggle flash search", "c"),
          },
        },
        {
          "folke/which-key.nvim",
          event = "VeryLazy",
          opts = {
            delay = 300,
            win = { border = "rounded" },
            spec = {
              { "<leader>b", group = "buffer" },
              { "<leader>c", group = "code" },
              { "<leader>g", group = "git" },
              { "<leader>gh", group = "hunks" },
              { "<leader>h", group = "harpoon" },
              { "<leader>s", group = "symbols" },
              { "<leader>t", group = "todo / terminal" },
              { "<leader>u", group = "toggles" },
              { "<leader>x", group = "trouble" },
            },
          },
        },
        {
          "folke/todo-comments.nvim",
          event = { "BufReadPost", "BufNewFile" },
          cmd = { "TodoTelescope", "TodoTrouble", "TodoQuickFix" },
          dependencies = { "nvim-lua/plenary.nvim" },
          opts = {},
          keys = {
            k("]t", function() require("todo-comments").jump_next() end, "Next TODO"),
            k("[t", function() require("todo-comments").jump_prev() end, "Previous TODO"),
            k("<leader>tt", function()
              require("telescope") -- loads telescope + todo-comments extension
              vim.cmd("TodoTelescope")
            end, "Find TODOs"),
          },
        },
        {
          "echasnovski/mini.nvim",
          version = false,
          event = "VeryLazy",
          config = function()
            require("mini.ai").setup({ n_lines = 300 })
            require("mini.bufremove").setup()
            require("mini.move").setup()
          end,
        },

        -- ── navigation ───────────────────────────────────────────────────
        {
          "stevearc/oil.nvim",
          lazy = false, -- must load early to take over directory buffers
          dependencies = { "nvim-tree/nvim-web-devicons" },
          opts = {
            default_file_explorer = true,
            columns = { "icon" },
            skip_confirm_for_simple_edits = true,
            view_options = { show_hidden = true },
            float = { border = "rounded" },
            keymaps = {
              ["q"] = "actions.close",
              ["<C-h>"] = false, -- keep window navigation
              ["<C-l>"] = false,
            },
          },
          keys = {
            k("<leader>e", "<cmd>Oil<cr>", "File explorer (Oil)"),
            k("-", "<cmd>Oil<cr>", "Open parent directory"),
          },
        },
        {
          "nvim-telescope/telescope.nvim",
          branch = "0.1.x",
          cmd = "Telescope",
          dependencies = {
            "nvim-lua/plenary.nvim",
            {
              "nvim-telescope/telescope-fzf-native.nvim",
              build = "make",
              enabled = vim.fn.executable("make") == 1,
            },
          },
          keys = {
            k("<leader>ff", "<cmd>Telescope find_files<cr>", "Find files"),
            k("<leader>fg", "<cmd>Telescope live_grep<cr>", "Live grep"),
            k("<leader>fb", "<cmd>Telescope buffers sort_mru=true ignore_current_buffer=true<cr>", "Find buffers"),
            k("<leader>fr", "<cmd>Telescope oldfiles<cr>", "Recent files"),
            k("<leader>fh", "<cmd>Telescope help_tags<cr>", "Help tags"),
            k("<leader>fd", "<cmd>Telescope diagnostics<cr>", "Diagnostics (Telescope)"),
            k("<leader>fG", "<cmd>Telescope git_files<cr>", "Git files"),
            k("<leader>fc", "<cmd>Telescope command_history<cr>", "Command history"),
            k("<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Search in buffer"),
          },
          config = function()
            local actions = require("telescope.actions")
            local telescope = require("telescope")
            telescope.setup({
              defaults = {
                prompt_prefix = "   ",
                selection_caret = "▎ ",
                sorting_strategy = "ascending",
                layout_config = { prompt_position = "top", width = 0.87, height = 0.80 },
                file_ignore_patterns = { "^%.git/", "node_modules/", "%.direnv/" },
                mappings = {
                  i = {
                    ["<C-j>"] = actions.move_selection_next,
                    ["<C-k>"] = actions.move_selection_previous,
                    ["<Esc>"] = actions.close,
                  },
                },
              },
              pickers = {
                find_files = { hidden = true, find_command = { "rg", "--files", "--hidden", "-g", "!.git" } },
              },
            })
            pcall(telescope.load_extension, "fzf")
            pcall(telescope.load_extension, "todo-comments")
          end,
        },
        {
          "ThePrimeagen/harpoon",
          branch = "harpoon2",
          dependencies = { "nvim-lua/plenary.nvim" },
          opts = { settings = { save_on_toggle = true } },
          config = function(_, opts) require("harpoon"):setup(opts) end,
          keys = {
            k("<leader>ha", function() require("harpoon"):list():add() end, "Harpoon add file"),
            k("<leader>hh", function()
              local h = require("harpoon")
              h.ui:toggle_quick_menu(h:list())
            end, "Harpoon menu"),
            k("<leader>hn", function() require("harpoon"):list():next() end, "Harpoon next"),
            k("<leader>hp", function() require("harpoon"):list():prev() end, "Harpoon previous"),
            k("<leader>1", function() require("harpoon"):list():select(1) end, "Harpoon file 1"),
            k("<leader>2", function() require("harpoon"):list():select(2) end, "Harpoon file 2"),
            k("<leader>3", function() require("harpoon"):list():select(3) end, "Harpoon file 3"),
            k("<leader>4", function() require("harpoon"):list():select(4) end, "Harpoon file 4"),
          },
        },
        {
          "folke/trouble.nvim",
          cmd = "Trouble",
          opts = {},
          keys = {
            k("<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics (Trouble)"),
            k("<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer diagnostics"),
            k("<leader>xs", "<cmd>Trouble symbols toggle<cr>", "Symbols (Trouble)"),
            k("<leader>xl", "<cmd>Trouble lsp toggle<cr>", "LSP references/definitions"),
            k("<leader>xq", "<cmd>Trouble qflist toggle<cr>", "Quickfix (Trouble)"),
          },
        },
        {
          "nvim-tree/nvim-tree.lua",
          cmd = { "NvimTreeToggle", "NvimTreeFindFile" },
          keys = { k("<leader>E", "<cmd>NvimTreeToggle<cr>", "File tree (nvim-tree)") },
          opts = {
            hijack_netrw = false,
            hijack_directories = { enable = false },
            view = { width = 34 },
            renderer = { group_empty = true },
            filters = { dotfiles = false },
          },
        },

        -- ── LSP, completion, snippets ────────────────────────────────────
        {
          "neovim/nvim-lspconfig",
          event = { "BufReadPre", "BufNewFile" },
          dependencies = { "hrsh7th/cmp-nvim-lsp" },
          config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            pcall(function()
              capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
            end)
            local native = vim.lsp.config ~= nil and vim.lsp.enable ~= nil
            for name, s in pairs(servers) do
              if vim.fn.executable(s.exe) == 1 then
                local conf = { capabilities = capabilities, settings = s.settings }
                if native then
                  vim.lsp.config(name, conf)
                  vim.lsp.enable(name)
                else
                  require("lspconfig")[name].setup(conf)
                end
              end
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
            "onsails/lspkind.nvim",
          },
          config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            local lspkind = require("lspkind")

            luasnip.config.setup({ history = true, updateevents = "TextChanged,TextChangedI" })

            cmp.setup({
              snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
              window = {
                completion = cmp.config.window.bordered({
                  winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
                }),
                documentation = cmp.config.window.bordered({
                  winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,Search:None",
                }),
              },
              mapping = cmp.mapping.preset.insert({
                ["<C-n>"] = cmp.mapping.select_next_item(),
                ["<C-p>"] = cmp.mapping.select_prev_item(),
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"] = cmp.mapping.abort(),
                ["<CR>"] = cmp.mapping.confirm({ select = false }),
                ["<Tab>"] = cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_next_item()
                  elseif luasnip.expand_or_locally_jumpable() then
                    luasnip.expand_or_jump()
                  else
                    fallback()
                  end
                end, { "i", "s" }),
                ["<S-Tab>"] = cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_prev_item()
                  elseif luasnip.locally_jumpable(-1) then
                    luasnip.jump(-1)
                  else
                    fallback()
                  end
                end, { "i", "s" }),
              }),
              sources = cmp.config.sources({
                { name = "nvim_lsp" },
                { name = "luasnip" },
              }, {
                { name = "buffer" },
                { name = "path" },
              }),
              formatting = {
                format = lspkind.cmp_format({
                  mode = "symbol_text",
                  maxwidth = 50,
                  ellipsis_char = "…",
                  menu = { nvim_lsp = "[LSP]", luasnip = "[Snip]", buffer = "[Buf]", path = "[Path]" },
                }),
              },
            })

            -- autopairs <-> cmp
            pcall(function()
              cmp.event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
            end)
          end,
        },

        -- ── formatting / linting ─────────────────────────────────────────
        {
          "stevearc/conform.nvim",
          event = "BufWritePre",
          cmd = "ConformInfo",
          keys = {
            k("<leader>f", function()
              require("conform").format({ async = true, lsp_format = "fallback" }, function(err)
                if err then notify("Format failed: " .. tostring(err), vim.log.levels.ERROR) end
              end)
            end, "Format buffer", { "n", "x" }),
          },
          opts = {
            formatters_by_ft = {
              nix = { "nixfmt" },
              lua = { "stylua" },
              python = { "ruff_organize_imports", "ruff_format" },
              javascript = { "prettier" },
              javascriptreact = { "prettier" },
              typescript = { "prettier" },
              typescriptreact = { "prettier" },
              rust = { "rustfmt" },
              c = { "clang-format" },
              cpp = { "clang-format" },
              html = { "prettier" },
              css = { "prettier" },
              json = { "prettier" },
              jsonc = { "prettier" },
              yaml = { "prettier" },
              markdown = { "prettier" },
              sh = { "shfmt" },
              bash = { "shfmt" },
            },
            format_on_save = function()
              if not vim.g.format_on_save then return nil end
              return { timeout_ms = 1500, lsp_format = "fallback" }
            end,
            notify_on_error = true,
            notify_no_formatters = true,
          },
        },
        {
          "mfussenegger/nvim-lint",
          event = { "BufReadPost", "BufWritePost", "BufNewFile" },
          config = function()
            local lint = require("lint")
            lint.linters_by_ft = {
              python = { "ruff" },
              javascript = { "eslint" },
              javascriptreact = { "eslint" },
              typescript = { "eslint" },
              typescriptreact = { "eslint" },
              sh = { "shellcheck" },
              bash = { "shellcheck" },
            }
            local function try_lint()
              for _, name in ipairs(lint.linters_by_ft[vim.bo.filetype] or {}) do
                local ok, cmd = pcall(function()
                  local l = lint.linters[name]
                  if type(l) == "function" then l = l() end
                  return type(l.cmd) == "function" and l.cmd() or l.cmd
                end)
                if ok and cmd and vim.fn.executable(cmd) == 1 then
                  pcall(lint.try_lint, name)
                end
              end
            end
            au({ "BufReadPost", "BufWritePost", "InsertLeave" }, { callback = try_lint })
            try_lint()
          end,
        },

        -- ── git ──────────────────────────────────────────────────────────
        {
          "lewis6991/gitsigns.nvim",
          event = { "BufReadPre", "BufNewFile" },
          opts = {
            signs = {
              add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" },
              topdelete = { text = "▔" }, changedelete = { text = "▎" }, untracked = { text = "▎" },
            },
            on_attach = function(buf)
              local gs = require("gitsigns")
              local function b(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
              end
              local function nav(dir)
                return function()
                  if vim.wo.diff then
                    return vim.cmd.normal({ dir == "next" and "]c" or "[c", bang = true })
                  end
                  if gs.nav_hunk then gs.nav_hunk(dir)
                  elseif dir == "next" then gs.next_hunk() else gs.prev_hunk() end
                end
              end
              b("n", "]h", nav("next"), "Next hunk")
              b("n", "[h", nav("prev"), "Previous hunk")
              b({ "n", "x" }, "<leader>ghs", "<cmd>Gitsigns stage_hunk<cr>", "Stage hunk")
              b({ "n", "x" }, "<leader>ghr", "<cmd>Gitsigns reset_hunk<cr>", "Reset hunk")
              b("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
              b("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
              b("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
            end,
          },
        },
        {
          "sindrets/diffview.nvim",
          cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
          dependencies = { "nvim-lua/plenary.nvim" },
          keys = {
            k("<leader>gd", "<cmd>DiffviewOpen<cr>", "Git diff (Diffview)"),
            k("<leader>gD", "<cmd>DiffviewClose<cr>", "Close Diffview"),
          },
        },
        {
          "tpope/vim-fugitive",
          cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite", "GBrowse" },
          keys = {
            k("<leader>gg", "<cmd>Git<cr>", "Git status (Fugitive)"),
            k("<leader>gB", "<cmd>Git blame<cr>", "Git blame"),
            k("<leader>gl", "<cmd>Git log --oneline<cr>", "Git log"),
          },
        },

        -- ── UI ───────────────────────────────────────────────────────────
        {
          "nvim-lualine/lualine.nvim",
          event = "VeryLazy",
          dependencies = { "nvim-tree/nvim-web-devicons" },
          config = function() setup_lualine() end,
        },
        {
          "akinsho/bufferline.nvim",
          version = "*",
          event = "VeryLazy",
          dependencies = { "nvim-tree/nvim-web-devicons" },
          config = function() setup_bufferline() end,
        },
        {
          "rcarriga/nvim-notify",
          lazy = true,
          opts = {
            stages = "fade",
            timeout = 3000,
            render = "wrapped-compact",
            max_width = 60,
            background_colour = "NormalFloat",
          },
          config = function(_, opts)
            local n = require("notify")
            n.setup(opts)
            vim.notify = n
          end,
        },
        {
          "folke/noice.nvim",
          event = "VeryLazy",
          dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
          opts = {
            lsp = {
              override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
                ["cmp.entry.get_documentation"] = true,
              },
            },
            presets = {
              bottom_search = true,
              command_palette = true,
              long_message_to_split = true,
              lsp_doc_border = true,
            },
            routes = {
              { -- reduce notification spam from trivial messages
                filter = {
                  event = "msg_show",
                  any = {
                    { find = "%d+L, %d+B" }, { find = "; after #%d+" }, { find = "; before #%d+" },
                    { find = "%d fewer lines" }, { find = "%d more lines" },
                  },
                },
                opts = { skip = true },
              },
            },
          },
        },
        {
          "stevearc/dressing.nvim",
          event = "VeryLazy",
          opts = {
            input = { border = "rounded", relative = "editor" },
            select = { backend = { "telescope", "builtin" }, builtin = { border = "rounded" } },
          },
        },
      }

      require("lazy").setup({
        spec = plugins,
        defaults = { lazy = true },
        lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
        install = { missing = true },
        checker = { enabled = false },
        change_detection = { notify = false },
        ui = { border = "rounded" },
        performance = {
          rtp = {
            disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
          },
        },
      })

      -- ═══════════════════════════════════════════════════════════════════
      -- Kuro theme activation (file is generated by kurogen)
      -- ═══════════════════════════════════════════════════════════════════
      -- Never override the background: Kuro's active palette (light/dark) decides.
      local function activate_kuro()
        local ok = pcall(vim.cmd.colorscheme, "kuro")
        if not ok then
          notify("Kuro not found at " .. kuro_file .. " — run kurogen (falling back to default).")
        end
        return ok
      end

      activate_kuro()
      ui_refresh()

      au("ColorScheme", { pattern = "kuro", callback = ui_refresh })

      vim.api.nvim_create_user_command("KuroReload", function() activate_kuro() end, {})
      map("n", "<leader>uk", "<cmd>KuroReload<cr>", "Reload Kuro theme")

      -- Pick up palette regeneration automatically when focus returns.
      local last_mtime
      do
        local st = uv.fs_stat(kuro_file)
        last_mtime = st and st.mtime.sec
      end
      au("FocusGained", {
        callback = function()
          local st = uv.fs_stat(kuro_file)
          local m = st and st.mtime.sec
          if m and m ~= last_mtime then
            last_mtime = m
            activate_kuro()
          end
        end,
      })
    '';
  };
}
