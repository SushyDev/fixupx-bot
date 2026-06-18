defmodule FixupxBot.State do
  @moduledoc """
  Runtime configuration store.

  Holds a small map that controls the bot's behaviour at runtime without
  requiring a restart.  Implemented as a named `GenServer` — this gives us
  typed callbacks, `@impl` verification by the compiler, and a clear API
  boundary.  A bare `Agent` would work for the simple case but provides none
  of those guarantees.

  ## State shape

      %{
        is_enabled: boolean(),
        mode: :webhook | :suppress
      }

  ## Thread safety

  All reads and writes go through the GenServer mailbox, so state changes are
  serialised and consistent even under high concurrency.
  """

  use GenServer
  require Logger

  @type mode :: :webhook | :suppress
  @type t :: %{is_enabled: boolean(), mode: mode()}

  @name __MODULE__

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, @name))
  end

  @doc "Returns the full configuration map."
  @spec get() :: t()
  def get, do: GenServer.call(@name, :get)

  @doc "Deep-merges `changes` into the current state and returns the new map."
  @spec update(map()) :: t()
  def update(changes) when is_map(changes) do
    GenServer.call(@name, {:update, changes})
  end

  @doc "Flips `is_enabled`; returns the new boolean value."
  @spec toggle_enabled() :: boolean()
  def toggle_enabled, do: GenServer.call(@name, :toggle_enabled)

  @doc "Sets the operating mode; returns the atom that was set."
  @spec set_mode(mode()) :: mode()
  def set_mode(mode) when mode in [:webhook, :suppress] do
    GenServer.call(@name, {:set_mode, mode})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(:ok) do
    state = %{is_enabled: true, mode: :webhook}
    Logger.info("[State] Initialized: #{inspect(state)}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get, _from, state), do: {:reply, state, state}

  def handle_call({:update, changes}, _from, state) do
    new_state = Map.merge(state, changes)
    Logger.info("[State] Updated → #{inspect(new_state)}")
    {:reply, new_state, new_state}
  end

  def handle_call(:toggle_enabled, _from, %{is_enabled: current} = state) do
    new_state = %{state | is_enabled: !current}
    Logger.info("[State] is_enabled → #{new_state.is_enabled}")
    {:reply, new_state.is_enabled, new_state}
  end

  def handle_call({:set_mode, mode}, _from, state) do
    new_state = %{state | mode: mode}
    Logger.info("[State] mode → :#{mode}")
    {:reply, mode, new_state}
  end
end
