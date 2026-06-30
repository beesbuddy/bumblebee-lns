defmodule BumblebeeLnsWeb.Backpex.ResourceSlots do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @impl Backpex.LiveResource
      def render_resource_slot(var!(assigns), action, :page_title)
          when action in [:index, :new, :edit] do
        ~H""
      end
    end
  end
end
