defmodule KoveWeb.StorefrontLive do
  use KoveWeb, :live_view

  alias Kove.Bikes
  alias Kove.KovyAssistant
  alias KoveWeb.ChatLive

  @impl true
  def mount(_params, _session, socket) do
    bikes = Bikes.list_bikes()
    bikes_full = Bikes.list_bikes_full()

    {:ok,
     socket
     |> assign(:page_title, "Kove Moto USA")
     |> assign(:bikes, bikes)
     |> assign(:bikes_full, bikes_full)
     |> assign(:chat_messages, [])
     |> assign(:chat_loading, false)
     |> assign(:chat_open, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 pb-8">
      <%!-- Left Column: Hero + Bike Grid --%>
      <div class="lg:col-span-2">
        <%!-- Hero Section --%>
        <section class="text-center mb-16">
          <h1 class="text-5xl sm:text-6xl font-black tracking-tight">
            KOVE MOTO <span class="text-primary">USA</span>
          </h1>
          <p class="mt-4 text-lg text-base-content/60 max-w-2xl mx-auto">
            Adventure, Rally &amp; Motocross motorcycles engineered for riders who push boundaries.
          </p>
        </section>

        <%!-- Bike Grid — 2 columns --%>
        <section class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <.bike_card :for={bike <- @bikes} bike={bike} />
        </section>
      </div>

      <%!-- Right Column: Chat via ChatLive component (desktop + mobile) --%>
      <div class="lg:col-span-1">
        <.live_component
          module={ChatLive}
          id="kovy-chat"
          chat_messages={@chat_messages}
          chat_loading={@chat_loading}
          chat_open={@chat_open}
          context_label="our lineup"
          placeholder="Ask about any Kove bike..."
          quick_asks={[
            %{label: "Best for beginners?", message: "Which Kove bike is best for a beginner?"},
            %{label: "Compare models", message: "Compare the 800X and 450 Rally"},
            %{label: "Off-road pick?", message: "What's the best Kove for off-road riding?"}
          ]}
        />
      </div>
    </div>
    """
  end

  # ── Bike Card Component ──────────────────────────────────────────────

  attr :bike, Kove.Bikes.Bike, required: true

  defp bike_card(assigns) do
    assigns =
      assigns
      |> assign(:hero_url, Bikes.hero_image_url(assigns.bike))
      |> assign(:price, Bikes.format_msrp(assigns.bike.msrp_cents))
      |> assign(:category, Bikes.category_label(assigns.bike.category))
      |> assign(:status, Bikes.status_label(assigns.bike.status))
      |> assign(:engine_label, engine_label(assigns.bike))

    ~H"""
    <article class="card card-compact bg-base-200 shadow-md hover:shadow-xl transition-shadow group overflow-hidden">
      <%!-- Image --%>
      <figure class="relative aspect-[4/3] overflow-hidden bg-base-300">
        <img
          :if={@hero_url}
          src={@hero_url}
          alt={@bike.name}
          loading="lazy"
          class="object-cover w-full h-full group-hover:scale-105 transition-transform duration-300"
        />
        <div
          :if={!@hero_url}
          class="flex items-center justify-center w-full h-full text-base-content/30"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="size-16"
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

        <%!-- Category badge --%>
        <div class="absolute top-3 left-3">
          <span class={[
            "badge badge-sm font-semibold uppercase tracking-wider",
            badge_color(@bike.category)
          ]}>
            {@category}
          </span>
        </div>

        <%!-- Status badge --%>
        <div :if={@bike.status == :competition} class="absolute top-3 right-3">
          <span class="badge badge-sm badge-warning font-semibold">
            {@status}
          </span>
        </div>
      </figure>

      <%!-- Body --%>
      <div class="card-body gap-1">
        <h2 class="card-title text-lg font-bold leading-snug">
          {@bike.name}
        </h2>

        <p class="text-sm text-base-content/60">
          {@engine_label}
        </p>

        <div class="flex items-center justify-between mt-3">
          <span class="text-xl font-extrabold text-primary">
            {@price}
          </span>
          <.link
            navigate={~p"/bikes/#{@bike.slug}"}
            class="btn btn-primary btn-sm"
          >
            View Details
          </.link>
        </div>
      </div>
    </article>
    """
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

      KovyAssistant.send_catalog_message(socket.assigns.bikes_full, history)

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

  # ── Helpers ──────────────────────────────────────────────────────────

  defp engine_label(%{engine: %{displacement: disp, engine_type: type}})
       when is_binary(disp) and is_binary(type) do
    "#{disp} #{type}"
  end

  defp engine_label(_), do: ""

  defp badge_color(:adv), do: "badge-primary"
  defp badge_color(:rally), do: "badge-secondary"
  defp badge_color(:mx), do: "badge-accent"
  defp badge_color(_), do: "badge-neutral"
end
