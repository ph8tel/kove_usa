defmodule KoveWeb.Live.ChatHandlers do
  @moduledoc """
  Shared chat state management handlers for LiveViews with Kovy integration.

  This module provides common `handle_info/2` callbacks for managing
  chat state across LiveViews that integrate with the KovyAssistant.

  ## Usage

  Import this module in your LiveView and delegate the chat-related
  `handle_info/2` callbacks to the functions provided:

      defmodule MyAppWeb.MyLive do
        use MyAppWeb, :live_view
        import KoveWeb.Live.ChatHandlers

        def handle_info(:chat_toggle, socket) do
          handle_chat_toggle(socket)
        end

        def handle_info({:kovy_chunk, text}, socket) do
          handle_kovy_chunk(socket, text)
        end

        def handle_info(:kovy_done, socket) do
          handle_kovy_done(socket)
        end

        def handle_info({:kovy_error, reason}, socket) do
          handle_kovy_error(socket, reason)
        end
      end
  """

  import Phoenix.Component

  @doc """
  Toggles the chat panel open/closed state.

  ## Examples

      def handle_info(:chat_toggle, socket) do
        handle_chat_toggle(socket)
      end
  """
  def handle_chat_toggle(socket) do
    {:noreply, assign(socket, :chat_open, !socket.assigns.chat_open)}
  end

  @doc """
  Handles incoming text chunks from the Groq streaming API.

  Appends the new text to the last message (assistant response) in the chat.

  ## Examples

      def handle_info({:kovy_chunk, text}, socket) do
        handle_kovy_chunk(socket, text)
      end
  """
  def handle_kovy_chunk(socket, text) do
    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        %{msg | content: msg.content <> text}
      end)

    {:noreply, assign(socket, :chat_messages, messages)}
  end

  @doc """
  Handles completion of a Groq streaming response.

  Removes the :streaming flag from the last message and sets loading to false.

  ## Examples

      def handle_info(:kovy_done, socket) do
        handle_kovy_done(socket)
      end
  """
  def handle_kovy_done(socket) do
    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        Map.delete(msg, :streaming)
      end)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:chat_loading, false)}
  end

  @doc """
  Handles errors from the Groq streaming API.

  Accepts either a categorized error tuple `{error_type, message}` or a plain string
  for backwards compatibility. Marks the message as an error and stops loading.

  ## Examples

      def handle_info({:kovy_error, error_type, reason}, socket) do
        handle_kovy_error(socket, error_type, reason)
      end

      def handle_info({:kovy_error, reason}, socket) do
        handle_kovy_error(socket, reason)
      end
  """
  def handle_kovy_error(socket, error_type, original_message) when is_atom(error_type) do
    user_message =
      case error_type do
        :rate_limited ->
          "⏱️ Kovy is temporarily busy. Wait 30 seconds and try again."

        :auth_failed ->
          "🔐 Authentication issue. Please contact support."

        :timeout ->
          "⏳ Request timed out. Try asking a simpler question."

        :connection ->
          "📡 Connection lost. Check your internet and try again."

        :server_error ->
          "🔧 Groq's servers are having issues. Please try again shortly."

        :retry_exhausted ->
          "Couldn't connect to Kovy after multiple attempts. Please try again."

        :internal_error ->
          "Kovy encountered an internal error. Please try again."

        _ ->
          original_message
      end

    messages =
      List.update_at(socket.assigns.chat_messages, -1, fn msg ->
        msg
        |> Map.put(:content, user_message)
        |> Map.put(:streaming, false)
        |> Map.put(:error, true)
        |> Map.put(:error_type, error_type)
      end)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:chat_loading, false)}
  end

  # Backwards compatibility for raw string errors
  def handle_kovy_error(socket, error_message) when is_binary(error_message) do
    handle_kovy_error(socket, :unknown, error_message)
  end
end
