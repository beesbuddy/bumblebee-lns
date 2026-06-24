defmodule BumblebeeLnsWeb.CoreComponents do
  use Phoenix.Component

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <p :if={message = Phoenix.Flash.get(@flash, :info)}>{message}</p>
    <p :if={message = Phoenix.Flash.get(@flash, :error)}>{message}</p>
    """
  end

  def translate_backpex({message, options}), do: interpolate(message, options)
  def translate_error({message, options}), do: interpolate(message, options)

  defp interpolate(message, options) do
    Enum.reduce(options, message, fn {key, value}, translated ->
      String.replace(translated, "%{#{key}}", to_string(value))
    end)
  end
end
