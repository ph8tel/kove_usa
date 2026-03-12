defmodule KoveWeb.UserLive.GoogleOAuthButtonTest do
  # async: false — tests manipulate global Application config, so they must
  # not run concurrently with each other or with other test files.
  use KoveWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Save and restore Application config around every test so changes made
  # inside a test never leak into other tests.
  setup do
    original_google_oauth = Application.get_env(:kove, :google_oauth)

    on_exit(fn ->
      if original_google_oauth do
        Application.put_env(:kove, :google_oauth, original_google_oauth)
      else
        Application.delete_env(:kove, :google_oauth)
      end
    end)

    :ok
  end

  # -------------------------------------------------------------------------
  # Login page
  # -------------------------------------------------------------------------

  describe "login page - Google OAuth button" do
    test "shows Google button when OAuth is configured", %{conn: conn} do
      Application.put_env(:kove, :google_oauth,
        client_id: "test-client-id",
        client_secret: "test-secret",
        redirect_uri: "http://localhost/auth/google/callback"
      )

      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Continue with Google"
      assert html =~ ~p"/auth/google"
    end

    test "hides Google button when OAuth is not configured", %{conn: conn} do
      Application.delete_env(:kove, :google_oauth)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      refute html =~ "Continue with Google"
      refute html =~ ~p"/auth/google"
    end

    test "hides both surrounding dividers when OAuth is not configured", %{conn: conn} do
      Application.delete_env(:kove, :google_oauth)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      # The page should still render (no crash), just without the Google section
      assert html =~ "Log in with email"
      assert html =~ "Log in and stay logged in"
      refute html =~ "Continue with Google"
    end
  end

  # -------------------------------------------------------------------------
  # Registration page
  # -------------------------------------------------------------------------

  describe "registration page - Google OAuth button" do
    test "shows Google button when OAuth is configured", %{conn: conn} do
      Application.put_env(:kove, :google_oauth,
        client_id: "test-client-id",
        client_secret: "test-secret",
        redirect_uri: "http://localhost/auth/google/callback"
      )

      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Continue with Google"
      assert html =~ ~p"/auth/google"
    end

    test "hides Google button when OAuth is not configured", %{conn: conn} do
      Application.delete_env(:kove, :google_oauth)

      {:ok, _lv, html} = live(conn, ~p"/users/register")

      refute html =~ "Continue with Google"
      refute html =~ ~p"/auth/google"
    end

    test "hides the 'or sign up with' divider when OAuth is not configured", %{conn: conn} do
      Application.delete_env(:kove, :google_oauth)

      {:ok, _lv, html} = live(conn, ~p"/users/register")

      # Page still renders normally — only the Google section is absent
      assert html =~ "Create an account"
      refute html =~ "or sign up with"
    end
  end

  # -------------------------------------------------------------------------
  # Controller guard — /auth/google when not configured
  # -------------------------------------------------------------------------

  describe "GET /auth/google - request action guard" do
    test "redirects with error flash when OAuth is not configured", %{conn: conn} do
      Application.delete_env(:kove, :google_oauth)

      conn = get(conn, ~p"/auth/google")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not configured"
    end

    test "does not redirect when OAuth is configured", %{conn: conn} do
      Application.put_env(:kove, :google_oauth,
        client_id: "test-client-id",
        client_secret: "test-secret",
        redirect_uri: "http://localhost/auth/google/callback"
      )

      conn = get(conn, ~p"/auth/google")

      # Should redirect externally to Google (not back to our login page)
      location = get_resp_header(conn, "location") |> List.first()
      assert location =~ "accounts.google.com"
      refute redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
