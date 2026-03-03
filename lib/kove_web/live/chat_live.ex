defmodule KoveWeb.ChatLive do
  @moduledoc """
  Shared LiveComponent for the Kovy chat assistant.

  Used on both the bike detail page (single‑bike context) and the storefront
  (catalog‑wide context). The parent LiveView owns the chat state and relays
  streaming updates via `send_update/2`.

  ## Required assigns

    * `:id`             — unique component id (e.g. `"kovy-chat"`)
    * `:chat_messages`  — list of `%{role: :user | :assistant, content: String.t(), …}`
    * `:chat_loading`   — boolean, true while Kovy is streaming
    * `:chat_open`      — boolean, whether the mobile drawer is open
    * `:context_label`  — string shown in the empty‑state greeting (e.g. `"the Kove 800X"` or `"our lineup"`)
    * `:placeholder`    — input placeholder when idle (e.g. `"Ask about this bike..."`)
    * `:quick_asks`     — list of `%{label: String.t(), message: String.t()}`

  ## Parent ↔ Component protocol

  Events bubble up to the parent via `send/2`:

    * `{:chat_send, message}`  — user submitted a message
    * `{:chat_retry, message}` — user retried after a retryable error; parent should drop the
      failed assistant message and re-dispatch to KovyAssistant with the cleaned history
    * `:chat_toggle`           — user toggled the mobile drawer

  The parent relays streaming data back down via:

      send_update(ChatLive, id: "kovy-chat", chat_messages: updated, chat_loading: bool)
  """

  use KoveWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%!-- Desktop Chat Panel — right column, visible at lg+ --%>
      <div class="hidden lg:block">
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
          <div
            id={"#{@id}-messages"}
            phx-hook="ScrollBottom"
            class="flex-1 overflow-y-auto p-4 space-y-4"
          >
            <.empty_state
              :if={Enum.empty?(@chat_messages)}
              context_label={@context_label}
              quick_asks={@quick_asks}
              target={@myself}
            />
            <.message_bubble :for={msg <- @chat_messages} msg={msg} target={@myself} />
          </div>

          <%!-- Chat Input --%>
          <div class="border-t border-base-300 p-4">
            <.chat_form
              id={"#{@id}-form"}
              loading={@chat_loading}
              placeholder={@placeholder}
              target={@myself}
            />
          </div>
        </div>
      </div>

      <%!-- Mobile Chat FAB — only visible below lg when chat is closed --%>
      <button
        :if={!@chat_open}
        id={"#{@id}-fab"}
        phx-click="toggle_chat"
        phx-target={@myself}
        class="lg:hidden fixed bottom-6 right-6 btn btn-primary btn-circle btn-lg shadow-xl z-40"
        aria-label="Open chat with Kovy"
      >
        <.icon name="hero-chat-bubble-left-ellipsis" class="size-6" />
      </button>

      <%!-- Mobile Chat Drawer — full-screen overlay below lg --%>
      <div
        :if={@chat_open}
        id={"#{@id}-drawer"}
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
              <p class="text-xs opacity-75">Ask about {@context_label}</p>
            </div>
          </div>
          <button
            id={"#{@id}-close"}
            phx-click="toggle_chat"
            phx-target={@myself}
            class="btn btn-ghost btn-sm btn-circle text-primary-content"
            aria-label="Close chat"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <%!-- Mobile Chat Messages --%>
        <div
          id={"#{@id}-mobile-messages"}
          phx-hook="ScrollBottom"
          class="flex-1 overflow-y-auto p-4 space-y-4"
        >
          <.empty_state
            :if={Enum.empty?(@chat_messages)}
            context_label={@context_label}
            quick_asks={@quick_asks}
            target={@myself}
          />
          <.message_bubble :for={msg <- @chat_messages} msg={msg} target={@myself} />
        </div>

        <%!-- Mobile Chat Input --%>
        <div class="border-t border-base-300 p-4 pb-safe">
          <.chat_form
            id={"#{@id}-mobile-form"}
            loading={@chat_loading}
            placeholder={@placeholder}
            target={@myself}
          />
        </div>
      </div>
    </div>
    """
  end

  # ── Sub-components ───────────────────────────────────────────────────

  attr :context_label, :string, required: true
  attr :quick_asks, :list, required: true
  attr :target, :any, required: true

  defp empty_state(assigns) do
    ~H"""
    <div class="h-full flex flex-col items-center justify-center text-base-content/50 text-center text-sm gap-4">
      <div>
        <p class="font-bold mb-2">Hey! I'm Kovy 👋</p>
        <p>Ask me anything about {@context_label}.</p>
      </div>
      <div class="flex flex-wrap justify-center gap-2">
        <button
          :for={qa <- @quick_asks}
          phx-click="send_message"
          phx-value-message={qa.message}
          phx-target={@target}
          class="btn btn-xs btn-outline"
        >
          {qa.label}
        </button>
      </div>
    </div>
    """
  end

  attr :msg, :map, required: true
  attr :target, :any, required: true

  defp message_bubble(assigns) do
    ~H"""
    <div class={[
      "flex",
      if(@msg.role == :user, do: "justify-end", else: "justify-start")
    ]}>
      <div class={[
        "max-w-xs rounded-lg px-4 py-2",
        if(@msg.role == :user,
          do: "bg-primary text-primary-content",
          else: "bg-base-300 text-base-content"
        ),
        if(Map.get(@msg, :error), do: "border-2 border-error bg-error/10 text-error", else: "")
      ]}>
        <p class="text-sm whitespace-pre-wrap">{@msg.content}</p>

        <%!-- Show retry button for retryable errors --%>
        <button
          :if={
            Map.get(@msg, :error) &&
              Map.get(@msg, :error_type) in [:timeout, :connection, :retry_exhausted]
          }
          phx-click="retry_message"
          phx-target={@target}
          class="text-xs mt-2 link link-error underline"
        >
          Try again
        </button>

        <span
          :if={Map.get(@msg, :streaming) && @msg.content == ""}
          class="loading loading-dots loading-xs"
        />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :loading, :boolean, required: true
  attr :placeholder, :string, required: true
  attr :target, :any, required: true

  defp chat_form(assigns) do
    ~H"""
    <form id={@id} phx-submit="send_message" phx-target={@target} class="flex gap-2">
      <input
        type="text"
        name="message"
        placeholder={if @loading, do: "Kovy is thinking…", else: @placeholder}
        class="input input-bordered input-sm flex-1"
        autocomplete="off"
        disabled={@loading}
      />
      <button type="submit" class="btn btn-primary btn-sm" disabled={@loading}>
        <span :if={@loading} class="loading loading-spinner loading-xs" />
        <.icon :if={!@loading} name="hero-paper-airplane" class="size-4" />
      </button>
    </form>
    """
  end

  # ── Event handlers ───────────────────────────────────────────────────

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    trimmed = String.trim(message)

    if trimmed != "" do
      send(self(), {:chat_send, trimmed})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    send(self(), :chat_toggle)
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_message", _params, socket) do
    last_user_msg =
      socket.assigns.chat_messages
      |> Enum.reverse()
      |> Enum.find(&(&1.role == :user))

    if last_user_msg do
      send(self(), {:chat_retry, last_user_msg.content})
    end

    {:noreply, socket}
  end
end
