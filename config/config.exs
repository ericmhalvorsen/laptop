import Config

if config_env() == :test do
  config :vault, env: :test
end
