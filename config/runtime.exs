import Config

# ---------------------------------------------------------------------------
# Runtime configuration — evaluated at startup, never baked into beam files.
# ---------------------------------------------------------------------------
# Set DISCORD_TOKEN in your shell, a .env file (loaded by direnv / dotenv),
# a systemd EnvironmentFile, or a secrets manager.  Never hardcode the value.

discord_token =
  System.get_env("DISCORD_TOKEN") ||
    raise """

    ┌─────────────────────────────────────────────────────────┐
    │  DISCORD_TOKEN environment variable is not set.         │
    │                                                         │
    │  Export it before starting the bot:                     │
    │    export DISCORD_TOKEN="Bot your_token_here"           │
    │    mix run --no-halt                                     │
    └─────────────────────────────────────────────────────────┘
    """

config :nostrum, token: discord_token
