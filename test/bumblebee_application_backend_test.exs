defmodule BumblebeeApplicationBackendTest do
  use ExUnit.Case, async: true

  test "transform_uplink applies a QuickJS script to backend vars" do
    script = """
    function transform(input, context) {
      return {
        temperature: input.raw / 10,
        app: context.app,
        bytes: context.data.length
      };
    }
    """

    handler =
      {:handler, "test-app", [], :undefined, :undefined, String.to_charlist(script), [],
       :undefined, :undefined, "never"}

    assert %{"temperature" => 23.1, "app" => "test-app", "bytes" => 2} =
             :bumblebee_application_backend.transform_uplink(
               handler,
               %{raw: 231},
               <<1, 2>>,
               %{}
             )
  end

  test "transform_uplink falls back to original vars when script fails" do
    handler =
      {:handler, "test-app", [], :undefined, :undefined,
       ~c'function transform(input) { throw new Error("bad payload"); }', [], :undefined,
       :undefined, "never"}

    assert %{raw: 231} =
             :bumblebee_application_backend.transform_uplink(
               handler,
               %{raw: 231},
               <<1, 2>>,
               %{}
             )
  end
end
