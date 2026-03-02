defmodule Kove.Repo do
  use Ecto.Repo,
    otp_app: :kove,
    adapter: Ecto.Adapters.Postgres
end
