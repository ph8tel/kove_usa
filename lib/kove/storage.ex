defmodule Kove.Storage do
  @moduledoc """
  Cloudflare R2 object storage for user bike photos.

  Uses AWS Signature V4 (via `Kove.Storage.S3Signer`) to authenticate against
  R2's S3-compatible API.  Uploads go through the server via LiveView file
  uploads, then are PUT to R2.

  ## Configuration

  Set in `config/runtime.exs` (loaded from environment variables):

      config :kove, Kove.Storage,
        enabled: true,
        endpoint: "https://<ACCOUNT_ID>.r2.cloudflarestorage.com",
        bucket: "kove-uploads",
        access_key_id: "...",
        secret_access_key: "...",
        public_url: "https://images.kovemotousa.com",
        region: "auto"

  When `:enabled` is `false` (default in dev/test), uploads return a placeholder URL.
  """

  alias Kove.Storage.S3Signer

  @doc """
  Uploads a local file to R2 and returns `{:ok, public_url}` or `{:error, reason}`.
  """
  def upload_file(file_path, object_key, content_type \\ "image/jpeg") do
    config = config()

    require Logger

    if config[:enabled] do
      Logger.info(
        "R2 upload: key=#{object_key} bucket=#{config[:bucket]} endpoint=#{config[:endpoint]}"
      )

      body = File.read!(file_path)
      url = endpoint_url(config, object_key)

      headers =
        S3Signer.sign_headers(:put, url, [{"content-type", content_type}], body, config)

      case Req.put(url, body: body, headers: headers) do
        {:ok, %{status: status}} when status in 200..299 ->
          {:ok, public_url(object_key, config)}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, "R2 upload failed (#{status}): #{inspect(resp_body)}"}

        {:error, exception} ->
          {:error, "R2 upload error: #{Exception.message(exception)}"}
      end
    else
      # Storage disabled (dev/test) — return a placeholder
      Logger.warning("R2 storage disabled — returning placeholder for #{object_key}")
      {:ok, placeholder_url(object_key)}
    end
  end

  @doc """
  Deletes an object from R2. Best-effort — returns `:ok` even on 404.
  """
  def delete(object_key) do
    config = config()

    if config[:enabled] do
      url = endpoint_url(config, object_key)
      headers = S3Signer.sign_headers(:delete, url, [], "", config)

      case Req.delete(url, headers: headers) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: 404}} -> :ok
        _ -> :ok
      end
    else
      :ok
    end
  end

  @doc """
  Returns the public URL for an object key.
  """
  def public_url(object_key, config \\ nil) do
    config = config || config()
    "#{config[:public_url]}/#{object_key}"
  end

  @doc """
  Generates a unique object key for a user upload.

  Keys are namespaced under `bike-photos/` with a UUID filename to avoid collisions.
  """
  def generate_key(original_filename) do
    ext = original_filename |> Path.extname() |> String.downcase()
    uuid = Ecto.UUID.generate()
    "bike-photos/#{uuid}#{ext}"
  end

  @doc """
  Returns `true` if R2 storage is configured and enabled.
  """
  def enabled? do
    config()[:enabled] == true
  end

  # ── Private ──

  defp endpoint_url(config, object_key) do
    "#{config[:endpoint]}/#{config[:bucket]}/#{object_key}"
  end

  defp placeholder_url(object_key) do
    "/uploads/#{object_key}"
  end

  defp config do
    Application.get_env(:kove, __MODULE__, [])
  end
end
