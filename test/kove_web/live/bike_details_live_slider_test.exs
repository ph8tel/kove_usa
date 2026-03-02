defmodule KoveWeb.BikeDetailsLiveSliderTest do
  use KoveWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    engine_attrs = %{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc",
      starter: "Electric"
    }

    {:ok, engine} =
      Kove.Repo.insert(Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, engine_attrs))

    {:ok, engine: engine}
  end

  defp create_bike(engine, opts \\ []) do
    slug = Keyword.get(opts, :slug, "2026-kove-800x-rally")

    bike_attrs = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Rally",
      year: 2026,
      variant: "Rally",
      slug: slug,
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900
    }

    {:ok, bike} =
      Kove.Repo.insert(Kove.Bikes.Bike.changeset(%Kove.Bikes.Bike{}, bike_attrs))

    bike
  end

  defp create_images(bike, count) do
    for i <- 1..count do
      image_attrs = %{
        bike_id: bike.id,
        url: "https://example.com/bike-#{i}.jpg",
        alt: "Bike image #{i}",
        position: i,
        is_hero: i == 1
      }

      {:ok, image} =
        Kove.Repo.insert(Kove.Images.Image.changeset(%Kove.Images.Image{}, image_attrs))

      image
    end
  end

  describe "slider with no images" do
    test "shows placeholder when bike has no images", %{conn: conn, engine: engine} do
      bike = create_bike(engine)
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "#image-slider svg")
      refute has_element?(view, "#image-slider img")
      refute has_element?(view, "button[phx-click=prev_image]")
      refute has_element?(view, "button[phx-click=next_image]")
    end
  end

  describe "slider with single image" do
    test "shows the image without navigation controls", %{conn: conn, engine: engine} do
      bike = create_bike(engine)
      _images = create_images(bike, 1)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "#image-slider img[src='https://example.com/bike-1.jpg']")
      refute has_element?(view, "button[phx-click=prev_image]")
      refute has_element?(view, "button[phx-click=next_image]")
      refute has_element?(view, "button[phx-click=goto_image]")
    end
  end

  describe "slider with multiple images" do
    setup %{engine: engine} do
      bike = create_bike(engine)
      images = create_images(bike, 3)
      {:ok, bike: bike, images: images}
    end

    test "shows first image on mount", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "#image-slider img[src='https://example.com/bike-1.jpg']")
    end

    test "shows navigation controls", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "button[phx-click=prev_image]")
      assert has_element?(view, "button[phx-click=next_image]")
    end

    test "shows dot indicators for each image", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "button[phx-click=goto_image][phx-value-index='0']")
      assert has_element?(view, "button[phx-click=goto_image][phx-value-index='1']")
      assert has_element?(view, "button[phx-click=goto_image][phx-value-index='2']")
    end

    test "shows counter badge", %{conn: conn, bike: bike} do
      {:ok, _view, html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert html =~ "1 / 3"
    end

    test "next_image advances to second image", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = render_click(view, "next_image")

      assert html =~ "https://example.com/bike-2.jpg"
      assert html =~ "2 / 3"
    end

    test "prev_image from first wraps to last image", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = render_click(view, "prev_image")

      assert html =~ "https://example.com/bike-3.jpg"
      assert html =~ "3 / 3"
    end

    test "next_image from last wraps to first image", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Advance to the last image
      render_click(view, "next_image")
      render_click(view, "next_image")

      html = render_click(view, "next_image")

      assert html =~ "https://example.com/bike-1.jpg"
      assert html =~ "1 / 3"
    end

    test "goto_image jumps to specific image", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = render_click(view, "goto_image", %{"index" => "2"})

      assert html =~ "https://example.com/bike-3.jpg"
      assert html =~ "3 / 3"
    end

    test "goto_image clamps out-of-range index", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = render_click(view, "goto_image", %{"index" => "99"})

      # Should clamp to last image (index 2)
      assert html =~ "https://example.com/bike-3.jpg"
      assert html =~ "3 / 3"
    end

    test "full navigation cycle through all images", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Start at image 1
      assert render(view) =~ "https://example.com/bike-1.jpg"

      # Forward through all
      html = render_click(view, "next_image")
      assert html =~ "https://example.com/bike-2.jpg"

      html = render_click(view, "next_image")
      assert html =~ "https://example.com/bike-3.jpg"

      # Back through all
      html = render_click(view, "prev_image")
      assert html =~ "https://example.com/bike-2.jpg"

      html = render_click(view, "prev_image")
      assert html =~ "https://example.com/bike-1.jpg"
    end

    test "active dot indicator updates on navigation", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Initially first dot is active (has bg-primary)
      assert has_element?(view, "button[phx-value-index='0'].bg-primary")
      refute has_element?(view, "button[phx-value-index='1'].bg-primary")

      # Navigate to second image
      render_click(view, "next_image")

      refute has_element?(view, "button[phx-value-index='0'].bg-primary")
      assert has_element?(view, "button[phx-value-index='1'].bg-primary")
    end
  end

  describe "image ordering" do
    test "images are displayed sorted by position", %{conn: conn, engine: engine} do
      bike = create_bike(engine)

      # Insert images out of order
      Kove.Repo.insert!(
        Kove.Images.Image.changeset(%Kove.Images.Image{}, %{
          bike_id: bike.id,
          url: "https://example.com/third.jpg",
          alt: "Third",
          position: 3,
          is_hero: false
        })
      )

      Kove.Repo.insert!(
        Kove.Images.Image.changeset(%Kove.Images.Image{}, %{
          bike_id: bike.id,
          url: "https://example.com/first.jpg",
          alt: "First",
          position: 1,
          is_hero: true
        })
      )

      Kove.Repo.insert!(
        Kove.Images.Image.changeset(%Kove.Images.Image{}, %{
          bike_id: bike.id,
          url: "https://example.com/second.jpg",
          alt: "Second",
          position: 2,
          is_hero: false
        })
      )

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # First image shown should be position 1
      assert has_element?(view, "#image-slider img[src='https://example.com/first.jpg']")

      # Navigate forward — should get position 2
      html = render_click(view, "next_image")
      assert html =~ "https://example.com/second.jpg"

      # Navigate forward again — should get position 3
      html = render_click(view, "next_image")
      assert html =~ "https://example.com/third.jpg"
    end
  end
end
