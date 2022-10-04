defmodule CMS.Updater do
  use GenServer

  require Logger

  defmodule State do
    @moduledoc false
    defstruct awaiting_init: [],
              initialized?: false,
              opts: nil,
              ref: nil
  end

  @task_supervisor CMS.TaskSupervisor

  @init_opts_validation [
    module: [
      type: :atom,
      required: true
    ],
    interval: [
      type: :pos_integer,
      default: :timer.minutes(15)
    ],
    error_interval: [
      type: :pos_integer,
      default: 10_000
    ]
  ]

  ###
  # Client API
  ###

  @doc """
  Starts server.

  ## Options

  #{NimbleOptions.docs(@init_opts_validation)}
  """
  def start_link(opts) do
    opts = NimbleOptions.validate!(opts, @init_opts_validation)

    GenServer.start_link(__MODULE__, opts, name: opts[:module])
  end

  @await_initialization_opts_validation [
    timeout: [
      type: :pos_integer,
      default: 5_000,
      doc: "Milliseconds to wait for response."
    ]
  ]

  @doc """
  Waits until the content has been initialized. Returns `:ok` if the content has been initialized
  or `{:error, :timeout}` if a timeout occurs.

  ## Options

  #{NimbleOptions.docs(@await_initialization_opts_validation)}
  """
  def await_initialization(server, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @await_initialization_opts_validation)
    timeout = Keyword.fetch!(opts, :timeout)

    GenServer.call(server, {:await_initialization, timeout: timeout}, timeout + 5_000)
  end

  ###
  # Server API
  ###

  @impl true
  def init(opts) do
    send(self(), :sync)

    {:ok, %State{opts: opts}}
  end

  @impl true
  def handle_call({:await_initialization, timeout: timeout}, from, %{initialized?: false} = state) do
    Process.send_after(self(), {:timeout, from}, timeout)

    {:noreply, %{state | awaiting_init: [from | state.awaiting_init]}}
  end

  def handle_call({:await_initialization, timeout: _}, _from, %{initialized?: true} = state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:sync, state) do
    mod = Keyword.fetch!(state.opts, :module)

    Logger.info("syncing #{inspect(mod)} #{inspect(state.opts)}")

    %Task{ref: ref} =
      Task.Supervisor.async_nolink(@task_supervisor, fn ->
        :ok = CMS.update(mod)
      end)

    {:noreply, %{state | ref: ref}}
  end

  def handle_info({ref, :ok}, %{ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    Process.send_after(self(), :sync, Keyword.fetch!(state.opts, :interval))

    Enum.each(state.awaiting_init, fn from ->
      GenServer.reply(from, :ok)
    end)

    {:noreply, %{state | awaiting_init: [], initialized?: true, ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{ref: ref} = state) do
    Process.send_after(self(), :sync, Keyword.fetch!(state.opts, :error_interval))

    {:noreply, %{state | ref: nil}}
  end

  def handle_info({:timeout, from}, state) do
    GenServer.reply(from, {:error, :timeout})

    {:noreply, state}
  end
end
