defmodule KoveWeb.PageControllerTest do
  use KoveWeb.ConnCase, async: true

  describe "GET /privacy-policy" do
    test "renders the privacy policy page", %{conn: conn} do
      conn = get(conn, ~p"/privacy-policy")
      html = html_response(conn, 200)

      assert html =~ "Privacy Policy"
      assert html =~ "Information We Collect"
      assert html =~ "Google OAuth"
    end
  end
end
