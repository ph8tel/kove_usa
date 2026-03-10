defmodule KoveWeb.UserHomeLive do
  use KoveWeb, :live_view

  import KoveWeb.Live.ChatHandlers

  alias Kove.Bikes
  alias Kove.UserBikes
  alias Kove.KovyAssistant
  alias KoveWeb.ChatLive

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    user_bike = UserBikes.get_user_bike(user)
    bike = if user_bike, do: user_bike.bike, else: nil

    hero_slides = build_hero_slides(user_bike, bike)

    rate_limit_key =
      case get_connect_info(socket, :peer_data) do
        %{address: addr} -> {:ip, :inet.ntoa(addr) |> to_string()}
        _ -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, "My Garage")
     |> assign(:user, user)
     |> assign(:user_bike, user_bike)
     |> assign(:bike, bike)
     |> assign(:hero_slides, hero_slides)
     |> assign(:active_tab, :my_bike)
     |> assign(:rate_limit_key, rate_limit_key)
     |> assign(:chat_messages, [])
     |> assign(:chat_loading, false)
     |> assign(:chat_open, false)
     |> allow_upload(:bike_photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 pb-8">
        <%!-- Left Column: User content (wider) --%>
        <div class="lg:col-span-2">
          <%!-- Hero Slideshow --%>
          <div
            id="hero-carousel"
            phx-hook="Carousel"
            phx-update="ignore"
            class="mb-6 rounded-lg overflow-hidden bg-base-300 aspect-video relative group"
          >
            <%= if @hero_slides == [] do %>
              <div
                data-slide
                class="absolute inset-0 flex flex-col items-center justify-center text-base-content/30 transition-opacity duration-500"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="size-24"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0 0 22.5 18.75V5.25A2.25 2.25 0 0 0 20.25 3H3.75A2.25 2.25 0 0 0 1.5 5.25v13.5A2.25 2.25 0 0 0 3.75 21Z"
                  />
                </svg>
                <p class="mt-2 text-sm">No bike photos yet</p>
              </div>
            <% else %>
              <%= for {slide, _idx} <- Enum.with_index(@hero_slides) do %>
                <div
                  data-slide
                  class="absolute inset-0 transition-opacity duration-500 opacity-0"
                >
                  <img
                    src={slide.url}
                    alt={slide.label}
                    class="w-full h-full object-cover"
                  />
                  <div class="absolute bottom-8 left-4 bg-black/50 text-white text-xs px-2 py-1 rounded">
                    {slide.label}
                  </div>
                </div>
              <% end %>
            <% end %>

            <%!-- Prev / Next arrows (shown when 2+ slides) --%>
            <%= if length(@hero_slides) > 1 do %>
              <button
                data-prev
                class="absolute left-2 top-1/2 -translate-y-1/2 btn btn-circle btn-sm btn-ghost bg-black/30 text-white opacity-0 group-hover:opacity-100 transition-opacity z-10"
              >
                <.icon name="hero-chevron-left" class="size-5" />
              </button>
              <button
                data-next
                class="absolute right-2 top-1/2 -translate-y-1/2 btn btn-circle btn-sm btn-ghost bg-black/30 text-white opacity-0 group-hover:opacity-100 transition-opacity z-10"
              >
                <.icon name="hero-chevron-right" class="size-5" />
              </button>

              <%!-- Dot indicators --%>
              <div class="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1.5 z-10">
                <%= for {_slide, idx} <- Enum.with_index(@hero_slides) do %>
                  <button
                    data-dot
                    class={[
                      "size-2.5 rounded-full transition-colors",
                      if(idx == 0, do: "bg-primary", else: "bg-white/50")
                    ]}
                  >
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- User Header Info --%>
          <div class="mb-6">
            <div class="flex items-start justify-between gap-4 mb-2">
              <div>
                <h1 class="text-4xl font-black mb-1">My Garage</h1>
                <p class="text-lg text-base-content/60">
                  {user_greeting(@user, @bike)}
                </p>
              </div>
              <%= if @bike do %>
                <div class="text-right">
                  <p class="text-xl font-extrabold text-primary">{@bike.name}</p>
                  <p class="text-sm text-base-content/60">
                    {Bikes.category_label(@bike.category)} • {@bike.year}
                  </p>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Navigation Tabs --%>
          <div class="tabs tabs-bordered mb-6 gap-2">
            <button
              phx-click="set_tab"
              phx-value-tab="my_bike"
              class={["tab", @active_tab == :my_bike && "tab-active"]}
            >
              <.icon name="hero-truck" class="size-5" />
              <span class="hidden sm:inline ml-2">My Bike</span>
            </button>
            <button
              phx-click="set_tab"
              phx-value-tab="photos"
              class={["tab", @active_tab == :photos && "tab-active"]}
            >
              <.icon name="hero-camera" class="size-5" />
              <span class="hidden sm:inline ml-2">Photos</span>
            </button>
            <button
              phx-click="set_tab"
              phx-value-tab="maintenance"
              class={["tab", @active_tab == :maintenance && "tab-active"]}
            >
              <.icon name="hero-wrench-screwdriver" class="size-5" />
              <span class="hidden sm:inline ml-2">Maintenance</span>
            </button>
            <button
              phx-click="set_tab"
              phx-value-tab="orders"
              class={["tab", @active_tab == :orders && "tab-active"]}
            >
              <.icon name="hero-shopping-bag" class="size-5" />
              <span class="hidden sm:inline ml-2">Orders</span>
            </button>
          </div>

          <%!-- Content Area --%>
          <div class="bg-base-200 rounded-lg p-6 min-h-64">
            <%!-- My Bike Tab --%>
            <div :if={@active_tab == :my_bike}>
              <%= if @bike do %>
                <.bike_details_section bike={@bike} user_bike={@user_bike} />
              <% else %>
                <.no_bike_section />
              <% end %>
            </div>

            <%!-- Photos Tab --%>
            <div :if={@active_tab == :photos}>
              <.photos_section uploads={@uploads} user_bike={@user_bike} />
            </div>

            <%!-- Maintenance Tab --%>
            <div :if={@active_tab == :maintenance}>
              <.maintenance_section bike={@bike} />
            </div>

            <%!-- Orders Tab --%>
            <div :if={@active_tab == :orders}>
              <.orders_section />
            </div>
          </div>
        </div>

        <%!-- Right Column: Chat --%>
        <div class="lg:col-span-1">
          <.live_component
            module={ChatLive}
            id="kovy-chat"
            chat_messages={@chat_messages}
            chat_loading={@chat_loading}
            chat_open={@chat_open}
            context_label={if @bike, do: "your #{@bike.name}", else: "Kove bikes"}
            placeholder={
              if @bike, do: "Ask about your #{@bike.name}...", else: "Ask about any Kove bike..."
            }
            quick_asks={quick_asks(@bike)}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Sub-components ──

  attr :bike, :map, required: true
  attr :user_bike, :map, required: true

  defp bike_details_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <h3 class="text-lg font-bold">Bike Specs</h3>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="stat bg-base-100 rounded-lg">
          <div class="stat-title">Model</div>
          <div class="stat-value text-lg">{@bike.name}</div>
        </div>
        <div class="stat bg-base-100 rounded-lg">
          <div class="stat-title">Year</div>
          <div class="stat-value text-lg">{@bike.year}</div>
        </div>
        <div class="stat bg-base-100 rounded-lg">
          <div class="stat-title">Category</div>
          <div class="stat-value text-lg">{Kove.Bikes.category_label(@bike.category)}</div>
        </div>
        <div :if={@bike.engine} class="stat bg-base-100 rounded-lg">
          <div class="stat-title">Engine</div>
          <div class="stat-value text-lg">{@bike.engine.displacement} {@bike.engine.engine_type}</div>
        </div>
        <div class="stat bg-base-100 rounded-lg">
          <div class="stat-title">MSRP</div>
          <div class="stat-value text-lg text-primary">
            {Kove.Bikes.format_msrp(@bike.msrp_cents)}
          </div>
        </div>
        <div class="stat bg-base-100 rounded-lg">
          <div class="stat-title">Status</div>
          <div class="stat-value text-lg">{Kove.Bikes.status_label(@bike.status)}</div>
        </div>
      </div>

      <div class="divider"></div>

      <div class="flex items-center gap-4">
        <.link navigate={~p"/bikes/#{@bike.slug}"} class="btn btn-primary btn-sm">
          <.icon name="hero-arrow-right" class="size-4" /> View Full Details
        </.link>
      </div>
    </div>
    """
  end

  defp no_bike_section(assigns) do
    ~H"""
    <div class="text-center py-8 space-y-4">
      <.icon name="hero-truck" class="size-16 text-base-content/20 mx-auto" />
      <h3 class="text-lg font-bold text-base-content/60">No bike selected yet</h3>
      <p class="text-base-content/50 max-w-md mx-auto">
        Browse our lineup and find your perfect Kove. You can update your bike selection in settings anytime.
      </p>
      <.link navigate={~p"/"} class="btn btn-primary btn-sm">
        <.icon name="hero-magnifying-glass" class="size-4" /> Browse Bikes
      </.link>
    </div>
    """
  end

  attr :bike, :map, default: nil

  defp maintenance_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-bold">Maintenance Schedule</h3>

      <%= if @bike do %>
        <div class="alert alert-info">
          <.icon name="hero-information-circle" class="size-5" />
          <span>
            Maintenance tracking is coming soon! Ask Kovy about maintenance tips for your {@bike.name} in the meantime.
          </span>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="card bg-base-100 p-4">
            <div class="flex items-center gap-3">
              <div class="size-10 rounded-full bg-warning/20 flex items-center justify-center">
                <.icon name="hero-wrench" class="size-5 text-warning" />
              </div>
              <div>
                <p class="font-semibold">Oil Change</p>
                <p class="text-sm text-base-content/60">Every 3,000 km</p>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 p-4">
            <div class="flex items-center gap-3">
              <div class="size-10 rounded-full bg-error/20 flex items-center justify-center">
                <.icon name="hero-fire" class="size-5 text-error" />
              </div>
              <div>
                <p class="font-semibold">Air Filter</p>
                <p class="text-sm text-base-content/60">Every 6,000 km</p>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 p-4">
            <div class="flex items-center gap-3">
              <div class="size-10 rounded-full bg-success/20 flex items-center justify-center">
                <.icon name="hero-cog-6-tooth" class="size-5 text-success" />
              </div>
              <div>
                <p class="font-semibold">Chain & Sprockets</p>
                <p class="text-sm text-base-content/60">Every 10,000 km</p>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 p-4">
            <div class="flex items-center gap-3">
              <div class="size-10 rounded-full bg-info/20 flex items-center justify-center">
                <.icon name="hero-shield-check" class="size-5 text-info" />
              </div>
              <div>
                <p class="font-semibold">Valve Clearance</p>
                <p class="text-sm text-base-content/60">Every 12,000 km</p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="text-center py-8">
          <p class="text-base-content/50">Select a bike to see maintenance schedules.</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp orders_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-bold">My Orders</h3>
      <div class="text-center py-8 space-y-4">
        <.icon name="hero-shopping-bag" class="size-16 text-base-content/20 mx-auto" />
        <p class="text-base-content/50">No orders yet. Check back soon!</p>
      </div>
    </div>
    """
  end

  attr :uploads, :any, required: true
  attr :user_bike, :map, default: nil

  defp photos_section(assigns) do
    images =
      case assigns.user_bike do
        %{images: imgs} when is_list(imgs) -> imgs
        _ -> []
      end

    assigns = assign(assigns, :images, images)

    ~H"""
    <div class="space-y-6">
      <h3 class="text-lg font-bold">My Photos</h3>

      <%!-- Upload form --%>
      <form id="photo-upload-form" phx-submit="save-photo" phx-change="validate-photo">
        <div
          class="border-2 border-dashed border-base-300 rounded-lg p-6 text-center hover:border-primary transition-colors"
          phx-drop-target={@uploads.bike_photo.ref}
        >
          <%= if @uploads.bike_photo.entries == [] do %>
            <.icon name="hero-camera" class="size-10 text-base-content/30 mx-auto" />
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
              <div class="flex items-center gap-4">
                <.live_img_preview
                  entry={entry}
                  class="w-24 h-24 object-cover rounded-lg shrink-0"
                />
                <div class="flex-1 min-w-0 text-left">
                  <p class="text-sm font-medium truncate">{entry.client_name}</p>
                  <p class="text-xs text-base-content/50">
                    {Float.round(entry.client_size / 1_000_000, 1)} MB
                  </p>
                  <%= if entry.progress > 0 do %>
                    <progress
                      value={entry.progress}
                      max="100"
                      class="progress progress-primary w-full mt-1"
                    />
                  <% end %>
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

            <button type="submit" class="btn btn-primary btn-sm mt-4">
              <.icon name="hero-cloud-arrow-up" class="size-4" />
              Upload Photo
            </button>
          <% end %>
        </div>

        <%= for err <- upload_errors(@uploads.bike_photo) do %>
          <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
        <% end %>
      </form>

      <%!-- Photo gallery --%>
      <%= if @images != [] do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <%= for image <- @images do %>
            <div class="relative group/photo rounded-lg overflow-hidden aspect-video bg-base-300">
              <img
                src={image.url}
                alt="My bike"
                class="w-full h-full object-cover"
              />
              <button
                phx-click="delete-photo"
                phx-value-id={image.id}
                data-confirm="Delete this photo?"
                class="absolute top-2 right-2 btn btn-circle btn-xs btn-error opacity-0 group-hover/photo:opacity-100 transition-opacity"
              >
                <.icon name="hero-trash" class="size-3" />
              </button>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-4">
          <p class="text-base-content/50 text-sm">
            No photos uploaded yet. Add one above!
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Helpers ──

  defp build_hero_slides(user_bike, bike) do
    # User-uploaded images (from user_bike_images table)
    user_images =
      case user_bike do
        %{images: images} when is_list(images) ->
          Enum.map(images, fn img -> %{url: img.url, label: "My bike"} end)

        _ ->
          []
      end

    # Catalog hero image for the selected bike model
    catalog_slide =
      if bike do
        case Bikes.hero_image_url(bike) do
          nil -> []
          url -> [%{url: url, label: "#{bike.name} — Catalog"}]
        end
      else
        []
      end

    # User photos first, then catalog hero
    user_images ++ catalog_slide
  end

  defp user_greeting(user, bike) do
    email_name = user.email |> String.split("@") |> List.first()

    if bike do
      "Welcome back, #{email_name}"
    else
      "Welcome, #{email_name}"
    end
  end

  defp quick_asks(nil) do
    [
      %{label: "Best for beginners?", message: "Which Kove bike is best for a beginner?"},
      %{label: "Compare models", message: "Compare the Kove models"},
      %{label: "Off-road pick?", message: "What's the best Kove for off-road riding?"}
    ]
  end

  defp quick_asks(bike) do
    [
      %{label: "Maintenance?", message: "What maintenance does my #{bike.name} need?"},
      %{label: "Upgrades?", message: "What upgrades do riders make to the #{bike.name}?"},
      %{label: "vs KTM?", message: "How does the #{bike.name} compare to a KTM?"}
    ]
  end

  # ── Tab switching ──

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :bike_photo, ref)}
  end

  def handle_event("delete-photo", %{"id" => id}, socket) do
    case UserBikes.delete_image(id) do
      {:ok, _image} ->
        user_bike = UserBikes.get_user_bike(socket.assigns.user)
        hero_slides = build_hero_slides(user_bike, socket.assigns.bike)

        {:noreply,
         socket
         |> assign(:user_bike, user_bike)
         |> assign(:hero_slides, hero_slides)
         |> push_event("update-slides", %{slides: hero_slides})
         |> put_flash(:info, "Photo deleted.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete photo.")}
    end
  end

  def handle_event("validate-photo", _params, socket) do
    {:noreply, socket}
  end

  # ── Photo upload (form-based, matches registration pattern) ──

  def handle_event("save-photo", _params, socket) do
    results =
      consume_uploaded_entries(socket, :bike_photo, fn %{path: path}, entry ->
        key = Kove.Storage.generate_key(entry.client_name)

        case Kove.Storage.upload_file(path, key, content_type_for(entry)) do
          {:ok, url} ->
            {:ok, {url, key}}

          {:error, reason} ->
            require Logger
            Logger.error("R2 upload failed from home page: #{reason}")
            {:ok, nil}
        end
      end)

    result = List.first(results)

    if result do
      {url, storage_key} = result
      user = socket.assigns.user

      # Ensure user_bike exists
      user_bike =
        case socket.assigns.user_bike do
          nil ->
            {:ok, ub} = UserBikes.create_user_bike(user, %{})
            ub

          ub ->
            ub
        end

      # Add image to the images table
      {:ok, _image} = UserBikes.add_image(user_bike, url, storage_key)

      # Reload user_bike with all images
      user_bike = UserBikes.get_user_bike(user)
      bike = socket.assigns.bike
      hero_slides = build_hero_slides(user_bike, bike)

      {:noreply,
       socket
       |> assign(:user_bike, user_bike)
       |> assign(:hero_slides, hero_slides)
       |> push_event("update-slides", %{slides: hero_slides})
       |> put_flash(:info, "Photo uploaded!")}
    else
      {:noreply, put_flash(socket, :error, "Photo upload failed. Please try again.")}
    end
  end

  # ── Chat callbacks from ChatLive component ──

  @impl true
  def handle_info({:chat_send, message}, socket) do
    if socket.assigns.chat_loading do
      {:noreply, socket}
    else
      user_msg = %{role: :user, content: message}
      assistant_msg = %{role: :assistant, content: "", streaming: true}
      history = socket.assigns.chat_messages ++ [user_msg]
      context = %{tier: :public, rate_limit_key: socket.assigns.rate_limit_key}

      if socket.assigns.bike do
        KovyAssistant.send_message(socket.assigns.bike, history, self(), context)
      else
        bikes_full = Bikes.list_bikes_full()
        KovyAssistant.send_catalog_message(bikes_full, history, self(), context)
      end

      {:noreply,
       socket
       |> assign(:chat_messages, history ++ [assistant_msg])
       |> assign(:chat_loading, true)
       |> assign(:chat_open, true)}
    end
  end

  @impl true
  def handle_info({:chat_retry, _message}, socket) do
    if socket.assigns.chat_loading do
      {:noreply, socket}
    else
      history = List.delete_at(socket.assigns.chat_messages, -1)
      assistant_msg = %{role: :assistant, content: "", streaming: true}
      context = %{tier: :public, rate_limit_key: socket.assigns.rate_limit_key}

      if socket.assigns.bike do
        KovyAssistant.send_message(socket.assigns.bike, history, self(), context)
      else
        bikes_full = Bikes.list_bikes_full()
        KovyAssistant.send_catalog_message(bikes_full, history, self(), context)
      end

      {:noreply,
       socket
       |> assign(:chat_messages, history ++ [assistant_msg])
       |> assign(:chat_loading, true)}
    end
  end

  @impl true
  def handle_info(:chat_toggle, socket), do: handle_chat_toggle(socket)

  @impl true
  def handle_info({:kovy_chunk, text}, socket), do: handle_kovy_chunk(socket, text)

  @impl true
  def handle_info({:kovy_done}, socket), do: handle_kovy_done(socket)

  @impl true
  def handle_info({:kovy_error, error_type, reason}, socket),
    do: handle_kovy_error(socket, error_type, reason)

  @impl true
  def handle_info({:kovy_error, reason}, socket) when is_binary(reason),
    do: handle_kovy_error(socket, reason)

  # ── Upload helpers ──

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
