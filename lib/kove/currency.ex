defmodule Kove.Currency do
  @moduledoc """
  Currency formatting and parsing utilities for MSRP values.

  Handles conversion between cents (integer storage) and formatted USD strings.
  """

  @doc """
  Formats an integer cents value as a USD string.

  Returns "Contact for pricing" when nil.

  ## Examples

      iex> Kove.Currency.format(1299900)
      "$12,999"

      iex> Kove.Currency.format(100000000)
      "$1,000,000"

      iex> Kove.Currency.format(nil)
      "Contact for pricing"
  """
  def format(nil), do: "Contact for pricing"

  def format(cents) when is_integer(cents) do
    dollars = div(cents, 100)

    formatted =
      dollars
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

    "$#{formatted}"
  end

  @doc """
  Parses a USD string to cents.

  Returns nil when input is nil.

  ## Examples

      iex> Kove.Currency.parse("$12,999")
      1299900

      iex> Kove.Currency.parse("$1,000,000")
      100000000

      iex> Kove.Currency.parse(nil)
      nil
  """
  def parse(nil), do: nil

  def parse(msrp_str) when is_binary(msrp_str) do
    msrp_str
    |> String.replace("$", "")
    |> String.replace(",", "")
    |> String.to_integer()
    |> Kernel.*(100)
  end
end
