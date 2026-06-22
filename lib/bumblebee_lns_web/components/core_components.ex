defmodule BumblebeeLnsWeb.CoreComponents do
  use Phoenix.Component

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <p :if={message = Phoenix.Flash.get(@flash, :info)}>{message}</p>
    <p :if={message = Phoenix.Flash.get(@flash, :error)}>{message}</p>
    """
  end
end
