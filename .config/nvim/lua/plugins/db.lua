return {
  {
    "kndndrj/nvim-dbee",
    dependencies = { "MunifTanjim/nui.nvim" },
    build = function()
      require("dbee").install()
    end,
    config = function()
      require("dbee").setup({
        sources = {
          require("dbee.sources").MemorySource:new({
            {
              name = "A1Hive Local",
              type = "postgres",
              url = "postgres://a1hive:a1hive@localhost:5432/a1hive?sslmode=disable",
            },
            {
              name = "TimeTrace",
              type = "sqlite",
              url = "/home/user/.timetrace/timetrace.db",
            },
          }),
        },
      })
    end,
    keys = {
      {
        "<leader>od",
        function()
          require("dbee").open()
        end,
        desc = "Open DBee",
      },
    },
  },
}
