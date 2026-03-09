defmodule Kove.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.

  Run via:

      /app/bin/kove eval "Kove.Release.migrate()"
      /app/bin/kove eval "Kove.Release.embed_descriptions()"
  """
  @app :kove

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds the database from priv/repo/seeds.exs.
  Safe to run on a fresh database. Requires the DB to be migrated first.

  Run via:

      /app/bin/kove eval \"Kove.Release.seed()\"
  """
  def seed do
    load_app()

    [repo] = repos()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, fn _repo ->
        seeds_path = Application.app_dir(:kove, "priv/repo/seeds.exs")
        Code.eval_file(seeds_path)
      end)
  end

  @doc """
  Populates `descriptions.embedding` for every row where it is NULL.
  Safe to re-run. Requires `OPENAI_API_KEY` to be set in the environment.
  """
  def embed_descriptions do
    load_app()

    import Ecto.Query
    alias Kove.Repo
    alias Kove.Descriptions.Description
    alias Kove.KovyAssistant.Embeddings

    pending =
      from(d in Description,
        where: is_nil(d.embedding),
        select: struct(d, [:id, :bike_id, :body])
      )
      |> Repo.all()

    total = length(pending)

    if total == 0 do
      IO.puts("✓ All descriptions already have embeddings — nothing to do.")
    else
      IO.puts("Embedding #{total} descriptions…")

      pending
      |> Enum.with_index(1)
      |> Enum.each(fn {desc, n} ->
        case Embeddings.embed_text(desc.body) do
          {:ok, vector} ->
            desc
            |> Ecto.Changeset.change(embedding: vector)
            |> Repo.update!()

            IO.puts("  [#{n}/#{total}] ✓ description #{desc.id} (bike #{desc.bike_id})")

          {:error, :no_api_key} ->
            IO.puts("  ✗ OPENAI_API_KEY is not set — aborting.")
            System.halt(1)

          {:error, kind, message} ->
            IO.puts("  [#{n}/#{total}] ✗ description #{desc.id}: #{kind} — #{message}")

          {:error, kind} ->
            IO.puts("  [#{n}/#{total}] ✗ description #{desc.id}: #{kind}")
        end

        # Brief pause to stay under OpenAI rate limits
        Process.sleep(100)
      end)

      IO.puts("\nDone.")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(@app)
  end
end
