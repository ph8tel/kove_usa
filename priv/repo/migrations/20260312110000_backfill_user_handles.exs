defmodule Kove.Repo.Migrations.BackfillUserHandles do
  use Ecto.Migration

  import Ecto.Query

  def up do
    # Fetch all users without a handle
    users_without_handle =
      from(u in "users", where: is_nil(u.handle), select: {u.id, u.email})
      |> repo().all()

    for {id, email} <- users_without_handle do
      base =
        email
        |> String.split("@")
        |> List.first("")
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "_")
        |> String.replace(~r/_+/, "_")
        |> String.trim("_")
        |> String.slice(0, 25)

      base = if String.length(base) < 3, do: "rider", else: base
      suffix = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
      handle = "#{base}_#{suffix}"

      repo().update_all(
        from(u in "users", where: u.id == ^id),
        set: [handle: handle]
      )
    end
  end

  def down do
    # Backfill is not reversible — handles assigned here are left in place
    :ok
  end
end
