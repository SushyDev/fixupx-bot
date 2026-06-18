import Config

# ---------------------------------------------------------------------------
# Nostrum — gateway intents
# ---------------------------------------------------------------------------
# Intents are declared as atoms; nostrum converts them to the Discord bitmask
# internally.  Only request what the bot actually uses to keep the event
# volume low.
#
#   :guilds          — guild/channel cache; required for member lookups
#   :guild_messages  — MESSAGE_CREATE events in guild channels
#   :message_content — message body text (privileged intent)
#                      Must ALSO be enabled in the Discord Developer Portal:
#                      Bot → Privileged Gateway Intents → Message Content Intent
#
# Reference: https://discord.com/developers/docs/topics/gateway#list-of-intents
config :nostrum,
  gateway_intents: [:guilds, :guild_messages, :message_content],
  # ETS-backed caches — zero extra dependencies, restarts cleanly on crash.
  caches: %{
    guilds: Nostrum.Cache.GuildCache.ETS,
    users: Nostrum.Cache.UserCache.ETS,
    channels: Nostrum.Cache.ChannelGuildMapping.ETS,
    members: Nostrum.Cache.MemberCache.ETS
  },

  ffmpeg: nil
