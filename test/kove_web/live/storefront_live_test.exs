defmodule KoveWeb.StorefrontLiveTest do
  use KoveWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Kove.Bikes.Bike
  alias Kove.Engines.Engine

  setup do
    engine_attrs = %{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
      starter: "Electric"
    }

    {:ok, engine} = Kove.Repo.insert(Engine.changeset(%Engine{}, engine_attrs))

    bike_attrs = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Rally",
      year: 2026,
      variant: "Rally",
      slug: "2026-kove-800x-rally",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900,
      hero_image_url: "https://example.com/hero.jpg"
    }

    {:ok, bike} = Kove.Repo.insert(Bike.changeset(%Bike{}, bike_attrs))
    {:ok, bike: bike}
  end

  test "GET / renders the storefront with bikes", %{conn: conn, bike: bike} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "KOVE MOTO"
    assert html_response(conn, 200) =~ bike.name
  end

  test "storefront displays bike price", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "$12,999"
  end

  test "storefront displays category badge", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Adventure"
  end

  test "storefront displays engine info", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "799cc"
  end
end
