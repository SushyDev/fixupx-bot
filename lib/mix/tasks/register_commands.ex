defmodule Mix.Tasks.FixupxBot.RegisterCommands do
  @shortdoc "Register /fixtoggle with Discord (global or guild-scoped)"

  @moduledoc """
  Registers (or bulk-overwrites) the `/fixtoggle` slash command via Discord's
  Application Command API.

  ## Usage

      # Register globally (propagates to all servers within ~1 hour):
      DISCORD_TOKEN="MTM..." mix fixupx_bot.register_commands

      # Register to one guild immediately (ideal during development):
      DISCORD_TOKEN="MTM..." mix fixupx_bot.register_commands --guild GUILD_ID

  `DISCORD_TOKEN` must be set in the environment (without the "Bot " prefix).

  ## Idempotency

  Discord's bulk-overwrite endpoint atomically replaces all existing commands
  for the given scope, so running this task multiple times is safe.
  """

  use Mix.Task

  alias Nostrum.Api.ApplicationCommand

  # Full command schema sent to Discord.
  # Option type 3 = STRING.
  @command %{
    name: "fixtoggle",
    description: "Control the FixupX link-fixer bot",
    # Prevent the command from appearing in DMs — it's guild-only.
    dm_permission: false,
    options: [
      %{
        type: 3,
        name: "action",
        description: "What to do",
        required: true,
        choices: [
          %{name: "Enable bot",            value: "enable"},
          %{name: "Disable bot",           value: "disable"},
          %{name: "Toggle bot on/off",     value: "toggle"},
          %{name: "Switch operating mode", value: "mode"}
        ]
      },
      %{
        type: 3,
        name: "mode",
        description: "Operating mode — only required when action = 'Switch operating mode'",
        required: false,
        choices: [
          %{name: "Webhook  (delete + re-post as original user)", value: "webhook"},
          %{name: "Suppress (hide embeds + post reply link)",     value: "suppress"}
        ]
      }
    ]
  }

  @impl Mix.Task
  def run(args) do
    # Manually load runtime config BEFORE starting nostrum.
    # This is necessary because Mix doesn't automatically evaluate runtime.exs
    # for tasks unless the app is in the deps/supervision tree.
    token = System.get_env("DISCORD_TOKEN")

    unless token do
      Mix.raise("""
      DISCORD_TOKEN is not set.

      Set it before running this task:
          DISCORD_TOKEN="MTMyMzM3Njc2MjA3OTU0MzI5Ng.GlqT-Q.34NeMr5..." mix fixupx_bot.register_commands
      """)
    end

    # Apply the token to the :nostrum config before starting the application.
    Application.put_env(:nostrum, :token, token)

    # Now start nostrum with the configured token.
    case Application.ensure_all_started(:nostrum) do
      {:ok, _} ->
        :ok

      {:error, {failed_app, reason}} ->
        Mix.raise("Could not start #{failed_app}: #{inspect(reason)}")
    end

    guild_id = parse_guild_id(args)

    # Extract the application ID (bot's user ID) from the token.
    # Token format: <base64(user_id)>.<timestamp>.<signature>
    application_id =
      token
      |> String.split(".")
      |> List.first()
      |> Base.decode64!(padding: false)
      |> String.to_integer()

    {label, result} =
      if guild_id do
        Mix.shell().info("Registering commands in guild #{guild_id}...")
        {
          "guild #{guild_id}",
          # Call the 3-arg version to avoid the broken default parameter.
          ApplicationCommand.bulk_overwrite_guild_commands(application_id, guild_id, [@command])
        }
      else
        Mix.shell().info("Registering commands globally (may take ~1 hour to propagate)...")
        {
          "global scope",
          # For global commands, we need the app ID. There's also a 1-arg version but
          # it has the same broken default parameter. Use the 2-arg version instead.
          ApplicationCommand.bulk_overwrite_global_commands(application_id, [@command])
        }
      end

    case result do
      {:ok, commands} ->
        Mix.shell().info("Registered #{length(commands)} command(s) in #{label}:")

        for %{id: id, name: name} <- commands do
          Mix.shell().info("  /#{name}  (id: #{id})")
        end

      {:error, reason} ->
        Mix.raise("Command registration failed: #{inspect(reason)}")
    end
  end

  # Accept both `--guild 123` and `--guild=123`.
  defp parse_guild_id(["--guild", id | _]), do: String.to_integer(id)
  defp parse_guild_id(["--guild=" <> id | _]), do: String.to_integer(id)
  defp parse_guild_id([_ | rest]), do: parse_guild_id(rest)
  defp parse_guild_id([]), do: nil
end
