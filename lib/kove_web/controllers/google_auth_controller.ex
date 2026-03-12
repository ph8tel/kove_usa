defmodule KoveWeb.GoogleAuthController do
  use KoveWeb, :controller

  alias Kove.Accounts
  alias Kove.Accounts.GoogleOAuth
  alias KoveWeb.UserAuth

  @doc """
  Initiates the Google OAuth flow.

  Generates a random state token for CSRF protection, stores it in the session,
  and redirects the browser to Google's authorization endpoint.
  """
  def request(conn, _params) do
    if GoogleOAuth.configured?() do
      state = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      conn
      |> put_session(:google_oauth_state, state)
      |> redirect(external: GoogleOAuth.authorize_url(state))
    else
      conn
      |> put_flash(:error, "Google sign-in is not configured.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  Handles the callback from Google after the user grants (or denies) access.

  On success: exchanges the code for a token, fetches user info, finds or
  creates the user, and logs them in.
  On failure: shows an error flash and redirects to the login page.
  """
  def callback(conn, %{"code" => code, "state" => state}) do
    expected_state = get_session(conn, :google_oauth_state)
    conn = delete_session(conn, :google_oauth_state)

    if state != expected_state do
      conn
      |> put_flash(:error, "Invalid OAuth state — please try again.")
      |> redirect(to: ~p"/users/log-in")
    else
      with {:ok, access_token} <- GoogleOAuth.exchange_code_for_token(code),
           {:ok, user_info} <- GoogleOAuth.get_user_info(access_token),
           {:ok, user} <- Accounts.register_or_login_with_google(user_info) do
        conn
        |> put_flash(:info, "Signed in with Google!")
        |> UserAuth.log_in_user(user)
      else
        {:error, _reason} ->
          conn
          |> put_flash(:error, "Google sign-in failed. Please try again.")
          |> redirect(to: ~p"/users/log-in")
      end
    end
  end

  def callback(conn, %{"error" => _error}) do
    conn
    |> put_flash(:error, "Google sign-in was cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  # Catch-all for unexpected callback params
  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Something went wrong with Google sign-in.")
    |> redirect(to: ~p"/users/log-in")
  end
end
