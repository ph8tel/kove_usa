defmodule KoveWeb.RiderPageLive do
  use KoveWeb, :live_view

  alias Kove.Accounts
  alias Kove.UserBikes
  alias Kove.Bikes

  @impl true
  def mount(%{"handle" => handle}, _session, socket) do
    case Accounts.get_user_by_handle(handle) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Rider page not found.")
         |> push_navigate(to: ~p"/")}

      user ->
        user_bike = UserBikes.get_user_bike(user)
        bike = if user_bike, do: user_bike.bike, else: nil

        # Build photo slides: rider photos first, then fall back to official hero image
        photos = if user_bike, do: user_bike.images, else: []

        og_images =
          cond do
            photos != [] -> Enum.map(photos, & &1.url)
            bike != nil -> [Bikes.hero_image_url(bike)]
            true -> []
          end

        bike_name = if bike, do: bike.name, else: nil

        og_title =
          cond do
            user_bike && bike_name ->
              "#{handle}'s #{bike_name} — Kove Moto USA"

            user_bike ->
              "#{handle}'s Garage — Kove Moto USA"

            true ->
              "#{handle} — Kove Moto USA"
          end

        og_description =
          cond do
            user_bike && bike_name && user_bike.mods != [] ->
              mod_count = length(user_bike.mods)

              "Check out #{handle}'s #{bike_name} build with #{mod_count} mod#{if mod_count == 1, do: "", else: "s"}."

            user_bike && bike_name ->
              "Check out #{handle}'s #{bike_name} on Kove Moto USA."

            true ->
              "Rider page for #{handle} on Kove Moto USA."
          end

        {:ok,
         socket
         |> assign(:page_title, og_title)
         |> assign(:og_title, og_title)
         |> assign(:og_description, og_description)
         |> assign(:og_images, og_images)
         |> assign(:og_url, url(~p"/@#{handle}"))
         |> assign(:handle, handle)
         |> assign(:user, user)
         |> assign(:user_bike, user_bike)
         |> assign(:bike, bike)
         |> assign(:photos, photos)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto pb-16">
        <%!-- Hero photo carousel --%>
        <div class="rounded-xl overflow-hidden bg-base-300 aspect-video relative mb-6">
          <%= if @photos == [] do %>
            <%= if @bike do %>
              <img
                src={Bikes.hero_image_url(@bike)}
                alt={@bike.name}
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="absolute inset-0 flex flex-col items-center justify-center text-base-content/30">
                <.icon name="hero-photo" class="size-24" />
                <p class="mt-2 text-sm">No photos yet</p>
              </div>
            <% end %>
          <% else %>
            <%!-- Simple static photo display — first photo as hero, thumbnails below --%>
            <img
              src={List.first(@photos).url}
              alt={"#{@handle}'s bike"}
              class="w-full h-full object-cover"
            />
          <% end %>
        </div>

        <%!-- Thumbnail strip (if 2+ photos) --%>
        <%= if length(@photos) > 1 do %>
          <div class="flex gap-2 mb-6 overflow-x-auto pb-1">
            <%= for photo <- @photos do %>
              <img
                src={photo.url}
                alt="Bike photo"
                class="h-16 w-24 object-cover rounded-lg flex-shrink-0 ring-1 ring-base-300"
              />
            <% end %>
          </div>
        <% end %>

        <%!-- Rider identity + share button --%>
        <div class="flex items-start justify-between gap-4 mb-6">
          <div>
            <h1 class="text-3xl font-bold">@{@handle}</h1>
            <%= if @bike do %>
              <p class="text-lg text-base-content/70 mt-1">{@bike.name}</p>
            <% else %>
              <p class="text-base-content/50 mt-1 italic">No bike registered yet</p>
            <% end %>
            <%= if @user_bike && @user_bike.nickname do %>
              <p class="text-sm text-base-content/50 mt-0.5">"{@user_bike.nickname}"</p>
            <% end %>
          </div>

          <%!-- Share button --%>
          <button
            id="share-btn"
            phx-hook="SharePage"
            data-share-title={@og_title}
            data-share-text={@og_description}
            data-share-url={@og_url}
            class="btn btn-outline btn-sm gap-2 flex-shrink-0"
          >
            <.icon name="hero-share" class="size-4" /> Share
          </button>
        </div>

        <%!-- Bike specs summary --%>
        <%= if @bike do %>
          <div class="card bg-base-200 mb-6">
            <div class="card-body py-4">
              <h2 class="card-title text-base">Bike Details</h2>
              <div class="grid grid-cols-2 gap-x-8 gap-y-1 text-sm">
                <%= if @bike.engine do %>
                  <div class="text-base-content/60">Engine</div>
                  <div>{@bike.engine.displacement} {@bike.engine.engine_type}</div>
                  <div class="text-base-content/60">Power</div>
                  <div>{@bike.engine.max_power}</div>
                  <%= if @bike.engine.max_torque do %>
                    <div class="text-base-content/60">Torque</div>
                    <div>{@bike.engine.max_torque}</div>
                  <% end %>
                <% end %>
                <%= if @bike.msrp_cents do %>
                  <div class="text-base-content/60">MSRP</div>
                  <div>{Bikes.format_msrp(@bike.msrp_cents)}</div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Mods list --%>
        <%= if @user_bike && @user_bike.mods != [] do %>
          <h2 class="text-xl font-semibold mb-3">Mods ({length(@user_bike.mods)})</h2>
          <div class="flex flex-col gap-3">
            <%= for mod <- @user_bike.mods do %>
              <div class="card bg-base-200">
                <div class="card-body py-3 px-4">
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <div class="flex items-center gap-2 flex-wrap">
                        <span class="badge badge-primary badge-sm capitalize">
                          {mod.mod_type}
                        </span>
                        <%= if mod.brand do %>
                          <span class="text-sm font-medium">{mod.brand}</span>
                        <% end %>
                      </div>
                      <p class="text-sm text-base-content/80 mt-1">{mod.description}</p>
                      <%= if mod.installed_at do %>
                        <p class="text-xs text-base-content/40 mt-0.5">
                          Installed {Calendar.strftime(mod.installed_at, "%B %Y")}
                        </p>
                      <% end %>
                    </div>
                    <%!-- Star rating --%>
                    <%= if mod.rating do %>
                      <div class="flex gap-0.5 flex-shrink-0 mt-0.5">
                        <%= for i <- 1..5 do %>
                          <%= if i <= mod.rating do %>
                            <.icon name="hero-star-solid" class="size-4 text-warning" />
                          <% else %>
                            <.icon name="hero-star-solid" class="size-4 text-base-content/20" />
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Empty state when user has no garage --%>
        <%= if is_nil(@user_bike) do %>
          <div class="text-center py-12 text-base-content/40">
            <.icon name="hero-wrench-screwdriver" class="size-16 mx-auto mb-3" />
            <p>This rider hasn't set up their garage yet.</p>
          </div>
        <% end %>

        <%!-- Footer CTA --%>
        <div class="mt-10 text-center border-t border-base-300 pt-8">
          <p class="text-sm text-base-content/50 mb-3">Kove rider? Build your own page.</p>
          <.link navigate={~p"/"} class="btn btn-primary btn-sm">Explore Kove Moto USA</.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
