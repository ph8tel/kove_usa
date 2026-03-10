defmodule Kove.Repo.Migrations.CreateUserBikes do
  use Ecto.Migration

  def change do
    create table(:user_bikes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :bike_id, references(:bikes, on_delete: :restrict)
      add :bike_image_url, :string
      add :nickname, :string

      timestamps(type: :utc_datetime)
    end

    create index(:user_bikes, [:user_id])
    create index(:user_bikes, [:bike_id])
  end
end
