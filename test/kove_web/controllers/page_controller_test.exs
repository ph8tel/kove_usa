defmodule KoveWeb.PageControllerTest do
  use KoveWeb.ConnCase, async: true

  describe "GET /privacy-policy" do
    test "renders the privacy policy page", %{conn: conn} do
      conn = get(conn, ~p"/privacy-policy")

      assert html_response(conn, 200) =~ "Privacy Policy"
      assert html_response(conn, 200) =~ "Information We Collect"
      assert html_response(conn, 200) =~ "Google OAuth"
    end
  end
end
