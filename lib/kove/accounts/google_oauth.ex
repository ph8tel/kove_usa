defmodule Kove.Accounts.GoogleOAuth do
  @moduledoc """
  Handles the Google OAuth 2.0 flow for rider sign-in / registration.

  Uses `Req` (already a project dependency) for all HTTP calls.
  Credentials are loaded from the application config (set via runtime.exs
  from `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, and
  `GOOGLE_OAUTH_REDIRECT_URI` environment variables).
  """

  @google_auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @google_token_url "https://oauth2.googleapis.com/token"
  @google_userinfo_url "https://www.googleapis.com/oauth2/v3/userinfo"

  @doc """
  Builds the Google OAuth 2.0 authorization URL.

  The `state` parameter is a CSRF token that should be stored in the session
  and verified when Google calls back.
  """
  def authorize_url(state) do
    params = %{
      client_id: client_id(),
      redirect_uri: redirect_uri(),
      response_type: "code",
      scope: "openid email profile",
      access_type: "online",
      state: state
    }

    "#{@google_auth_url}?#{URI.encode_query(params)}"
  end

  @doc """
  Exchanges an authorization `code` for an access token.

  Returns `{:ok, access_token}` or `{:error, reason}`.
  """
  def exchange_code_for_token(code) do
    body = %{
      client_id: client_id(),
      client_secret: client_secret(),
      code: code,
      grant_type: "authorization_code",
      redirect_uri: redirect_uri()
    }

    case Req.post(@google_token_url, form: body) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["access_token"]}

      {:ok, %{body: body}} ->
        {:error, "Token exchange failed: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches the Google user's profile information using an `access_token`.

  Returns `{:ok, %{email: email, google_id: sub, name: name}}` or `{:error, reason}`.
  """
  def get_user_info(access_token) do
    case Req.get(@google_userinfo_url,
           headers: [{"authorization", "Bearer #{access_token}"}]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           email: body["email"],
           google_id: body["sub"],
           name: body["name"]
         }}

      {:ok, %{body: body}} ->
        {:error, "User info fetch failed: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns true if Google OAuth is configured (all three credentials are present).
  """
  def configured? do
    config = Application.get_env(:kove, :google_oauth, [])

    not is_nil(config[:client_id]) and not is_nil(config[:client_secret]) and
      not is_nil(config[:redirect_uri])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp client_id do
    Application.fetch_env!(:kove, :google_oauth)[:client_id]
  end

  defp client_secret do
    Application.fetch_env!(:kove, :google_oauth)[:client_secret]
  end

  defp redirect_uri do
    Application.fetch_env!(:kove, :google_oauth)[:redirect_uri]
  end
end
