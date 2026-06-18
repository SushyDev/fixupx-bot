defmodule FixupxBot.CommandHandler do
  @moduledoc """
  Handles the `/fixtoggle` slash command interaction.

  ## Command signature

      /fixtoggle action:enable|disable|toggle|mode  [mode:webhook|suppress]

  ### Options

  | Option   | Type           | Required | Description                          |
  |----------|----------------|----------|--------------------------------------|
  | `action` | string (choice)| yes      | `enable` / `disable` / `toggle` / `mode` |
  | `mode`   | string (choice)| no       | `webhook` or `suppress` (only with `action:mode`) |

  ## Permission enforcement

  Discord sends `member.permissions` as a decimal-string bitfield.  We parse
  it and verify that at least one of these bits is set:

  - `ADMINISTRATOR`  (0x8)   — implies all other permissions
  - `MANAGE_GUILD`   (0x20)  — can manage server settings

  We check this in code rather than relying solely on Discord's command-level
  permission overrides, so a misconfigured server cannot bypass the restriction.

  ## Response

  All replies use interaction callback type 4 (`CHANNEL_MESSAGE_WITH_SOURCE`)
  with the EPHEMERAL flag (bit 6, value 64) so only the invoking user sees the
  confirmation message.  Discord requires a response within 3 seconds — because
  `State` calls are synchronous GenServer calls that return in microseconds,
  this budget is never at risk.
  """

  require Logger

  import Bitwise, only: [band: 2]

  alias Nostrum.Api.Interaction, as: InteractionAPI
  alias Nostrum.Struct.Interaction
  alias FixupxBot.State

  # https://discord.com/developers/docs/topics/permissions#permissions-bitwise-permission-flags
  @perm_administrator 0x8
  @perm_manage_guild  0x20

  # Interaction callback type: respond immediately with a channel message.
  @callback_channel_message 4

  # Message flag: only visible to the invoking user.
  # Bit 6 = 2^6 = 64. Literal for the same reason as above.
  @flag_ephemeral 64

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec handle(Interaction.t()) :: :ok
  def handle(%Interaction{} = interaction) do
    case check_permissions(interaction) do
      :ok -> apply_action(interaction)
      :forbidden -> reply(interaction, "You need **Administrator** or **Manage Server** permission.")
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Permission check
  # ---------------------------------------------------------------------------

  # Discord sends permissions as a decimal string in the member struct.
  defp check_permissions(%{member: %{permissions: perms_str}} = interaction) when is_binary(perms_str) do
    perms = String.to_integer(perms_str)
    
    Logger.debug("[CommandHandler] User #{interaction.user.id}: perms_str=#{perms_str}, perms=#{perms}, admin_bit=#{band(perms, @perm_administrator)}, manage_bit=#{band(perms, @perm_manage_guild)}")

    if band(perms, @perm_administrator) != 0 or band(perms, @perm_manage_guild) != 0 do
      :ok
    else
      :forbidden
    end
  end

  # Member struct present but no permissions field — allow as fallback
  # (Discord sometimes omits this for cached members).
  defp check_permissions(%{member: %{}} = interaction) do
    Logger.warning("[CommandHandler] User #{interaction.user.id}: member struct present but no permissions field — allowing by default")
    :ok
  end

  # No member struct present (DM or malformed event) — deny by default.
  defp check_permissions(%{user: %{id: user_id}} = _interaction) do
    Logger.warning("[CommandHandler] User #{user_id}: no member struct in interaction — denying")
    :forbidden
  end

  defp check_permissions(_), do: :forbidden

  # ---------------------------------------------------------------------------
  # Action dispatch
  # ---------------------------------------------------------------------------

  defp apply_action(%{data: %{options: options}} = interaction) do
    opts = parse_options(options)

    case opts["action"] do
      "enable" ->
        State.update(%{is_enabled: true})
        reply(interaction, "FixupX Bot **enabled**.")

      "disable" ->
        State.update(%{is_enabled: false})
        reply(interaction, "FixupX Bot **disabled**.")

      "toggle" ->
        label = if State.toggle_enabled(), do: "enabled", else: "disabled"
        reply(interaction, "FixupX Bot is now **#{label}**.")

      "mode" ->
        case opts["mode"] do
          nil ->
            reply(interaction, "Provide the `mode` option when using `action: mode`.")

          raw ->
            # String.to_existing_atom is safe here: `:webhook` and `:suppress`
            # are guaranteed to exist because they appear as literals in State.
            State.set_mode(String.to_existing_atom(raw))
            reply(interaction, "Mode set to **#{raw}**.")
        end

      other ->
        Logger.warning("[CommandHandler] Unexpected action value: #{inspect(other)}")
        reply(interaction, "Unknown action `#{other}`.")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Convert the options list into a plain string→value map for easy access.
  defp parse_options(nil), do: %{}

  defp parse_options(options) when is_list(options) do
    Map.new(options, fn %{name: name, value: value} -> {name, value} end)
  end

  defp reply(%Interaction{} = interaction, content) do
    response = %{
      type: @callback_channel_message,
      data: %{content: content, flags: @flag_ephemeral}
    }

    case InteractionAPI.create_response(interaction, response) do
      {:ok} ->
        Logger.info("[CommandHandler] Response sent successfully")
        :ok

      {:error, reason} ->
        Logger.error("[CommandHandler] Response failed: #{inspect(reason)}")
    end
  end
end
