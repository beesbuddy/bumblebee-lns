defmodule BumblebeeLnsWeb.Backpex.Fields.Select do
  @moduledoc false

  @config_schema [
    options: [
      doc: "List of possibly grouped options or function that receives the assigns.",
      type: {:or, [{:list, :any}, {:map, :any, :any}, {:fun, 1}]},
      required: true
    ],
    prompt: [
      doc:
        "The text to be displayed when no option is selected or function that receives the assigns.",
      type: {:or, [:string, {:fun, 1}]}
    ],
    debounce: [
      doc: "Timeout value (in milliseconds), \"blur\" or function that receives the assigns.",
      type: {:or, [:pos_integer, :string, {:fun, 1}]}
    ],
    throttle: [
      doc: "Timeout value (in milliseconds) or function that receives the assigns.",
      type: {:or, [:pos_integer, {:fun, 1}]}
    ]
  ]

  use Backpex.Field, config_schema: @config_schema

  @impl Backpex.Field
  def render_value(assigns) do
    options = get_options(assigns)
    label = get_label(assigns.value, options)

    assigns = assign(assigns, :label, label)

    ~H"""
    <p class={@live_action in [:index, :resource_action] && "truncate"}>
      {HTML.pretty_value(@label)}
    </p>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    options = get_options(assigns)
    field = assigns.form[assigns.name]
    errors = visible_errors(field, assigns.field_options)

    assigns =
      assigns
      |> assign(:field, field)
      |> assign(:errors, errors)
      |> assign(:options, options)
      |> assign_prompt(assigns.field_options)

    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns)}>
          <Layout.input_label for={@field} text={@field_options[:label]} />
        </:label>
        <BackpexForm.input
          type="select"
          id={@field.id}
          name={@field.name}
          value={@field.value}
          errors={@errors}
          options={@options}
          prompt={@prompt}
          help_text={Backpex.Field.help_text(@field_options, assigns)}
          phx-debounce={Backpex.Field.debounce(@field_options, assigns)}
          phx-throttle={Backpex.Field.throttle(@field_options, assigns)}
          aria-labelledby={Map.get(assigns, :aria_labelledby)}
        />
      </Layout.field_container>
    </div>
    """
  end

  @impl Backpex.Field
  def render_index_form(assigns), do: Backpex.Fields.Select.render_index_form(assigns)

  @impl Phoenix.LiveComponent
  def handle_event("update-field", params, socket),
    do: Backpex.Fields.Select.handle_event("update-field", params, socket)

  defp visible_errors(field, field_options) do
    if Phoenix.Component.used_input?(field) or submit_action?(field.form.source.action) do
      translate_error_fun = Backpex.Field.translate_error_fun(field_options, %{})
      Backpex.HTML.Form.translate_form_errors(field.errors, translate_error_fun)
    else
      []
    end
  end

  defp submit_action?(action), do: action in [:insert, :update]

  defp get_label(value, options) do
    options =
      options
      |> Enum.map(fn
        {_label, value} = option ->
          case value do
            value when is_list(value) or is_map(value) -> value
            _value -> option
          end

        option ->
          option
      end)
      |> List.flatten()

    case Enum.find(options, fn option -> value?(option, value) end) do
      nil -> value
      {label, _value} -> label
      label -> label
    end
  end

  defp value?({_label, value}, to_compare), do: to_string(value) == to_string(to_compare)
  defp value?(value, to_compare), do: to_string(value) == to_string(to_compare)

  defp assign_prompt(assigns, field_options) do
    prompt =
      case Map.get(field_options, :prompt) do
        nil -> nil
        prompt when is_function(prompt) -> prompt.(assigns)
        prompt -> prompt
      end

    assign(assigns, :prompt, prompt)
  end

  defp get_options(assigns) do
    case Map.get(assigns.field_options, :options) do
      options when is_function(options) -> options.(assigns)
      options -> options
    end
  end
end
