defmodule FixupxBot.WebhookHandler do
  @moduledoc """
  Executes the `:webhook` mode action for a message containing Twitter/X links.

  ## Flow

  1. List the channel's webhooks and reuse one named `"FixupX Bot"` if it
     already exists; otherwise create it.  Reuse avoids the per-channel limit
     of 10 webhooks and saves an API round-trip on subsequent messages.
  2. Delete the original message so Discord's native embed disappears.
     If the message is already gone (error 10008) we log and continue rather
     than aborting — the webhook post still makes sense.
  3. Execute the webhook, overriding its display `username` and `avatar_url`
     with the original author's identity so the replacement looks seamless.

  All Discord API calls are wrapped in `with` pipelines so failures surface as
  `{:error, reason}` tuples rather than exceptions.  The caller (`Consumer`)
  handles logging at the appropriate level.
  """

  require Logger

  alias Nostrum.Api.Channel, as: ChannelAPI
  alias Nostrum.Api.Message, as: MessageAPI
  alias Nostrum.Api.Webhook, as: WebhookAPI
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  @webhook_name "FixupX Bot"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec handle(Message.t(), String.t()) ::
          {:ok, Message.t()} | {:error, term()}
  def handle(%Message{} = message, fixed_content) do
    with {:ok, webhook} <- get_or_create_webhook(message.channel_id),
         :ok <- delete_original(message),
         {:ok, sent} <- execute_webhook(webhook, message, fixed_content) do
      {:ok, sent}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_or_create_webhook(channel_id) do
    with {:ok, webhooks} <- ChannelAPI.webhooks(channel_id) do
      case Enum.find(webhooks, &(&1.name == @webhook_name)) do
        nil ->
          Logger.debug("[WebhookHandler] Creating webhook in channel #{channel_id}")
          WebhookAPI.create(channel_id, %{name: @webhook_name})

        existing ->
          Logger.debug("[WebhookHandler] Reusing webhook #{existing.id}")
          {:ok, existing}
      end
    end
  end

  # 10008 = Unknown Message — already deleted; treat as soft success so the
  # webhook post still goes through.
  defp delete_original(%Message{id: msg_id, channel_id: chan_id}) do
    case MessageAPI.delete(chan_id, msg_id) do
      {:ok} ->
        :ok

      {:error, %{response: %{code: 10008}}} ->
        Logger.warning("[WebhookHandler] Msg #{msg_id} already gone; continuing.")
        :ok

      {:error, _} = err ->
        err
    end
  end

  # `wait: true` tells Discord to return the created Message struct so the
  # caller can log or inspect it.
  defp execute_webhook(webhook, %Message{author: author} = _message, fixed_content) do
    WebhookAPI.execute(
      webhook.id,
      webhook.token,
      %{
        content: fixed_content,
        username: author.username,
        avatar_url: avatar_url(author),
        # Never ping anyone in the replacement message.
        # :none tells nostrum to set allowed_mentions to {parse: []}
        allowed_mentions: :none
      },
      # wait = true → Discord returns the created Message object
      true
    )
  end

  # Build the CDN avatar URL for a user.  Handles animated avatars (a_ prefix),
  # users with no avatar set, and the new pomelo accounts (nil discriminator).
  @spec avatar_url(User.t()) :: String.t()
  defp avatar_url(%User{avatar: nil, discriminator: disc}) do
    # Modulo 5 maps the legacy 4-digit discriminator to one of 5 default images.
    # Pomelo usernames have discriminator "0" — they map to index 0.
    index = (disc || "0") |> String.to_integer() |> rem(5)
    "https://cdn.discordapp.com/embed/avatars/#{index}.png"
  end

  defp avatar_url(%User{id: id, avatar: hash}) do
    ext = if String.starts_with?(hash, "a_"), do: "gif", else: "png"
    "https://cdn.discordapp.com/avatars/#{id}/#{hash}.#{ext}?size=256"
  end
end
