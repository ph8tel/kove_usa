defmodule Kove.Repo.Migrations.CreateUserBikeImages do
  use Ecto.Migration

  def change do
    create table(:user_bike_images) do
      add :user_bike_id, references(:user_bikes, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :storage_key, :string
      add :position, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_bike_images, [:user_bike_id, :position])

    # Migrate existing bike_image_url data into the new table
    execute(
      """
      INSERT INTO user_bike_images (user_bike_id, url, position, inserted_at, updated_at)
      SELECT id, bike_image_url, 0, now(), now()
      FROM user_bikes
      WHERE bike_image_url IS NOT NULL AND bike_image_url != ''
      """,
      """
      UPDATE user_bikes SET bike_image_url = (
        SELECT url FROM user_bike_images
        WHERE user_bike_images.user_bike_id = user_bikes.id
        ORDER BY position LIMIT 1
      )
      """
    )
  end
end
