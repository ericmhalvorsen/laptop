return {
  "milanglacier/minuet-ai.nvim",
  config = function()
    require("minuet").setup {
      provider = "openai_fim_compatible",
      n_completions = 1, -- recommend for local model for resource saving
      context_window = 256,
      provider_options = {
        openai_fim_compatible = {
          api_key = "TERM",
          name = "Ollama",
          end_point = "http://localhost:11434/v1/completions",
          model = "qwen2.5-coder:7b",
          optional = {
            max_tokens = 200,
            top_p = 0.9,
          },
        },
        claude = {
          max_tokens = 256,
          model = "claude-haiku-4.5",
          -- system = "see [Prompt] section for the default value",
          -- few_shots = "see [Prompt] section for the default value",
          -- chat_input = "See [Prompt Section for default value]",
          api_key = function()
            return io.popen("~/.claude/anthropic_key.sh"):read "*all"
          end,
          end_point = "https://api.anthropic.com/v1/messages",
          optional = {
            -- pass any additional parameters you want to send to claude request,
            -- e.g.
            -- stop_sequences = nil,
          },
        },
      },
    }
  end,
  dependencies = {
    { "nvim-lua/plenary.nvim" },
    { "hrsh7th/nvim-cmp" },
    { "Saghen/blink.cmp" },
  },
}
