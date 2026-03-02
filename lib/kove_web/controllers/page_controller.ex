defmodule KoveWeb.PageController do
  use KoveWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
