defmodule FixupxBot.Application do
  @moduledoc """
  OTP Application callback — root of the supervision tree.

  Children are started in declaration order; `FixupxBot.State` must be alive
  before `FixupxBot.Consumer` can receive the first gateway event and call
  `State.get/0`.

  Nostrum's own supervisor (`Nostrum.Application`) is started automatically by
  the `:nostrum` OTP application dependency — we don't need to include it here.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      # 1. Runtime state store — must precede the consumer.
      FixupxBot.State,

      # 2. Gateway event consumer — subscribes to nostrum's ConsumerGroup.
      FixupxBot.Consumer
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
