defmodule Kove.Repo.Migrations.SeedOilChangeKits do
  use Ecto.Migration

  @doc """
  Data migration: seeds the 4 oil change kits (one per engine platform)
  and their engine compatibilities. Idempotent — uses ON CONFLICT DO NOTHING.
  """

  def up do
    # Fetch engine IDs by platform_name prefix
    engine_map =
      for {match, sku, name, desc, price} <- kits_data(), into: %{} do
        engine_id =
          repo().query!(
            "SELECT id FROM engines WHERE platform_name LIKE $1 LIMIT 1",
            ["#{match}%"]
          )
          |> Map.get(:rows)
          |> List.first()
          |> case do
            [id] -> id
            _ -> nil
          end

        {sku, %{engine_id: engine_id, name: name, description: desc, price_cents: price}}
      end

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    Enum.each(engine_map, fn {sku, data} ->
      if data.engine_id do
        # Insert kit (idempotent)
        repo().query!(
          """
          INSERT INTO part_kits (sku, name, description, price_cents, active, inserted_at, updated_at)
          VALUES ($1, $2, $3, $4, true, $5, $5)
          ON CONFLICT (sku) DO NOTHING
          """,
          [sku, data.name, data.description, data.price_cents, now]
        )

        # Insert compatibility (idempotent)
        repo().query!(
          """
          INSERT INTO part_kit_compatibilities (part_kit_id, engine_id, inserted_at, updated_at)
          SELECT pk.id, $1, $2, $2
          FROM part_kits pk
          WHERE pk.sku = $3
          ON CONFLICT (part_kit_id, engine_id) DO NOTHING
          """,
          [data.engine_id, now, sku]
        )
      end
    end)
  end

  def down do
    # Remove order_items → compatibilities → kits (respecting FK order)
    skus = Enum.map(kits_data(), fn {_, sku, _, _, _} -> sku end)

    repo().query!(
      """
      DELETE FROM order_items
      WHERE part_kit_id IN (SELECT id FROM part_kits WHERE sku = ANY($1))
      """,
      [skus]
    )

    repo().query!(
      """
      DELETE FROM part_kit_compatibilities
      WHERE part_kit_id IN (SELECT id FROM part_kits WHERE sku = ANY($1))
      """,
      [skus]
    )

    repo().query!("DELETE FROM part_kits WHERE sku = ANY($1)", [skus])
  end

  defp kits_data do
    [
      {"800X", "OIL-KIT-800X", "800X Oil Change Kit",
       "Complete oil change kit for the 800X twin — includes 3.5L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
       6499},
      {"450 Rally", "OIL-KIT-450R", "450 Rally Oil Change Kit",
       "Complete oil change kit for the 450 Rally — includes 1.6L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
       4299},
      {"MX450", "OIL-KIT-MX450", "MX450 Oil Change Kit",
       "Complete oil change kit for the MX450 — includes 1.4L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
       3999},
      {"MX250", "OIL-KIT-MX250", "MX250 Oil Change Kit",
       "Complete oil change kit for the MX250 — includes 1.1L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
       3499}
    ]
  end
end
