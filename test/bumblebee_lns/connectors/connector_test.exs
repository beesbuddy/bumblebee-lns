defmodule BumblebeeLns.Connectors.ConnectorTest do
  use ExUnit.Case, async: true

  alias BumblebeeLns.Connectors.Connector

  test "changeset normalizes and validates connector fields" do
    changeset =
      Connector.changeset(%Connector{}, %{
        "connid" => " telemetry ",
        "app" => " backend ",
        "format" => "json",
        "uri" => " mqtt://localhost ",
        "publish_qos" => "1",
        "publish_uplinks" => " uplinks/{devaddr} ",
        "subscribe_qos" => "2",
        "enabled" => "true",
        "auth" => " basic "
      })

    assert changeset.valid?
    connector = Ecto.Changeset.apply_changes(changeset)

    assert connector.connid == "telemetry"
    assert connector.app == "backend"
    assert connector.uri == "mqtt://localhost"
    assert connector.publish_qos == 1
    assert connector.subscribe_qos == 2
    assert connector.publish_uplinks == "uplinks/{devaddr}"
    assert connector.enabled
    assert connector.auth == "basic"
  end

  test "changeset rejects unsupported format and qos" do
    changeset =
      Connector.changeset(%Connector{}, %{
        "connid" => "telemetry",
        "app" => "backend",
        "format" => "xml",
        "uri" => "mqtt://localhost",
        "publish_qos" => "3",
        "subscribe_qos" => "x"
      })

    refute changeset.valid?

    assert {"is invalid", [validation: :inclusion, enum: ["json", "raw"]]} in Keyword.get_values(
             changeset.errors,
             :format
           )

    assert {"is invalid", [validation: :inclusion, enum: 0..2]} in Keyword.get_values(
             changeset.errors,
             :publish_qos
           )

    assert {"is invalid", [type: :integer, validation: :cast]} in Keyword.get_values(
             changeset.errors,
             :subscribe_qos
           )
  end
end
