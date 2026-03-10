defmodule KoveWeb.UserLive.Registration do
  use KoveWeb, :live_view

  alias Kove.Accounts
  alias Kove.Accounts.User
  alias Kove.Bikes
  alias Kove.UserBikes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:bike_id]}
            type="select"
            label="Which Kove do you ride?"
            options={@bike_options}
          />

          <%!-- Bike Photo Upload --%>
          <div class="form-control mt-4">
            <label class="label">
              <span class="label-text">Photo of your bike (optional)</span>
            </label>

            <div
              class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors"
              phx-drop-target={@uploads.bike_photo.ref}
            >
              <%= if @uploads.bike_photo.entries == [] do %>
                <.icon name="hero-camera" class="size-8 text-base-content/30 mx-auto" />
                <p class="text-sm text-base-content/50 mt-2">
                  Drop a photo here or
                  <label
                    for={@uploads.bike_photo.ref}
                    class="text-primary cursor-pointer hover:underline"
                  >
                    browse
                  </label>
                </p>
                <p class="text-xs text-base-content/30 mt-1">JPG, PNG, or WebP up to 10 MB</p>
                <.live_file_input upload={@uploads.bike_photo} class="hidden" />
              <% else %>
                <%= for entry <- @uploads.bike_photo.entries do %>
                  <div class="flex items-center gap-3 min-w-0">
                    <.live_img_preview
                      entry={entry}
                      class="w-20 h-20 object-cover rounded-lg shrink-0"
                    />
                    <div class="flex-1 min-w-0 text-left">
                      <p class="text-sm font-medium truncate">{entry.client_name}</p>
                      <progress
                        value={entry.progress}
                        max="100"
                        class="progress progress-primary w-full"
                      />
                    </div>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="btn btn-ghost btn-xs btn-circle shrink-0"
                    >
                      <.icon name="hero-x-mark" class="size-4" />
                    </button>
                  </div>
                  <%= for err <- upload_errors(@uploads.bike_photo, entry) do %>
                    <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
                  <% end %>
                <% end %>
                <.live_file_input upload={@uploads.bike_photo} class="hidden" />
              <% end %>
            </div>

            <%= for err <- upload_errors(@uploads.bike_photo) do %>
              <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
            <% end %>
          </div>

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full mt-6">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: KoveWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)
    bikes = Bikes.list_bikes()

    bike_options =
      [{"None — I'm just looking", ""}] ++
        Enum.map(bikes, fn b -> {b.name, b.id} end)

    {:ok,
     socket
     |> assign(:bike_options, bike_options)
     |> allow_upload(:bike_photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign_form(changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Consume uploads only AFTER registration succeeds so they survive retries
        uploaded_results =
          consume_uploaded_entries(socket, :bike_photo, fn %{path: path}, entry ->
            key = Kove.Storage.generate_key(entry.client_name)

            case Kove.Storage.upload_file(path, key, content_type_for(entry)) do
              {:ok, url} ->
                {:ok, {url, key}}

              {:error, reason} ->
                require Logger
                Logger.error("R2 upload failed during registration: #{reason}")
                {:ok, nil}
            end
          end)

        upload_result = Enum.find(uploaded_results, &(not is_nil(&1)))

        # Create user_bike record if they selected a bike or uploaded a photo
        bike_id = user_params["bike_id"]

        if (bike_id && bike_id != "") || upload_result do
          {:ok, user_bike} = UserBikes.create_user_bike(user, %{"bike_id" => bike_id})

          # Save uploaded image to user_bike_images table
          if upload_result do
            {url, storage_key} = upload_result
            UserBikes.add_image(user_bike, url, storage_key)
          end
        end

        # Auto-login: generate magic link token and redirect to confirmation
        token = Accounts.generate_magic_link_token(user)

        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Kove Moto USA!")
         |> redirect(to: ~p"/users/log-in/#{token}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :bike_photo, ref)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp content_type_for(entry) do
    case entry.client_type do
      "" -> mime_from_ext(entry.client_name)
      nil -> mime_from_ext(entry.client_name)
      type -> type
    end
  end

  defp mime_from_ext(filename) do
    case filename |> Path.extname() |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      _ -> "image/jpeg"
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10 MB)"
  defp error_to_string(:too_many_files), do: "Only one photo allowed"
  defp error_to_string(:not_accepted), do: "Only .jpg, .png, and .webp files are accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
