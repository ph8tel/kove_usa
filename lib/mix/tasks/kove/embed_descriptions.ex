defmodule Mix.Tasks.Kove.EmbedDescriptions do
  @shortdoc "Populate embedding vectors for all descriptions that have none"

  @moduledoc """
  Generates and stores embedding vectors for every `descriptions` row where
  `embedding IS NULL`, using the Groq `nomic-embed-text-v1.5` model.

  Safe to re-run — only rows with a `NULL` embedding are processed.

  ## Usage

      mix kove.embed_descriptions

  ## Options

      --batch-size N   Number of descriptions to embed in each batch (default: 5).
                       Lower values reduce memory; higher values are faster but
                       risk hitting Groq's requests-per-minute limit.

  ## Requirements

  `GROQ_API_KEY` must be set in the environment or in the `../.env` file.
  """

  use Mix.Task

  require Logger

  import Ecto.Query

  alias Kove.Repo
  alias Kove.Descriptions.Description
  alias Kove.KovyAssistant.Embeddings

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args, strict: [batch_size: :integer])

    batch_size = Keyword.get(opts, :batch_size, 5)

    pending =
      from(d in Description,
        where: is_nil(d.embedding),
        select: struct(d, [:id, :bike_id, :body])
      )
      |> Repo.all()

    total = length(pending)

    if total == 0 do
      Mix.shell().info("✓ All descriptions already have embeddings — nothing to do.")
    else
      Mix.shell().info("Embedding #{total} descriptions in batches of #{batch_size}…")

      pending
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)
      |> Enum.each(fn {batch, batch_num} ->
        Enum.each(batch, fn desc ->
          case Embeddings.embed_text(desc.body) do
            {:ok, vector} ->
              desc
              |> Ecto.Changeset.change(embedding: vector)
              |> Repo.update!()

              Mix.shell().info("  [#{batch_num}] ✓ description #{desc.id} (bike #{desc.bike_id})")

            {:error, :no_api_key} ->
              Mix.raise("GROQ_API_KEY is not set. Cannot generate embeddings.")

            {:error, kind, message} ->
              Mix.shell().error("  [#{batch_num}] ✗ description #{desc.id}: #{kind} — #{message}")

            {:error, kind} ->
              Mix.shell().error("  [#{batch_num}] ✗ description #{desc.id}: #{kind}")
          end
        end)

        # Brief pause between batches to stay under Groq rate limits
        unless batch_num * batch_size >= total do
          Process.sleep(200)
        end
      end)

      Mix.shell().info("\nDone. Run `mix kove.embed_descriptions` again to verify.")
    end
  end
end
