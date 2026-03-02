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

  Updates the last message with the error reason and marks it as an error.

  ## Examples

      def handle_info({:kovy_error, reason}, socket) do
        handle_kovy_error(socket, reason)
      end
  """
  def handle_kovy_error(socket, reason) do
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
