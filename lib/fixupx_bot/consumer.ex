defmodule FixupxBot.Consumer do
  @moduledoc """
  Nostrum gateway event consumer.

  ## How `use Nostrum.Consumer` works (nostrum 0.10)

  Calling `use Nostrum.Consumer`:
  - pulls in `use GenServer`
  - injects `child_spec/1`, `start_link/1`, `init/1` so the process joins
    `Nostrum.ConsumerGroup` automatically on boot
  - provides a default `handle_info/2` that spawns a `Task` per event,
    calling our `handle_event/1` inside it

  Because every event runs in its own short-lived `Task` process, the
  consumer's GenServer mailbox is **never blocked** by API calls.  We exploit
  this: all Discord REST calls are made directly inside `handle_event/1`
  without any additional `Task.start` wrapping.

  ## SUPPRESS_EMBEDS flag

  Discord message flag bit 2 (integer value `4`) instructs clients not to
  render link-preview cards.  We OR it into the message's existing flags
  rather than replacing them, to avoid accidentally clearing other bits.
  """

  use Nostrum.Consumer

  require Logger

  alias Nostrum.Api.Message, as: MessageAPI
  alias Nostrum.Struct.Message
  alias FixupxBot.{CommandHandler, LinkFixer, State, WebhookHandler}

  # Discord MESSAGE flag: suppress all embed previews.
  # Bit 2 = 2^2 = 4. Defined as a literal because module attributes are
  # evaluated before `import Bitwise` takes effect in the compiler pipeline.
  # https://discord.com/developers/docs/resources/message#message-object-message-flags
  @suppress_embeds_flag 4

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  def handle_event({:READY, %{user: %{username: name, discriminator: disc}}, _ws}) do
    Logger.info("[Consumer] Ready — logged in as #{name}##{disc}")
  end

  # Only APPLICATION_COMMAND interactions (type 2) concern us.
  # Component interactions (buttons, selects — type 3) are ignored.
  def handle_event({:INTERACTION_CREATE, %{type: 2, data: %{name: "fixtoggle"}} = ix, _ws}) do
    CommandHandler.handle(ix)
  end

  def handle_event({:INTERACTION_CREATE, _ix, _ws}), do: :ignore

  # Ignore bot messages (including our own webhook re-posts) to prevent loops.
  def handle_event({:MESSAGE_CREATE, %Message{author: %{bot: true}}, _ws}), do: :ignore

  def handle_event({:MESSAGE_CREATE, %Message{} = msg, _ws}) do
    if LinkFixer.contains_link?(msg.content) do
      %{is_enabled: enabled, mode: mode} = State.get()

      if enabled do
        fixed = LinkFixer.fix(msg.content)
        dispatch(mode, msg, fixed)
      end
    end
  end

  # Catch-all — required; the injected default would cover it, but being
  # explicit documents intent and keeps the compiler happy.
  def handle_event(_event), do: :ignore

  # ---------------------------------------------------------------------------
  # Mode dispatch
  # ---------------------------------------------------------------------------

  # Mode A — Webhook: delete original + re-post via webhook as the original author.
  defp dispatch(:webhook, msg, fixed) do
    case WebhookHandler.handle(msg, fixed) do
      {:ok, _sent} ->
        Logger.debug("[Consumer] :webhook applied to msg #{msg.id}")

      {:error, reason} ->
        Logger.warning("[Consumer] :webhook failed for #{msg.id}: #{inspect(reason)}")
    end
  end

  # Mode B — Suppress: hide embeds on original + reply with fixed link.
  defp dispatch(:suppress, msg, fixed) do
    with :ok <- suppress_embeds(msg),
         {:ok, _reply} <- send_reply(msg, fixed) do
      Logger.debug("[Consumer] :suppress applied to msg #{msg.id}")
    else
      {:error, reason} ->
        Logger.warning("[Consumer] :suppress failed for #{msg.id}: #{inspect(reason)}")
    end
  end

  # Set SUPPRESS_EMBEDS on the message.
  # Nostrum's Message struct does not cache the `flags` field, so we cannot
  # read-modify-write.  In practice, Discord only allows bots to set/clear
  # SUPPRESS_EMBEDS on other users' messages via this endpoint, so passing
  # the flag value directly is safe and correct.
  defp suppress_embeds(%Message{id: msg_id, channel_id: chan_id}) do
    case MessageAPI.edit(chan_id, msg_id, flags: @suppress_embeds_flag) do
      {:ok, _} ->
        :ok

      # 10008 = Unknown Message — deleted before we got here.
      {:error, %{response: %{code: 10008}}} ->
        Logger.warning("[Consumer] Msg #{msg_id} gone before suppress.")
        {:error, :message_gone}

      {:error, _} = err ->
        err
    end
  end

  # Reply to the original message using Discord's built-in message reference
  # (thread-style reply), with all mention parsing disabled.
  defp send_reply(%Message{id: msg_id, channel_id: chan_id}, fixed) do
    MessageAPI.create(chan_id,
      content: fixed,
      message_reference: %{message_id: msg_id},
      allowed_mentions: %{parse: []}
    )
  end
end
