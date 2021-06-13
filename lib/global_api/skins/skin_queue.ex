defmodule GlobalApi.SkinQueue do
  use GenServer

  alias GlobalApi.SkinUploader

  @type t :: %__MODULE__{queue: List.t(), uploader_ready: bool}

  defstruct queue: :queue.new(), uploader_ready: true

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def add_request({_rgba_hash, _is_steve, _png} = data) do
    GenServer.cast(__MODULE__, {:push, data})
  end

  def resume() do
    send __MODULE__, :next
  end

  def get_queue_length() do
    GenServer.call(__MODULE__, :queue_length)
  end

  @impl true
  def handle_cast({:push, request}, state) do
    if state.uploader_ready do
      state = %{state | uploader_ready: false}
      SkinUploader.send_next(self(), request)
      {:noreply, state}
    else
      {:noreply, %{state | queue: :queue.in(request, state.queue)}}
    end
  end

  @impl true
  @doc """
  Send once the SkinUploader is ready to handle another request
  """
  def handle_info(:next, state) do
    if :queue.is_empty(state.queue) do
      {:noreply, %{state | uploader_ready: true}}
    else
      {{:value, result}, queue} = :queue.out(state.queue)
      SkinUploader.send_next(self(), result)
      {:noreply, %{state | queue: queue}}
    end
  end

  @impl true
  def handle_call(:queue_length, _, state) do
    # this is not very efficient
    {:reply, :queue.len(state.queue), state}
  end
end
