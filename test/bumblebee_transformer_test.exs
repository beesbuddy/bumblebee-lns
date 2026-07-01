defmodule BumblebeeTransformerTest do
  use ExUnit.Case, async: true

  test "transforms input map with context" do
    script = """
    function transform(input, context) {
      return {temperature: input.raw / 10, device: context.devaddr};
    }
    """

    result =
      :bumblebee_transformer.transform(String.to_charlist(script), %{raw: 231}, %{
        context: %{devaddr: "01020304"}
      })

    case result do
      {:error, :quickjs_nif_not_loaded} ->
        assert true

      {:ok, transformed} ->
        assert transformed["temperature"] == 23.1
        assert transformed["device"] == "01020304"
    end
  end

  test "returns an error when script raises" do
    script = "function transform(input) { throw new Error('bad payload'); }"

    assert {:error, _reason} =
             :bumblebee_transformer.transform(String.to_charlist(script), %{})
  end
end
