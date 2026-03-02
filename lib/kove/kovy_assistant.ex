defmodule Kove.KovyAssistant do
  @moduledoc """
  GenServer that manages Kovy chat sessions.

  Receives chat requests from LiveViews, builds structured prompts with
  full bike context, and streams Groq responses back to the caller.
  """

  use GenServer

  alias Kove.KovyAssistant.Prompt

  require Logger

  defp groq_module do
    Application.get_env(:kove, :groq_module, Kove.KovyAssistant.Groq)
  end

  # ── Client API ───────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a chat message for `bike` with the given `chat_history`.

  `chat_history` should be a list of `%{role: :user | :assistant, content: ...}` maps
  representing the conversation so far (including the latest user message).

  Response tokens are streamed back to `caller_pid` (defaults to `self()`) as:

    * `{:kovy_chunk, text}`
    * `{:kovy_done}`
    * `{:kovy_error, reason}`
  """
  def send_message(bike, chat_history, caller_pid \\ self()) do
    GenServer.cast(__MODULE__, {:send_message, bike, chat_history, caller_pid})
  end

  # ── Server callbacks ─────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:send_message, bike, chat_history, caller_pid}, state) do
    Logger.info("KovyAssistant: starting chat for #{bike.name}, history=#{length(chat_history)} msgs, caller=#{inspect(caller_pid)}")

    Task.Supervisor.start_child(Kove.TaskSupervisor, fn ->
      groq = groq_module()
      Logger.info("KovyAssistant task: building prompt for #{bike.name}")
      system_prompt = Prompt.build_system_prompt(bike)

      api_messages =
        [
          %{"role" => "system", "content" => system_prompt}
          | Enum.map(chat_history, fn msg ->
              %{"role" => to_string(msg.role), "content" => msg.content}
            end)
        ]

      Logger.info("KovyAssistant task: sending #{length(api_messages)} messages to Groq (key=#{if groq.api_key_available?(), do: "SET", else: "MISSING"})")
      groq.stream_chat(api_messages, caller_pid)
    end)

    {:noreply, state}
  end
end
