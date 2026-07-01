defmodule BumblebeeLnsWeb.Backpex.Fields.Password do
  @moduledoc false

  use Backpex.Field

  @impl Backpex.Field
  def render_value(assigns) do
    ~H"""
    <p>{raw("&mdash;")}</p>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <Layout.field_container>
        <:label
          :if={not @hide_label}
          align={Backpex.Field.align_label(@field_options, assigns, :center)}
        >
          <Layout.input_label for={@form[@name]} text={@field_options[:label]} />
        </:label>
        <BackpexForm.input
          type="password"
          field={@form[@name]}
          translate_error_fun={Backpex.Field.translate_error_fun(@field_options, assigns)}
          help_text={Backpex.Field.help_text(@field_options, assigns)}
          autocomplete="new-password"
          aria-labelledby={Map.get(assigns, :aria_labelledby)}
        />
      </Layout.field_container>
    </div>
    """
  end
end
