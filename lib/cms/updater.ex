defmodule CMS.Updater do
  use GenServer

  require Logger

  defmodule State do
    defstruct [:opts, :ref]
  end

  @task_supervisor CMS.TaskSupervisor

  @init_opts_validation [
    module: [
      type: :atom,
      required: true
    ],
    interval: [
      type: :pos_integer,
      default: 120_000
    ],
    error_interval: [
      type: :pos_integer,
      default: 10_000
    ]
  ]

  ###
  # Client API
  ###

  def start_link(opts) do
    opts = NimbleOptions.validate!(opts, @init_opts_validation)

    GenServer.start_link(__MODULE__, opts, name: opts[:module])
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

    {:noreply, %{state | ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{ref: ref} = state) do
    Process.send_after(self(), :sync, Keyword.fetch!(state.opts, :error_interval))

    {:noreply, %{state | ref: nil}}
  end
end
