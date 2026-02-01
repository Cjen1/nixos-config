-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = function(desc)
    return { noremap = true, silent = true, buffer = bufnr, desc = desc }
  end
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts("Hover"))
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts("Goto declaration"))
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts("Goto definition"))
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts("Goto implementation"))
  vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, bufopts("Goto type definition"))
  vim.keymap.set('n', 'gn', vim.diagnostic.goto_next, bufopts("Goto next issue"))
  vim.keymap.set('n', 'gN', vim.diagnostic.goto_prev, bufopts("Goto prev issue"))
  vim.keymap.set('n', 'gf', vim.lsp.buf.references, bufopts("Show references"))
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts("Code action"))
  vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, bufopts("Rename"))
  vim.keymap.set('n', '<leader>cf', function() vim.lsp.buf.format { async = true } end, bufopts("Format"))
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, bufopts("Get error"))
end

-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.tbl_deep_extend("force",
  vim.lsp.protocol.make_client_capabilities(),
  require('cmp_nvim_lsp').default_capabilities()
)
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

-- Enable language servers with the new vim.lsp.config API
local servers = { 'clangd', 'rust_analyzer', 'pyright', 'ts_ls', 'nil_ls', 'gopls', 'marksman', 'ocamllsp', 'tinymist' }
for _, lsp in ipairs(servers) do
  vim.lsp.config(lsp, {
    on_attach = on_attach,
    capabilities = capabilities,
  })
  vim.lsp.enable(lsp)
end

-- lua_ls with specific settings
vim.lsp.config('lua_ls', {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
})
vim.lsp.enable('lua_ls')


-- texlab with specific settings
vim.lsp.config('texlab', {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    texlab = {
      build = {
        onSave = true,
        args = {
          "-xelatex",
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
          "%f"
        },
        executable = "latexmk",
        forwardSearchAfter = true
      },
      chktex = {onOpenAndSave = true},
      forwardSearch = {
        args = {
          "--synctex-forward",
          "%l:1:%f",
          "%p"
        },
        executable = "okular"
      }
    }
  }
})
vim.lsp.enable('texlab')

-- nvim-cmp setup
local cmp = require 'cmp'
cmp.setup {
  mapping = cmp.mapping.preset.insert({
    ['<C-u>'] = cmp.mapping.scroll_docs(-4),
    ['<C-d>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<Tab>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
  }),
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'nvim_lsp_signature_help' },
    { name = 'path' },
    { name = 'buffer' },
  },
}
