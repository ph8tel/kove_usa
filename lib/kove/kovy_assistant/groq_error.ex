defmodule Kove.KovyAssistant.GroqError do
  @moduledoc """
  Custom exception for Groq API errors with user-friendly categorization.

  Supports categorized error types for better logging and UI-level error handling:
  - `:rate_limited` — Groq API rate limit hit (429)
  - `:auth_failed` — Authentication failed (401)
  - `:invalid_request` — Bad request format (400)
  - `:server_error` — Groq server error (5xx)
  - `:timeout` — Request timed out
  - `:connection` — Network/connection error
  - `:internal_error` — Unexpected task/process failure
  - `:retry_exhausted` — Retries failed
  - `:unknown` — Uncategorized error
  """

  defexception [:type, :status, :message, :original_error]

  def message(e) do
    case e.type do
      :rate_limited ->
        "Kovy is busy handling requests. Please try again in a moment."

      :auth_failed ->
        "Kovy can't authenticate. Please contact support."

      :invalid_request ->
        "Your message format caused an issue. Try rephrasing."

      :server_error ->
        "Groq's servers are having issues. Please try again shortly."

      :timeout ->
        "Request took too long. Please try a shorter question."

      :connection ->
        "Lost connection to Kovy's brain. Please try again."

      :internal_error ->
        "Kovy encountered an internal error. Please try again."

      :retry_exhausted ->
        "Couldn't connect to Kovy after multiple attempts. Please try again."

      _ ->
        "Kovy error: #{e.message}"
    end
  end

  @doc """
  Create an error from an HTTP status code and response body.
  """
  def from_http_response(status, body) do
    error_type = categorize_status(status)
    error_message = extract_message(body)

    %__MODULE__{
      type: error_type,
      status: status,
      message: error_message,
      original_error: body
    }
  end

  defp categorize_status(status) do
    case status do
      401 -> :auth_failed
      429 -> :rate_limited
      400 -> :invalid_request
      500..599 -> :server_error
      _ -> :unknown
    end
  end

  defp extract_message(body) do
    case body do
      %{"error" => %{"message" => msg}} -> msg
      %{"error" => msg} when is_binary(msg) -> msg
      body when is_binary(body) -> body
      _ -> "Unknown error"
    end
  end
end
