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
    searchable: [
      doc: "Render the select as a searchable single-value picker.",
      type: :boolean
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
      |> assign(:searchable?, Map.get(assigns.field_options, :searchable, false))
      |> assign(:help_text, Backpex.Field.help_text(assigns.field_options, assigns))
      |> assign_prompt(assigns.field_options)

    if assigns.searchable? do
      ~H"""
      <div>
        <Layout.field_container>
          <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns)}>
            <Layout.input_label for={@field} text={@field_options[:label]} />
          </:label>
          <div class="backpex-searchable-select" data-searchable-select>
            <input
              type="hidden"
              id={@field.id}
              name={@field.name}
              value={@field.value}
              data-searchable-select-value
            />
            <input
              type="text"
              id={"#{@field.id}_search"}
              value={selected_label(@field.value, @options)}
              class={[
                "input w-full",
                @errors != [] && "input-error bg-error/10"
              ]}
              placeholder={@prompt || @field_options[:placeholder]}
              autocomplete="off"
              role="combobox"
              aria-expanded="false"
              data-searchable-select-input
              phx-debounce={Backpex.Field.debounce(@field_options, assigns)}
              phx-throttle={Backpex.Field.throttle(@field_options, assigns)}
              aria-labelledby={Map.get(assigns, :aria_labelledby)}
            />
            <div class="backpex-searchable-select-options" role="listbox" hidden>
              <button
                :for={{label, value} <- flat_options(@options)}
                type="button"
                class="backpex-searchable-select-option"
                data-value={value}
                role="option"
              >
                <span>{label}</span>
                <span :if={to_string(label) != to_string(value)} class="backpex-searchable-select-value">
                  {value}
                </span>
              </button>
              <div class="backpex-searchable-select-empty" hidden>No matching options</div>
            </div>
            <Backpex.HTML.Form.error :for={msg <- @errors}>{msg}</Backpex.HTML.Form.error>
            <Backpex.HTML.Form.help_text :if={@help_text}>
              {@help_text}
            </Backpex.HTML.Form.help_text>
          </div>
        </Layout.field_container>
      </div>
      """
    else
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
    options = flat_options(options)

    case Enum.find(options, fn option -> value?(option, value) end) do
      nil -> value
      {label, _value} -> label
      label -> label
    end
  end

  defp value?({_label, value}, to_compare), do: to_string(value) == to_string(to_compare)
  defp value?(value, to_compare), do: to_string(value) == to_string(to_compare)

  defp selected_label(nil, _options), do: ""
  defp selected_label("", _options), do: ""

  defp selected_label(value, options) do
    case Enum.find(flat_options(options), fn option -> value?(option, value) end) do
      {label, _value} -> label
      _other -> ""
    end
  end

  defp flat_options(options) do
    options
    |> Enum.flat_map(fn
      {_label, value} when is_list(value) or is_map(value) ->
        flat_options(value)

      {label, value} ->
        [{label, value}]

      value ->
        [{value, value}]
    end)
  end

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
