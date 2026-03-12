defmodule Kove.KovyAssistant.Embeddings do
  @moduledoc """
  Generates and queries text embeddings via the OpenAI embeddings API.

  Uses `text-embedding-3-small` at 768 dimensions — matching the
  `descriptions.embedding vector(768)` column. The `dimensions` parameter
  is supported by OpenAI's v3 embedding models and produces vectors that
  are more compact while retaining strong retrieval quality.

  ## Usage

      # One-off embedding for a piece of text
      {:ok, vector} = Embeddings.embed_text("lightweight motocross bike")

      # Find bike IDs most relevant to a user query (used by KovyAssistant)
      {:ok, bike_ids} = Embeddings.find_relevant_bike_ids("what's your lightest bike?")

  When the OPENAI_API_KEY is absent (e.g. during tests without the key set)
  both functions return `{:error, :no_api_key}` so callers can gracefully
  fall back to keyword matching without raising.
  """

  require Logger

  alias Kove.Bikes

  @embed_model "text-embedding-3-small"

  # Reads the base URL at runtime so the mock server URL can be injected
  # via the OPENAI_BASE_URL environment variable during testing.
  defp openai_embed_url do
    base = Application.get_env(:kove, :openai_base_url, "https://api.openai.com")
    base <> "/v1/embeddings"
  end

  @embed_dims 768

  defp api_key do
    Application.get_env(:kove, :openai_api_key) || System.get_env("OPENAI_API_KEY")
  end

  # ── Public API ────────────────────────────────────────────────────────

  @doc """
  Embeds `text` using the Groq embeddings API.

  Returns `{:ok, vector}` where `vector` is a `%Pgvector{}` struct ready
  to be stored in or compared against the DB column, or one of:

    * `{:error, :no_api_key}` — GROQ_API_KEY not configured
    * `{:error, :api_error, message}` — non-2xx response
    * `{:error, :unexpected, message}` — unexpected response shape
  """
  @spec embed_text(String.t()) ::
          {:ok, Pgvector.t()} | {:error, :no_api_key} | {:error, atom(), String.t()}
  def embed_text(text) when is_binary(text) do
    case api_key() do
      nil ->
        {:error, :no_api_key}

      key ->
        do_embed(String.slice(text, 0, 8_000), key)
    end
  end

  @doc """
  Embeds `user_message` and returns the bike IDs whose descriptions are
  most semantically similar (up to `limit`).

  Returns `{:ok, [bike_id]}` on success — the list may be empty if no
  embeddings are in the DB yet.

  Falls back with `{:error, reason}` when the API is unavailable so
  the caller can degrade to keyword matching.
  """
  @spec find_relevant_bike_ids(String.t(), pos_integer()) ::
          {:ok, [integer()]} | {:error, atom()} | {:error, atom(), String.t()}
  def find_relevant_bike_ids(user_message, limit \\ 4) when is_binary(user_message) do
    case embed_text(user_message) do
      {:ok, vector} ->
        try do
          bike_ids = Bikes.search_bikes_by_embedding(vector, limit)
          {:ok, bike_ids}
        rescue
          e ->
            Logger.warning(
              "Embeddings: pgvector similarity search unavailable, falling back to keyword matching",
              error: Exception.message(e)
            )

            {:error, :pgvector_unavailable}
        end

      error ->
        error
    end
  end

  # ── HTTP ──────────────────────────────────────────────────────────────

  defp do_embed(text, api_key) do
    body =
      Jason.encode!(%{
        "model" => @embed_model,
        "input" => text,
        "dimensions" => @embed_dims
      })

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    try do
      resp =
        Req.post!(openai_embed_url(),
          headers: headers,
          body: body,
          receive_timeout: 15_000
        )

      parse_response(resp)
    rescue
      e ->
        Logger.error("Embeddings request failed", error: Exception.message(e))
        {:error, :request_failed, Exception.message(e)}
    end
  end

  defp parse_response(%{status: 200, body: body}) do
    case body do
      %{"data" => [%{"embedding" => floats} | _]} when is_list(floats) ->
        {:ok, Pgvector.new(floats)}

      other ->
        Logger.error("Embeddings unexpected response shape", body: inspect(other))
        {:error, :unexpected, "Unexpected response shape from embeddings API"}
    end
  end

  defp parse_response(%{status: status, body: body}) do
    message = get_in(body, ["error", "message"]) || "HTTP #{status}"
    Logger.error("Embeddings API error", status: status, message: message)
    {:error, :api_error, message}
  end
end
