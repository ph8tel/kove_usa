defmodule KoveWeb.BikeDetailsLive do
  use KoveWeb, :live_view

  alias Kove.Bikes
  alias Kove.KovyAssistant
  alias KoveWeb.ChatLive

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

      <%!-- Right Column: Chat via ChatLive component (desktop + mobile) --%>
      <div class="lg:col-span-1">
        <.live_component
          module={ChatLive}
          id="kovy-chat"
          chat_messages={@chat_messages}
          chat_loading={@chat_loading}
          chat_open={@chat_open}
          context_label={"the #{@bike.name}"}
          placeholder="Ask about this bike..."
          quick_asks={[
            %{label: "vs KTM?", message: "How does this compare to a KTM?"},
            %{label: "Maintenance?", message: "What should I expect for maintenance?"},
            %{label: "Upgrades?", message: "What upgrades do riders make?"}
          ]}
        />
      </div>
    </div>
    """
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

  # ── Chat callbacks from ChatLive component ──

  @impl true
  def handle_info({:chat_send, message}, socket) do
    if message == "" || socket.assigns.chat_loading do
      {:noreply, socket}
    else
      user_msg = %{role: :user, content: message}
      assistant_msg = %{role: :assistant, content: "", streaming: true}

      history = socket.assigns.chat_messages ++ [user_msg]

      KovyAssistant.send_message(socket.assigns.bike, history)

      {:noreply,
       socket
       |> assign(:chat_messages, history ++ [assistant_msg])
       |> assign(:chat_loading, true)
       |> assign(:chat_open, true)}
    end
  end

  @impl true
  def handle_info(:chat_toggle, socket) do
    {:noreply, assign(socket, :chat_open, !socket.assigns.chat_open)}
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
