defmodule KoveWeb.Live.BikeHelpers do
  @moduledoc """
  Shared helper functions for bike-related UI rendering across LiveViews.

  These helpers provide consistent styling and labeling for bike attributes
  used in multiple LiveView modules.
  """

  @doc """
  Returns the daisyUI badge color class for a bike category.

  ## Examples

      iex> KoveWeb.Live.BikeHelpers.badge_color(:adv)
      "badge-primary"

      iex> KoveWeb.Live.BikeHelpers.badge_color(:rally)
      "badge-secondary"

      iex> KoveWeb.Live.BikeHelpers.badge_color(:mx)
      "badge-accent"
  """
  def badge_color(:adv), do: "badge-primary"
  def badge_color(:rally), do: "badge-secondary"
  def badge_color(:mx), do: "badge-accent"
  def badge_color(_), do: "badge-neutral"

  @doc """
  Formats an engine label from displacement and type.

  ## Examples

      iex> bike = %{engine: %{displacement: "799cc", engine_type: "Twin Cylinder"}}
      iex> KoveWeb.Live.BikeHelpers.engine_label(bike)
      "799cc Twin Cylinder"
  """
  def engine_label(%{engine: %{displacement: disp, engine_type: type}})
      when is_binary(disp) and is_binary(type) do
    "#{disp} #{type}"
  end

  def engine_label(_), do: ""
end
