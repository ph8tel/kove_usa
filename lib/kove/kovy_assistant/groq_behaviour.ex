defmodule Kove.KovyAssistant.GroqBehaviour do
  @moduledoc """
  Behaviour defining the contract for the Groq chat‑completion client.

  Allows the real `Groq` module to be swapped for a Mox mock in tests.
  """

  @doc "Stream a chat completion; sends `{:kovy_chunk, …}` / `{:kovy_done}` / `{:kovy_error, …}` to `caller_pid`."
  @callback stream_chat(messages :: [map()], caller_pid :: pid()) :: :ok | :error

  @doc "Synchronous (non‑streaming) chat completion."
  @callback chat(messages :: [map()]) :: {:ok, String.t()} | {:error, String.t()}

  @doc "Returns `true` when an API key is available."
  @callback api_key_available?() :: boolean()
end
