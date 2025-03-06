{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraPackages = with pkgs; [
      black
      pyright
      marksman
      alejandra
      nil
      sumneko-lua-language-server
      ltex-ls
      tinymist
    ];
    extraLuaConfig = builtins.readFile ./init.lua;
    plugins = with pkgs.vimPlugins; [
      {
        plugin = gruvbox-nvim;
        type = "lua";
        config = ''
            require("gruvbox").setup{}
            vim.o.background = "dark"
            vim.cmd([[colorscheme gruvbox]])
        '';
      }

      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = ''
          -- setup done in cmp below
        '';
      }

      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-path
      cmp-buffer
      {
        plugin = nvim-cmp;
        type = "lua";
        config = builtins.readFile ./nvim-cmp.lua;
      }

      {
        plugin = fidget-nvim;
        type = "lua";
        config = ''
          require("fidget").setup{
            progress = {
              suppress_on_insert=true,
            }
          }
        '';
      }

      vim-fugitive

      vim-surround

      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
            local function lsp_client_names()
            local client_names = {}
          for _, client in ipairs(vim.lsp.get_active_clients()) do
            table.insert(client_names, client.name)
              end
              return table.concat(client_names, ",")
              end

              require('lualine').setup {
                options = {
                  section_separators = { left = ' ', right = ' ' },
                  component_separators = { left = '|', right = '|' },
                  theme = 'auto',
                },
                        sections = {
                          lualine_a = { 'mode' },
                          lualine_b = { 'branch', 'diff', 'diagnostics' },
                          lualine_c = { { 'filename', path = 1 } },
                          lualine_x = { 'filetype', 'encoding', 'fileformat' },
                          lualine_y = { lsp_client_names },
                          lualine_z = { 'progress', 'location' }
                        },
                        extensions = { 'quickfix', 'fugitive' },
              }
        '';
      }

      #      telescope-fzf-native-nvim
      #      {
      #        plugin = telescope-nvim;
      #        type = "lua";
      #        config = ''
      #          -- telescope
      #          local builtin = require('telescope.builtin')
      #          vim.keymap.set('n', '<leader><leader>f', builtin.find_files, { desc = "Find files" })
      #          vim.keymap.set('n', '<leader><leader>l', builtin.live_grep, { desc = "Find lines" })
      #          vim.keymap.set('n', '<leader><leader>b', builtin.buffers, { desc = "Buffers" })
      #          vim.keymap.set('n', '<leader><leader>/', builtin.current_buffer_fuzzy_find, { desc = "Buffer lines" })
      #
      #          local actions = require("telescope.actions")
      #          require("telescope").setup {
      #            defaults = {
      #              mappings = {
      #                i = {
      #                  ["<esc>"] = actions.close
      #                },
      #              },
      #            }
      #          }
      #
      #        -- use fzf filtering
      #          require("telescope").load_extension("fzf")
      #          '';
      #      }

      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = ''
          require'nvim-treesitter.configs'.setup {
            highlight = {
              enable = true,
            },
          }
          vim.opt.foldmethod = "expr"
          vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.opt.foldenable = false
      '';
      }
      
      {
        plugin = nvim-treesitter-context;
        type = "lua";
        config = ''
          require("treesitter-context").setup{}
        '';
      }

      nvim-web-devicons
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
            require("nvim-tree").setup({
                view = {
                preserve_window_proportions = true,
                },
                })
          local api = require("nvim-tree.api")
            vim.keymap.set('n', '<leader>p', api.tree.toggle, { desc = "Find files" })
            vim.keymap.set('n', '<leader>P', function() api.tree.toggle{find_file = true} end, { desc = "Find files" })
        '';
      }

      typst-vim
    ];
  };
}
