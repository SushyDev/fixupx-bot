defmodule FixupxBot do
  @moduledoc """
  FixupX Bot — rewrites Twitter/X links to `fixupx.com` in Discord messages.

  Built on **Elixir 1.19 / OTP 28** with **nostrum 0.10**.

  ## Module map

  | Module                       | Role                                         |
  |------------------------------|----------------------------------------------|
  | `FixupxBot.Application`      | OTP Application callback + Supervisor root   |
  | `FixupxBot.State`            | GenServer: runtime on/off + mode config      |
  | `FixupxBot.Consumer`         | Nostrum event consumer (MESSAGE_CREATE, etc) |
  | `FixupxBot.LinkFixer`        | Pure: detect + rewrite Twitter/X URLs        |
  | `FixupxBot.WebhookHandler`   | Mode `:webhook` — delete + webhook re-post   |
  | `FixupxBot.CommandHandler`   | `/fixtoggle` slash command handler           |

  ## Quick start

      export DISCORD_TOKEN="Bot your_token_here"

      # Register commands (once per bot / guild):
      mix fixupx_bot.register_commands --guild YOUR_GUILD_ID

      # Run:
      mix run --no-halt
  """
end
