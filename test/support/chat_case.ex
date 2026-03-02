defmodule KoveWeb.ChatCase do
  @moduledoc """
  This module defines shared test utilities for LiveView chat tests.

  Provides common Mox setup for Groq API mocking.
  """

  import Mox

  @doc """
  Sets up Mox for chat tests with default stubs for Groq API.

  This should be called in the setup block of tests that exercise
  the KovyAssistant chat functionality.

  ## Example

      use KoveWeb.ConnCase, async: false
      import KoveWeb.ChatCase

      setup do
        setup_chat_mox()
      end
  """
  def setup_chat_mox do
    set_mox_global()
    verify_on_exit!()

    Kove.KovyAssistant.GroqMock
    |> stub(:api_key_available?, fn -> true end)
    |> stub(:stream_chat, fn _messages, _pid -> :ok end)

    :ok
  end
end
