defmodule KoveWeb.BikeDetailsLive do
  use KoveWeb, :live_view

  alias Kove.Bikes
  alias Kove.KovyAssistant

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Bikes.get_bike_by_slug(slug) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      bike ->
        sorted_images = Enum.sort_by(bike.images, & &1.position)

        {:ok,
         socket
         |> assign(:page_title, bike.name)
         |> assign(:bike, bike)
         |> assign(:sorted_images, sorted_images)
         |> assign(:current_image_index, 0)
         |> assign(:active_tab, :marketing)
         |> assign(:chat_messages, [])
         |> assign(:chat_loading, false)
         |> assign(:chat_open, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 pb-8">
      <%!-- Left Column: Bike Details (wider) --%>
      <div class="lg:col-span-2">
        <%!-- Bike Image Slider --%>
        <div
          id="image-slider"
          class="mb-6 rounded-lg overflow-hidden bg-base-300 aspect-video relative group"
        >
          <%= if @sorted_images != [] do %>
            <% current_image = Enum.at(@sorted_images, @current_image_index) %>
            <img
              src={current_image.url}
              alt={current_image.alt || @bike.name}
              class="w-full h-full object-cover"
            />

            <%!-- Prev / Next buttons (shown when more than 1 image) --%>
            <%= if length(@sorted_images) > 1 do %>
              <button
                phx-click="prev_image"
                class="btn btn-circle btn-sm bg-base-100/70 hover:bg-base-100 border-none absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity"
                aria-label="Previous image"
              >
                <.icon name="hero-chevron-left" class="size-5" />
              </button>
              <button
                phx-click="next_image"
                class="btn btn-circle btn-sm bg-base-100/70 hover:bg-base-100 border-none absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity"
                aria-label="Next image"
              >
                <.icon name="hero-chevron-right" class="size-5" />
              </button>

              <%!-- Dot indicators --%>
              <div class="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
                <%= for {_img, idx} <- Enum.with_index(@sorted_images) do %>
                  <button
                    phx-click="goto_image"
                    phx-value-index={idx}
                    class={[
                      "size-2.5 rounded-full transition-all",
                      if(@current_image_index == idx,
                        do: "bg-primary scale-110",
                        else: "bg-base-content/40 hover:bg-base-content/60"
                      )
                    ]}
                    aria-label={"Go to image #{idx + 1}"}
                  />
                <% end %>
              </div>

              <%!-- Counter --%>
              <div class="absolute top-3 right-3 bg-base-100/70 text-base-content text-xs font-medium px-2 py-1 rounded-full">
                {@current_image_index + 1} / {length(@sorted_images)}
              </div>
            <% end %>
          <% else %>
            <div class="flex items-center justify-center w-full h-full text-base-content/30">
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
            </div>
          <% end %>
        </div>

        <%!-- Bike Header Info --%>
        <div class="mb-6">
          <div class="flex items-start justify-between gap-4 mb-2">
            <div>
              <h1 class="text-4xl font-black mb-1">{@bike.name}</h1>
              <p class="text-lg text-base-content/60">
                {Bikes.category_label(@bike.category)} • {@bike.year}
              </p>
            </div>
            <div class="text-right">
              <p class="text-3xl font-extrabold text-primary">
                {Bikes.format_msrp(@bike.msrp_cents)}
              </p>
              <p :if={@bike.status == :competition} class="badge badge-warning mt-2">
                {Bikes.status_label(@bike.status)}
              </p>
            </div>
          </div>
        </div>

        <%!-- Navigation Tabs --%>
        <div class="tabs tabs-bordered mb-6 gap-2">
          <button
            phx-click="set_tab"
            phx-value-tab="marketing"
            class={[
              "tab",
              @active_tab == :marketing && "tab-active"
            ]}
          >
            <.icon name="hero-sparkles" class="size-5" />
            <span class="hidden sm:inline ml-2">Marketing</span>
          </button>
          <button
            phx-click="set_tab"
            phx-value-tab="engine"
            class={[
              "tab",
              @active_tab == :engine && "tab-active"
            ]}
          >
            <.icon name="hero-cog-6-tooth" class="size-5" />
            <span class="hidden sm:inline ml-2">Engine</span>
          </button>
          <button
            phx-click="set_tab"
            phx-value-tab="chassis"
            class={[
              "tab",
              @active_tab == :chassis && "tab-active"
            ]}
          >
            <.icon name="hero-wrench-screwdriver" class="size-5" />
            <span class="hidden sm:inline ml-2">Chassis</span>
          </button>
        </div>

        <%!-- Content Area --%>
        <div class="bg-base-200 rounded-lg p-6 min-h-64">
          <%!-- Marketing Tab --%>
          <div :if={@active_tab == :marketing} class="space-y-4">
            <div :if={Enum.empty?(@bike.descriptions)} class="text-base-content/50">
              No marketing information available.
            </div>
            <div :for={desc <- Enum.filter(@bike.descriptions, &(&1.kind == :marketing))}>
              <p class="text-base leading-relaxed">{desc.body}</p>
            </div>
          </div>

          <%!-- Engine Tab --%>
          <div :if={@active_tab == :engine} class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Platform
                </h3>
                <p class="text-lg">{@bike.engine.platform_name}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Type
                </h3>
                <p class="text-lg">{@bike.engine.engine_type}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Displacement
                </h3>
                <p class="text-lg">{@bike.engine.displacement}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Bore × Stroke
                </h3>
                <p class="text-lg">{@bike.engine.bore_x_stroke}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Cooling
                </h3>
                <p class="text-lg">{@bike.engine.cooling}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Fuel System
                </h3>
                <p class="text-lg">{@bike.engine.fuel_system}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Transmission
                </h3>
                <p class="text-lg">{@bike.engine.transmission}</p>
              </div>
              <div>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Clutch
                </h3>
                <p class="text-lg">{@bike.engine.clutch}</p>
              </div>
              <div :if={@bike.engine.max_power}>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Max Power
                </h3>
                <p class="text-lg">{@bike.engine.max_power}</p>
              </div>
              <div :if={@bike.engine.max_torque}>
                <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                  Max Torque
                </h3>
                <p class="text-lg">{@bike.engine.max_torque}</p>
              </div>
            </div>
          </div>

          <%!-- Chassis Tab --%>
          <div :if={@active_tab == :chassis} class="space-y-6">
            <%!-- Chassis Specs --%>
            <div
              :if={is_nil(@bike.chassis_spec) && is_nil(@bike.dimension)}
              class="text-base-content/50"
            >
              No chassis information available.
            </div>
            <div :if={@bike.chassis_spec}>
              <h3 class="text-lg font-bold mb-4">Chassis</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div :if={@bike.chassis_spec.frame_type}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Frame Type
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.frame_type}</p>
                </div>
                <div :if={@bike.chassis_spec.front_suspension}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Front Suspension
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.front_suspension}</p>
                </div>
                <div :if={@bike.chassis_spec.front_travel}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Front Travel
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.front_travel}</p>
                </div>
                <div :if={@bike.chassis_spec.rear_suspension}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Rear Suspension
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.rear_suspension}</p>
                </div>
                <div :if={@bike.chassis_spec.rear_travel}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Rear Travel
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.rear_travel}</p>
                </div>
                <div :if={@bike.chassis_spec.front_brake}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Front Brake
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.front_brake}</p>
                </div>
                <div :if={@bike.chassis_spec.rear_brake}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Rear Brake
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.rear_brake}</p>
                </div>
                <div :if={@bike.chassis_spec.abs_system}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    ABS System
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.abs_system}</p>
                </div>
                <div :if={@bike.chassis_spec.wheels}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Wheels
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.wheels}</p>
                </div>
                <div :if={@bike.chassis_spec.tires}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Tires
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.tires}</p>
                </div>
                <div :if={@bike.chassis_spec.steering_angle}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Steering Angle
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.steering_angle}</p>
                </div>
                <div :if={@bike.chassis_spec.rake_angle}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Rake Angle
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.rake_angle}</p>
                </div>
                <div :if={@bike.chassis_spec.triple_clamp}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Triple Clamp
                  </h3>
                  <p class="text-lg">{@bike.chassis_spec.triple_clamp}</p>
                </div>
              </div>
            </div>

            <%!-- Dimensions --%>
            <div :if={@bike.dimension}>
              <h3 class="text-lg font-bold mb-4">Dimensions</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div :if={@bike.dimension.weight}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Weight ({if @bike.dimension.weight_type,
                      do: Atom.to_string(@bike.dimension.weight_type),
                      else: ""})
                  </h3>
                  <p class="text-lg">{@bike.dimension.weight}</p>
                </div>
                <div :if={@bike.dimension.fuel_capacity}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Fuel Capacity
                  </h3>
                  <p class="text-lg">{@bike.dimension.fuel_capacity}</p>
                </div>
                <div :if={@bike.dimension.estimated_range}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Estimated Range
                  </h3>
                  <p class="text-lg">{@bike.dimension.estimated_range}</p>
                </div>
                <div :if={@bike.dimension.overall_size}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Overall Size
                  </h3>
                  <p class="text-lg">{@bike.dimension.overall_size}</p>
                </div>
                <div :if={@bike.dimension.wheelbase}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Wheelbase
                  </h3>
                  <p class="text-lg">{@bike.dimension.wheelbase}</p>
                </div>
                <div :if={@bike.dimension.seat_height}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Seat Height
                  </h3>
                  <p class="text-lg">{@bike.dimension.seat_height}</p>
                </div>
                <div :if={@bike.dimension.ground_clearance}>
                  <h3 class="font-bold text-sm uppercase tracking-wide text-base-content/60 mb-1">
                    Ground Clearance
                  </h3>
                  <p class="text-lg">{@bike.dimension.ground_clearance}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right Column: Chat — desktop only --%>
      <div class="hidden lg:block lg:col-span-1">
        <div class="bg-base-200 rounded-lg lg:h-screen lg:sticky lg:top-20 flex flex-col overflow-hidden">
          <%!-- Chat Header --%>
          <div class="bg-primary text-primary-content p-4 border-b border-primary/20">
            <div class="flex items-center gap-2">
              <div class="size-8 rounded-full bg-primary-content/20 flex items-center justify-center">
                <.icon name="hero-sparkles" class="size-5" />
              </div>
              <div>
                <h2 class="font-bold">Kovy</h2>
                <p class="text-xs opacity-75">Your bike assistant</p>
              </div>
            </div>
          </div>

          <%!-- Chat Messages --%>
          <div id="chat-messages" phx-hook="ScrollBottom" class="flex-1 overflow-y-auto p-4 space-y-4">
            <div
              :if={Enum.empty?(@chat_messages)}
              class="h-full flex flex-col items-center justify-center text-base-content/50 text-center text-sm gap-4"
            >
              <div>
                <p class="font-bold mb-2">Hey! I'm Kovy 👋</p>
                <p>Ask me anything about the {@bike.name}.</p>
              </div>
              <div class="flex flex-wrap justify-center gap-2">
                <button
                  phx-click="send_message"
                  phx-value-message="How does this compare to a KTM?"
                  class="btn btn-xs btn-outline"
                >
                  vs KTM?
                </button>
                <button
                  phx-click="send_message"
                  phx-value-message="What should I expect for maintenance?"
                  class="btn btn-xs btn-outline"
                >
                  Maintenance?
                </button>
                <button
                  phx-click="send_message"
                  phx-value-message="What upgrades do riders make?"
                  class="btn btn-xs btn-outline"
                >
                  Upgrades?
                </button>
              </div>
            </div>
            <div
              :for={msg <- @chat_messages}
              class={[
                "flex",
                if msg.role == :user do
                  "justify-end"
                else
                  "justify-start"
                end
              ]}
            >
              <div class={[
                "max-w-xs rounded-lg px-4 py-2",
                if msg.role == :user do
                  "bg-primary text-primary-content"
                else
                  "bg-base-300 text-base-content"
                end,
                if Map.get(msg, :error) do
                  "border border-error"
                else
                  ""
                end
              ]}>
                <p class="text-sm whitespace-pre-wrap">{msg.content}</p>
                <span
                  :if={Map.get(msg, :streaming) && msg.content == ""}
                  class="loading loading-dots loading-xs"
                />
              </div>
            </div>
          </div>

          <%!-- Chat Input --%>
          <div class="border-t border-base-300 p-4">
            <form phx-submit="send_message" class="flex gap-2">
              <input
                type="text"
                name="message"
                placeholder={
                  if @chat_loading, do: "Kovy is thinking…", else: "Ask about this bike..."
                }
                class="input input-bordered input-sm flex-1"
                autocomplete="off"
                disabled={@chat_loading}
              />
              <button type="submit" class="btn btn-primary btn-sm" disabled={@chat_loading}>
                <span :if={@chat_loading} class="loading loading-spinner loading-xs" />
                <.icon :if={!@chat_loading} name="hero-paper-airplane" class="size-4" />
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>

    <%!-- Mobile Chat FAB — only visible below lg when chat is closed --%>
    <button
      :if={!@chat_open}
      id="mobile-chat-fab"
      phx-click="toggle_chat"
      class="lg:hidden fixed bottom-6 right-6 btn btn-primary btn-circle btn-lg shadow-xl z-40"
      aria-label="Open chat with Kovy"
    >
      <.icon name="hero-chat-bubble-left-ellipsis" class="size-6" />
    </button>

    <%!-- Mobile Chat Drawer — full-screen overlay below lg --%>
    <div
      :if={@chat_open}
      id="mobile-chat-drawer"
      class="lg:hidden fixed inset-0 z-50 flex flex-col bg-base-100"
    >
      <%!-- Mobile Chat Header with close button --%>
      <div class="bg-primary text-primary-content p-4 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="size-8 rounded-full bg-primary-content/20 flex items-center justify-center">
            <.icon name="hero-sparkles" class="size-5" />
          </div>
          <div>
            <h2 class="font-bold">Kovy</h2>
            <p class="text-xs opacity-75">Ask about the {@bike.name}</p>
          </div>
        </div>
        <button
          id="mobile-chat-close"
          phx-click="toggle_chat"
          class="btn btn-ghost btn-sm btn-circle text-primary-content"
          aria-label="Close chat"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>

      <%!-- Mobile Chat Messages --%>
      <div
        id="mobile-chat-messages"
        phx-hook="ScrollBottom"
        class="flex-1 overflow-y-auto p-4 space-y-4"
      >
        <div
          :if={Enum.empty?(@chat_messages)}
          class="h-full flex flex-col items-center justify-center text-base-content/50 text-center text-sm gap-4"
        >
          <div>
            <p class="font-bold mb-2">Hey! I'm Kovy 👋</p>
            <p>Ask me anything about the {@bike.name}.</p>
          </div>
          <div class="flex flex-wrap justify-center gap-2">
            <button
              phx-click="send_message"
              phx-value-message="How does this compare to a KTM?"
              class="btn btn-xs btn-outline"
            >
              vs KTM?
            </button>
            <button
              phx-click="send_message"
              phx-value-message="What should I expect for maintenance?"
              class="btn btn-xs btn-outline"
            >
              Maintenance?
            </button>
            <button
              phx-click="send_message"
              phx-value-message="What upgrades do riders make?"
              class="btn btn-xs btn-outline"
            >
              Upgrades?
            </button>
          </div>
        </div>
        <div
          :for={msg <- @chat_messages}
          class={[
            "flex",
            if msg.role == :user do
              "justify-end"
            else
              "justify-start"
            end
          ]}
        >
          <div class={[
            "max-w-xs rounded-lg px-4 py-2",
            if msg.role == :user do
              "bg-primary text-primary-content"
            else
              "bg-base-300 text-base-content"
            end,
            if Map.get(msg, :error) do
              "border border-error"
            else
              ""
            end
          ]}>
            <p class="text-sm whitespace-pre-wrap">{msg.content}</p>
            <span
              :if={Map.get(msg, :streaming) && msg.content == ""}
              class="loading loading-dots loading-xs"
            />
          </div>
        </div>
      </div>

      <%!-- Mobile Chat Input --%>
      <div class="border-t border-base-300 p-4 pb-safe">
        <form phx-submit="send_message" class="flex gap-2">
          <input
            type="text"
            name="message"
            placeholder={if @chat_loading, do: "Kovy is thinking…", else: "Ask about this bike..."}
            class="input input-bordered input-sm flex-1"
            autocomplete="off"
            disabled={@chat_loading}
          />
          <button type="submit" class="btn btn-primary btn-sm" disabled={@chat_loading}>
            <span :if={@chat_loading} class="loading loading-spinner loading-xs" />
            <.icon :if={!@chat_loading} name="hero-paper-airplane" class="size-4" />
          </button>
        </form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :chat_open, !socket.assigns.chat_open)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("prev_image", _params, socket) do
    count = length(socket.assigns.sorted_images)
    current = socket.assigns.current_image_index
    new_index = if current == 0, do: count - 1, else: current - 1
    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  @impl true
  def handle_event("next_image", _params, socket) do
    count = length(socket.assigns.sorted_images)
    current = socket.assigns.current_image_index
    new_index = if current >= count - 1, do: 0, else: current + 1
    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  @impl true
  def handle_event("goto_image", %{"index" => index}, socket) do
    {idx, _} = Integer.parse(index)
    count = length(socket.assigns.sorted_images)
    idx = max(0, min(idx, count - 1))
    {:noreply, assign(socket, :current_image_index, idx)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    message = String.trim(message)

    if message == "" || socket.assigns.chat_loading do
      {:noreply, socket}
    else
      user_msg = %{role: :user, content: message}
      assistant_msg = %{role: :assistant, content: "", streaming: true}

      # Build the history to send to the API (existing + new user message, no empty assistant)
      history = socket.assigns.chat_messages ++ [user_msg]

      KovyAssistant.send_message(socket.assigns.bike, history)

      {:noreply,
       socket
       |> assign(:chat_messages, history ++ [assistant_msg])
       |> assign(:chat_loading, true)
       |> assign(:chat_open, true)}
    end
  end

  # ── Streaming callbacks from KovyAssistant ──

  @impl true
  def handle_info({:kovy_chunk, text}, socket) do
    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        %{msg | content: msg.content <> text}
      end)

    {:noreply, assign(socket, :chat_messages, messages)}
  end

  @impl true
  def handle_info({:kovy_done}, socket) do
    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        Map.delete(msg, :streaming)
      end)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:chat_loading, false)}
  end

  @impl true
  def handle_info({:kovy_error, reason}, socket) do
    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        msg
        |> Map.put(:content, reason)
        |> Map.put(:streaming, false)
        |> Map.put(:error, true)
      end)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:chat_loading, false)}
  end
end
