defmodule KoveWeb.UserHomeLive do
  use KoveWeb, :live_view

  import KoveWeb.Live.ChatHandlers

  alias Kove.Bikes
  alias Kove.UserBikes
  alias Kove.UserBikes.UserBikeMod
  alias Kove.Parts
  alias Kove.Orders
  alias Kove.KovyAssistant
  alias KoveWeb.ChatLive

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    user_bike = UserBikes.get_user_bike(user)
    bike = if user_bike, do: user_bike.bike, else: nil

    hero_slides = build_hero_slides(user_bike, bike)

    oil_change_kit = if bike, do: Parts.oil_change_kit_for_bike(bike), else: nil
    cart_count = Orders.cart_item_count(user)
    user_orders = Orders.list_user_orders(user)
    cart = Orders.get_cart(user)

    bike_options = Bikes.list_bikes() |> Enum.map(fn b -> {b.name, b.id} end)

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
     |> assign(:active_tab, :my_mods)
     |> assign(:oil_change_kit, oil_change_kit)
     |> assign(:cart_count, cart_count)
     |> assign(:cart, cart)
     |> assign(:user_orders, user_orders)
     |> assign(:bike_options, bike_options)
     |> assign(:mod_form, to_form(UserBikes.change_mod(%UserBikeMod{}), as: :mod))
     |> assign(:mod_rating, nil)
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
              phx-value-tab="my_mods"
              class={["tab", @active_tab == :my_mods && "tab-active"]}
            >
              <.icon name="hero-wrench" class="size-5" />
              <span class="hidden sm:inline ml-2">My Mods</span>
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
              <span
                :if={@cart_count > 0}
                id="cart-badge"
                class="badge badge-primary badge-xs ml-1"
              >
                {@cart_count}
              </span>
            </button>
          </div>

          <%!-- Content Area --%>
          <div class="bg-base-200 rounded-lg p-6 min-h-64">
            <%!-- My Mods Tab --%>
            <div :if={@active_tab == :my_mods}>
              <%= if @bike do %>
                <.mods_section user_bike={@user_bike} mod_form={@mod_form} mod_rating={@mod_rating} />
              <% else %>
                <.no_bike_section bike_options={@bike_options} />
              <% end %>
            </div>

            <%!-- Photos Tab --%>
            <div :if={@active_tab == :photos}>
              <.photos_section uploads={@uploads} user_bike={@user_bike} />
            </div>

            <%!-- Maintenance Tab --%>
            <div :if={@active_tab == :maintenance}>
              <.maintenance_section bike={@bike} oil_change_kit={@oil_change_kit} />
            </div>

            <%!-- Orders Tab --%>
            <div :if={@active_tab == :orders}>
              <.orders_section cart={@cart} user_orders={@user_orders} />
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
            quick_asks={quick_asks_with_orders(@bike, @user_orders)}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Sub-components ──

  attr :user_bike, :map, required: true
  attr :mod_form, :map, required: true
  attr :mod_rating, :integer, default: nil

  defp mods_section(assigns) do
    mods =
      case assigns.user_bike do
        %{mods: mods} when is_list(mods) -> mods
        _ -> []
      end

    assigns = assign(assigns, :mods, mods)

    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-bold">My Mods</h3>
        <.link navigate={~p"/bikes/#{@user_bike.bike.slug}"} class="btn btn-ghost btn-xs">
          <.icon name="hero-arrow-right" class="size-4" /> View Full Specs
        </.link>
      </div>

      <%!-- Add Mod Form --%>
      <.form
        for={@mod_form}
        id="mod-form"
        phx-submit="save-mod"
        phx-change="validate-mod"
        class="card bg-base-100 p-4"
      >
        <h4 class="font-semibold mb-3">Add a Mod</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <.input
            field={@mod_form[:mod_type]}
            type="select"
            label="Type *"
            prompt="Select type..."
            options={Enum.map(UserBikeMod.mod_types(), &{UserBikeMod.mod_type_label(&1), &1})}
          />
          <.input
            field={@mod_form[:brand]}
            type="text"
            label="Brand"
            placeholder="e.g. Akrapovič, Rekluse"
          />
        </div>

        <div class="mt-3">
          <.input
            field={@mod_form[:description]}
            type="textarea"
            label="Description *"
            placeholder="What did you change and why?"
          />
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mt-3">
          <div>
            <label class="label mb-1">Cost ($)</label>
            <input
              type="number"
              name="mod[cost_dollars]"
              id="mod_cost_dollars"
              value={Phoenix.HTML.Form.input_value(@mod_form, :cost_dollars)}
              placeholder="e.g. 899.00"
              step="0.01"
              min="0"
              class="input w-full"
            />
          </div>
          <.input field={@mod_form[:installed_at]} type="date" label="Installed" />
          <div>
            <label class="label mb-1">Rating</label>
            <input type="hidden" name="mod[rating]" value={@mod_rating || ""} />
            <div class="flex items-center gap-1 mt-1">
              <%= for star <- 1..5 do %>
                <button
                  type="button"
                  phx-click="set-mod-rating"
                  phx-value-rating={star}
                  class={[
                    "text-2xl cursor-pointer transition-colors hover:scale-110",
                    if(@mod_rating && star <= @mod_rating,
                      do: "text-warning",
                      else: "text-base-content/20"
                    )
                  ]}
                >
                  ★
                </button>
              <% end %>
              <%= if @mod_rating do %>
                <button
                  type="button"
                  phx-click="set-mod-rating"
                  phx-value-rating="0"
                  class="btn btn-ghost btn-xs ml-1"
                >
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-4">
          <button type="submit" class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> Add Mod
          </button>
        </div>
      </.form>

      <%!-- Mods List --%>
      <%= if @mods != [] do %>
        <div class="space-y-3">
          <%= for mod <- @mods do %>
            <div id={"mod-#{mod.id}"} class="card bg-base-100 p-4">
              <div class="flex items-start justify-between gap-3">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="badge badge-primary badge-sm">
                      {UserBikeMod.mod_type_label(mod.mod_type)}
                    </span>
                    <%= if mod.brand do %>
                      <span class="badge badge-ghost badge-sm">{mod.brand}</span>
                    <% end %>
                    <%= if mod.rating do %>
                      <span class="text-warning text-sm">
                        {String.duplicate("★", mod.rating)}{String.duplicate("☆", 5 - mod.rating)}
                      </span>
                    <% end %>
                  </div>
                  <p class="mt-1 text-sm">{mod.description}</p>
                  <div class="flex items-center gap-3 mt-2 text-xs text-base-content/50">
                    <%= if mod.cost_cents do %>
                      <span>{"$#{:erlang.float_to_binary(mod.cost_cents / 100, decimals: 2)}"}</span>
                    <% end %>
                    <%= if mod.installed_at do %>
                      <span>Installed {Calendar.strftime(mod.installed_at, "%b %d, %Y")}</span>
                    <% end %>
                  </div>
                </div>
                <button
                  phx-click="delete-mod"
                  phx-value-id={mod.id}
                  data-confirm="Remove this mod?"
                  class="btn btn-ghost btn-xs btn-circle shrink-0"
                >
                  <.icon name="hero-trash" class="size-4 text-error" />
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-4">
          <p class="text-base-content/50 text-sm">
            No mods yet — add your first modification above!
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :bike_options, :list, required: true

  defp no_bike_section(assigns) do
    ~H"""
    <div class="text-center py-8 space-y-6 max-w-sm mx-auto">
      <svg
        class="size-16 mx-auto text-base-content/20"
        viewBox="0 0 24 24"
        fill="currentColor"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <path d="M19.44 9.03L15.41 5H11v2h3.59l2 2H5C2.2 9 0 11.2 0 14s2.2 5 5 5c2.42 0 4.44-1.72 4.9-4h2.2c.46 2.28 2.48 4 4.9 4 2.8 0 5-2.2 5-5 0-3.08-1.22-4.53-2.56-4.97zM7.82 15C7.4 16.15 6.28 17 5 17c-1.65 0-3-1.35-3-3s1.35-3 3-3c1.28 0 2.4.85 2.82 2H7.82zm4.09-2H9.93C9.43 11.28 7.86 10 6 10h-.45L7.95 7H11v2h2L11.91 13zM17 17c-1.65 0-3-1.35-3-3s1.35-3 3-3 3 1.35 3 3-1.35 3-3 3z" />
      </svg>

      <div>
        <h3 class="text-lg font-bold text-base-content/60">No bike selected yet</h3>
        <p class="text-base-content/50 text-sm mt-1">
          Choose your Kove to start tracking mods and maintenance.
        </p>
      </div>

      <form id="select-bike-form" phx-submit="select-bike" class="space-y-3 text-left">
        <select
          id="select-bike-dropdown"
          name="bike_id"
          class="select select-bordered w-full"
          required
        >
          <option value="">Select your bike…</option>
          <%= for {name, id} <- @bike_options do %>
            <option value={id}>{name}</option>
          <% end %>
        </select>
        <button type="submit" id="select-bike-submit" class="btn btn-primary w-full">
          <.icon name="hero-check" class="size-4" /> Set My Bike
        </button>
      </form>

      <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
        <.icon name="hero-magnifying-glass" class="size-4" /> Browse All Bikes
      </.link>
    </div>
    """
  end

  attr :bike, :map, default: nil
  attr :oil_change_kit, :map, default: nil

  defp maintenance_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-bold">Maintenance Schedule</h3>

      <%= if @bike do %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%!-- Oil Change Kit — live card with "Add to Cart" --%>
          <div id="oil-change-card" class="card bg-base-100 p-4">
            <div class="flex items-center gap-3">
              <div class="size-10 rounded-full bg-warning/20 flex items-center justify-center">
                <.icon name="hero-wrench" class="size-5 text-warning" />
              </div>
              <div class="flex-1">
                <p class="font-semibold">Oil Change</p>
                <p class="text-sm text-base-content/60">Every 3,000 km</p>
              </div>
            </div>
            <%= if @oil_change_kit do %>
              <div class="mt-3 flex items-center justify-between">
                <div>
                  <p class="text-xs text-base-content/60">{@oil_change_kit.name}</p>
                  <p class="font-bold text-primary">
                    {Kove.Currency.format(@oil_change_kit.price_cents)}
                  </p>
                </div>
                <button
                  id="add-oil-change-kit"
                  phx-click="add-to-cart"
                  phx-value-kit-id={@oil_change_kit.id}
                  class="btn btn-primary btn-sm"
                >
                  <.icon name="hero-shopping-cart" class="size-4" /> Add to Cart
                </button>
              </div>
            <% else %>
              <p class="mt-3 text-xs text-base-content/50">Kit coming soon for your engine.</p>
            <% end %>
          </div>

          <%!-- Air Filter — static placeholder --%>
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
            <p class="mt-3 text-xs text-base-content/50">Kit coming soon.</p>
          </div>

          <%!-- Chain & Sprockets — static placeholder --%>
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
            <p class="mt-3 text-xs text-base-content/50">Kit coming soon.</p>
          </div>

          <%!-- Valve Clearance — static placeholder --%>
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
            <p class="mt-3 text-xs text-base-content/50">Kit coming soon.</p>
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

  attr :cart, :map, default: nil
  attr :user_orders, :list, default: []

  defp orders_section(assigns) do
    cart_items =
      case assigns.cart do
        %{items: items} when is_list(items) -> items
        _ -> []
      end

    cart_total =
      Enum.reduce(cart_items, 0, fn item, acc ->
        acc + item.unit_price_cents * item.quantity
      end)

    assigns =
      assigns
      |> assign(:cart_items, cart_items)
      |> assign(:cart_total, cart_total)

    ~H"""
    <div class="space-y-6">
      <h3 class="text-lg font-bold">My Orders</h3>

      <%!-- Active Cart --%>
      <%= if @cart_items != [] do %>
        <div id="cart-section" class="card bg-base-100 p-4 space-y-3">
          <div class="flex items-center gap-2 mb-2">
            <.icon name="hero-shopping-cart" class="size-5 text-primary" />
            <span class="font-semibold">Shopping Cart</span>
          </div>

          <div class="divide-y divide-base-300">
            <%= for item <- @cart_items do %>
              <div id={"cart-item-#{item.id}"} class="flex items-center justify-between py-2">
                <div class="flex-1">
                  <p class="font-medium">{item.name_snapshot}</p>
                  <p class="text-sm text-base-content/60">
                    Qty: {item.quantity} × {Kove.Currency.format(item.unit_price_cents)}
                  </p>
                </div>
                <div class="flex items-center gap-3">
                  <span class="font-bold">
                    {Kove.Currency.format(item.unit_price_cents * item.quantity)}
                  </span>
                  <button
                    phx-click="remove-cart-item"
                    phx-value-item-id={item.id}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <div class="flex items-center justify-between pt-3 border-t border-base-300">
            <span class="font-bold text-lg">Total: {Kove.Currency.format(@cart_total)}</span>
            <button id="place-order-btn" phx-click="place-order" class="btn btn-primary btn-sm">
              <.icon name="hero-check" class="size-4" /> Place Order
            </button>
          </div>
        </div>
      <% end %>

      <%!-- Past Orders --%>
      <%= if @user_orders != [] do %>
        <div class="space-y-3">
          <%= for order <- @user_orders do %>
            <div id={"order-#{order.id}"} class="card bg-base-100 p-4">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <span class="font-semibold">Order #{order.id}</span>
                  <span class={[
                    "badge badge-sm",
                    order_status_badge_class(order.status)
                  ]}>
                    {String.capitalize(order.status)}
                  </span>
                </div>
                <span class="text-xs text-base-content/60">
                  {format_order_date(order.confirmed_at)}
                </span>
              </div>
              <div class="space-y-1">
                <%= for item <- order.items do %>
                  <div class="flex justify-between text-sm">
                    <span>{item.name_snapshot} × {item.quantity}</span>
                    <span>{Kove.Currency.format(item.unit_price_cents * item.quantity)}</span>
                  </div>
                <% end %>
              </div>
              <div class="flex justify-end pt-2 border-t border-base-300 mt-2">
                <span class="font-bold">
                  {Kove.Currency.format(Kove.Orders.order_total_cents(order))}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <%= if @cart_items == [] do %>
          <div class="text-center py-8 space-y-4">
            <.icon name="hero-shopping-bag" class="size-16 text-base-content/20 mx-auto" />
            <p class="text-base-content/50">
              No orders yet. Check the Maintenance tab to browse available kits!
            </p>
          </div>
        <% end %>
      <% end %>
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
              <.icon name="hero-cloud-arrow-up" class="size-4" /> Upload Photo
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

  # ── Order helpers ──

  defp order_status_badge_class("pending"), do: "badge-warning"
  defp order_status_badge_class("confirmed"), do: "badge-info"
  defp order_status_badge_class("shipped"), do: "badge-primary"
  defp order_status_badge_class("delivered"), do: "badge-success"
  defp order_status_badge_class("cancelled"), do: "badge-error"
  defp order_status_badge_class(_), do: "badge-ghost"

  defp format_order_date(nil), do: ""

  defp format_order_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
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

  defp quick_asks_with_orders(bike, user_orders) do
    base = quick_asks(bike)

    if user_orders != [] do
      order_ask = %{
        label: "My order status?",
        message: "What's the status of my order?"
      }

      [order_ask | Enum.take(base, 2)]
    else
      base
    end
  end

  # ── Tab switching ──

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  # ── Cart events ──

  def handle_event("add-to-cart", %{"kit-id" => kit_id}, socket) do
    user = socket.assigns.user
    kit = Parts.get_kit!(kit_id)

    case Orders.add_kit_to_cart(user, kit) do
      {:ok, _item} ->
        cart = Orders.get_cart(user)
        cart_count = Orders.cart_item_count(user)

        {:noreply,
         socket
         |> assign(:cart, cart)
         |> assign(:cart_count, cart_count)
         |> put_flash(:info, "#{kit.name} added to cart!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not add item to cart.")}
    end
  end

  def handle_event("remove-cart-item", %{"item-id" => item_id}, socket) do
    user = socket.assigns.user

    case Orders.remove_cart_item(user, item_id) do
      {:ok, _item} ->
        cart = Orders.get_cart(user)
        cart_count = Orders.cart_item_count(user)

        {:noreply,
         socket
         |> assign(:cart, cart)
         |> assign(:cart_count, cart_count)
         |> put_flash(:info, "Item removed from cart.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not remove item.")}
    end
  end

  def handle_event("place-order", _params, socket) do
    user = socket.assigns.user

    attrs = %{
      customer_name: user.email |> String.split("@") |> List.first(),
      customer_email: user.email
    }

    case Orders.confirm_order(user, attrs) do
      {:ok, _order} ->
        user_orders = Orders.list_user_orders(user)
        cart = Orders.get_cart(user)
        cart_count = Orders.cart_item_count(user)

        {:noreply,
         socket
         |> assign(:cart, cart)
         |> assign(:cart_count, cart_count)
         |> assign(:user_orders, user_orders)
         |> assign(:active_tab, :orders)
         |> put_flash(:info, "Order placed! We'll be in touch.")}

      {:error, :empty_cart} ->
        {:noreply, put_flash(socket, :error, "Your cart is empty.")}

      {:error, :no_cart} ->
        {:noreply, put_flash(socket, :error, "No active cart found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not place order.")}
    end
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

  # ── Mod events ──

  def handle_event("set-mod-rating", %{"rating" => rating_str}, socket) do
    rating =
      case Integer.parse(rating_str) do
        {0, _} -> nil
        {n, _} when n >= 1 and n <= 5 -> n
        _ -> nil
      end

    {:noreply, assign(socket, :mod_rating, rating)}
  end

  def handle_event("validate-mod", %{"mod" => mod_params}, socket) do
    mod_params = convert_dollars_to_cents(mod_params)

    changeset =
      %UserBikeMod{}
      |> UserBikeMod.changeset(mod_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :mod_form, to_form(changeset, as: :mod))}
  end

  def handle_event("save-mod", %{"mod" => mod_params}, socket) do
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

    mod_params = convert_dollars_to_cents(mod_params)

    case UserBikes.add_mod(user_bike, mod_params) do
      {:ok, _mod} ->
        user_bike = UserBikes.get_user_bike(user)

        {:noreply,
         socket
         |> assign(:user_bike, user_bike)
         |> assign(:mod_form, to_form(UserBikes.change_mod(%UserBikeMod{}), as: :mod))
         |> assign(:mod_rating, nil)
         |> put_flash(:info, "Mod added!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :mod_form, to_form(changeset, as: :mod))}
    end
  end

  def handle_event("delete-mod", %{"id" => id}, socket) do
    case UserBikes.delete_mod(id) do
      {:ok, _mod} ->
        user_bike = UserBikes.get_user_bike(socket.assigns.user)

        {:noreply,
         socket
         |> assign(:user_bike, user_bike)
         |> put_flash(:info, "Mod removed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not remove mod.")}
    end
  end

  # ── Bike selection (for users who registered via Google OAuth without choosing a bike) ──

  def handle_event("select-bike", %{"bike_id" => bike_id}, socket) when bike_id != "" do
    user = socket.assigns.user

    result =
      case socket.assigns.user_bike do
        nil -> UserBikes.create_user_bike(user, %{"bike_id" => bike_id})
        user_bike -> UserBikes.update_user_bike(user_bike, %{"bike_id" => bike_id})
      end

    case result do
      {:ok, _user_bike} ->
        user_bike = UserBikes.get_user_bike(user)
        bike = user_bike.bike
        hero_slides = build_hero_slides(user_bike, bike)
        oil_change_kit = Parts.oil_change_kit_for_bike(bike)

        {:noreply,
         socket
         |> assign(:user_bike, user_bike)
         |> assign(:bike, bike)
         |> assign(:hero_slides, hero_slides)
         |> assign(:oil_change_kit, oil_change_kit)
         |> push_event("update-slides", %{slides: hero_slides})
         |> put_flash(:info, "#{bike.name} added to your garage!")}

      {:error, reason} ->
        require Logger
        Logger.error("Failed to save bike selection for user #{user.id}: #{inspect(reason)}")

        {:noreply,
         put_flash(
           socket,
           :error,
           "We couldn't save your bike selection. This may happen if the selected bike is no longer available or due to a temporary server issue. Please try again."
         )}
    end
  end

  def handle_event("select-bike", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please select a bike.")}
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
      rider_mods = get_rider_mods(socket.assigns.user_bike)

      context = %{
        tier: :public,
        rate_limit_key: socket.assigns.rate_limit_key,
        rider_mods: rider_mods,
        user_orders: socket.assigns.user_orders
      }

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
      rider_mods = get_rider_mods(socket.assigns.user_bike)

      context = %{
        tier: :public,
        rate_limit_key: socket.assigns.rate_limit_key,
        rider_mods: rider_mods,
        user_orders: socket.assigns.user_orders
      }

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

  # ── Rider mods helper ──

  defp get_rider_mods(nil), do: []

  defp get_rider_mods(%{mods: mods}) when is_list(mods), do: mods

  defp get_rider_mods(_), do: []

  # Convert the user-facing "cost_dollars" field to "cost_cents" for the DB.
  # Removes the "cost_dollars" key so it doesn't confuse the changeset.
  defp convert_dollars_to_cents(params) do
    case Map.pop(params, "cost_dollars") do
      {nil, params} ->
        params

      {"", params} ->
        Map.delete(params, "cost_cents")

      {dollars_str, params} ->
        case Float.parse(dollars_str) do
          {dollars, _} ->
            Map.put(params, "cost_cents", round(dollars * 100))

          :error ->
            params
        end
    end
  end

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
