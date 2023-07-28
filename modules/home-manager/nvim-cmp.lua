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

  -- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#highlight-symbol-under-cursor
  if client.server_capabilities.documentHighlightProvider then
    vim.cmd [[
          hi! LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
          hi! LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
          hi! LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
        ]]
    vim.api.nvim_create_augroup('lsp_document_highlight', {
      clear = false
    })
    vim.api.nvim_clear_autocmds({
      buffer = bufnr,
      group = 'lsp_document_highlight',
    })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = 'lsp_document_highlight',
      buffer = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = 'lsp_document_highlight',
      buffer = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end
end

-- Add additional capabilities supported by nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local lspconfig = require('lspconfig')

-- Enable some language servers with the additional completion capabilities offered by nvim-cmp
local servers = { 'clangd', 'rust_analyzer', 'pyright', 'tsserver', 'nil_ls', 'gopls', 'texlab', 'marksman', 'ocamllsp' }
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

lspconfig['lua_ls'].setup {
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
}

lspconfig['ltex'].setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = { "ltex-ls" },
  filetypes = { "markdown", "tex", "text" },
  flags = { debounce_text_changes = 300 },
  settings = {
    ltex = {
      language = "en-GB",
      dictionary = {
        ["en-GB"] = {
          "MultiPaxos", "LogPaxos", "Paxos", "FastPaxos", "FlexiblePaxos", "EPaxos", "automerge",
          "multipaxos", "paxos",
          "RDMA", "SMR", "RPC",
          "OCons"
        },
      },
      disabledRules = {
        ["en-GB"] = {
          "OXFORD_SPELLING_Z_NOT_S",
        },
      },
    },
  },
}

-- nvim-cmp setup
local cmp = require 'cmp'
cmp.setup {
  mapping = cmp.mapping.preset.insert({
    ['<C-u>'] = cmp.mapping.scroll_docs( -4),
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
