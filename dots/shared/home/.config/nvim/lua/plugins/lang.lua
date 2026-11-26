return {
  -- QML / Quickshell
  { "peterhoeg/vim-qml", ft = { "qml", "qbs" } },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        qmlls = {},
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "qmljs", "qmldir" })
    end,
  },
}
