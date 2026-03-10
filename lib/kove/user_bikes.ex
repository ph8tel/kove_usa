defmodule Kove.UserBikes do
  @moduledoc """
  Context for managing the relationship between users and their bikes (the user's garage).
  """

  import Ecto.Query
  alias Kove.Repo
  alias Kove.UserBikes.UserBike
  alias Kove.UserBikes.UserBikeImage
  alias Kove.UserBikes.UserBikeMod

  @doc """
  Returns the user_bike for a given user, preloading the bike and its associations
  plus user-uploaded images ordered by position.
  Users currently have at most one bike.
  """
  def get_user_bike(user) do
    images_query = from(i in UserBikeImage, order_by: [asc: i.position])
    mods_query = from(m in UserBikeMod, order_by: [asc: m.position])

    UserBike
    |> where(user_id: ^user.id)
    |> preload([
      :user,
      images: ^images_query,
      mods: ^mods_query,
      bike: [:engine, :images, :chassis_spec, :dimension, :bike_features, :descriptions]
    ])
    |> Repo.one()
  end

  @doc """
  Creates a user_bike record, associating a user with their bike selection.
  """
  def create_user_bike(user, attrs) do
    %UserBike{}
    |> UserBike.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> normalize_bike_id()
    |> Repo.insert()
  end

  @doc """
  Updates an existing user_bike record.
  """
  def update_user_bike(%UserBike{} = user_bike, attrs) do
    user_bike
    |> UserBike.changeset(attrs)
    |> normalize_bike_id()
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking user_bike changes.
  """
  def change_user_bike(%UserBike{} = user_bike, attrs \\ %{}) do
    UserBike.changeset(user_bike, attrs)
  end

  # ── Image management ──

  @doc """
  Adds an image to a user_bike. Sets position to the next available slot.
  """
  def add_image(%UserBike{} = user_bike, url, storage_key \\ nil) do
    next_position =
      UserBikeImage
      |> where(user_bike_id: ^user_bike.id)
      |> select([i], coalesce(max(i.position), -1) + 1)
      |> Repo.one()

    %UserBikeImage{}
    |> UserBikeImage.changeset(%{url: url, storage_key: storage_key, position: next_position})
    |> Ecto.Changeset.put_change(:user_bike_id, user_bike.id)
    |> Repo.insert()
  end

  @doc """
  Deletes a user bike image by ID. Also deletes from R2 if storage_key is set.
  """
  def delete_image(image_id) do
    case Repo.get(UserBikeImage, image_id) do
      nil ->
        {:error, :not_found}

      image ->
        if image.storage_key, do: Kove.Storage.delete(image.storage_key)
        Repo.delete(image)
    end
  end

  @doc """
  Lists all images for a user_bike, ordered by position.
  """
  def list_images(%UserBike{} = user_bike) do
    UserBikeImage
    |> where(user_bike_id: ^user_bike.id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  # ── Mod management ──

  @doc """
  Adds a mod to a user_bike. Sets position to the next available slot.
  """
  def add_mod(%UserBike{} = user_bike, attrs) do
    next_position =
      UserBikeMod
      |> where(user_bike_id: ^user_bike.id)
      |> select([m], coalesce(max(m.position), -1) + 1)
      |> Repo.one()

    %UserBikeMod{}
    |> UserBikeMod.changeset(Map.put(attrs, "position", next_position))
    |> Ecto.Changeset.put_change(:user_bike_id, user_bike.id)
    |> Repo.insert()
  end

  @doc """
  Updates an existing mod.
  """
  def update_mod(%UserBikeMod{} = mod, attrs) do
    mod
    |> UserBikeMod.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a mod by ID.
  """
  def delete_mod(mod_id) do
    case Repo.get(UserBikeMod, mod_id) do
      nil -> {:error, :not_found}
      mod -> Repo.delete(mod)
    end
  end

  @doc """
  Lists all mods for a user_bike, ordered by position.
  """
  def list_mods(%UserBike{} = user_bike) do
    UserBikeMod
    |> where(user_bike_id: ^user_bike.id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  @doc """
  Returns a changeset for tracking mod changes.
  """
  def change_mod(%UserBikeMod{} = mod, attrs \\ %{}) do
    UserBikeMod.changeset(mod, attrs)
  end

  # Treat empty-string bike_id as nil (the "None" option)
  defp normalize_bike_id(changeset) do
    case Ecto.Changeset.get_change(changeset, :bike_id) do
      "" -> Ecto.Changeset.put_change(changeset, :bike_id, nil)
      _ -> changeset
    end
  end
end
