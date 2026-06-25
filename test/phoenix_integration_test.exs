defmodule BumblebeeLns.PhoenixIntegrationTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint BumblebeeLnsWeb.Endpoint

  setup do
    area_name = "liveview-area-#{System.unique_integer([:positive])}"
    gateway_mac = <<System.unique_integer([:positive])::64>>

    :ok =
      :mnesia.dirty_write({:area, area_name, "EU868", [], :undefined, true})

    :ok =
      :mnesia.dirty_write(
        {:gateway, gateway_mac, area_name, 0, 2, "Test gateway", {54.6872, 25.2797}, 112.0,
         :undefined, :undefined, :undefined, :undefined, [], [], [], 0, 0, :undefined}
      )

    on_exit(fn ->
      :mnesia.dirty_delete(:area, area_name)
      :mnesia.dirty_delete(:gateway, gateway_mac)
    end)

    %{area_name: area_name, gateway_mac: :bumblebee_utils.binary_to_hex(gateway_mac)}
  end

  test "Elixir application supervises the Erlang LNS runtime" do
    assert is_pid(Process.whereis(:bumblebee_gw_forwarder))
    assert is_pid(Process.whereis(:bumblebee_gw_router))
    assert is_pid(Process.whereis(:bumblebee_http_registry))
    assert :mnesia.system_info(:is_running) == :yes
  end

  test "Phoenix endpoint is supervised" do
    assert is_pid(Process.whereis(BumblebeeLnsWeb.Endpoint))
  end

  test "area list shows configured areas", %{area_name: area_name} do
    {:ok, _view, html} = live(build_conn(), "/areas")

    assert html =~ "Areas"
    assert html =~ area_name
    assert html =~ "EU 863-870MHz"
  end

  test "area new page persists a new area" do
    new_area_name = "created-area-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      :mnesia.dirty_delete(:area, new_area_name)
    end)

    {:ok, view, _html} = live(build_conn(), "/areas/new")

    assert has_element?(view, "#resource-form")

    view
    |> form("#resource-form", %{
      "change" => %{
        "name" => new_area_name,
        "region" => "EU868",
        "slack_channel" => "#created",
        "log_ignored" => "true"
      }
    })
    |> render_submit(%{"save-type" => "save"})

    assert_redirect(view, "/areas")

    assert [
             {:area, ^new_area_name, "EU868", [], "#created", true}
           ] = :mnesia.dirty_read(:area, new_area_name)
  end

  test "area edit page persists changes", %{area_name: area_name} do
    {:ok, view, html} = live(build_conn(), "/areas/#{area_name}/edit")

    assert html =~ "Edit Area"
    assert html =~ area_name

    view
    |> form("#resource-form", %{
      "change" => %{
        "region" => "US902",
        "slack_channel" => "#operations",
        "log_ignored" => "true"
      }
    })
    |> render_submit(%{"save-type" => "save"})

    assert_redirect(view, "/areas")

    assert [
             {:area, ^area_name, "US902", [], "#operations", true}
           ] = :mnesia.dirty_read(:area, area_name)
  end

  test "gateway list shows configured gateways", %{gateway_mac: gateway_mac} do
    {:ok, _view, html} = live(build_conn(), "/gateways")

    assert html =~ "Gateways"
    assert html =~ gateway_mac
  end

  test "gateway edit page persists configurable fields", %{
    gateway_mac: gateway_mac,
    area_name: area_name
  } do
    {:ok, view, html} = live(build_conn(), "/gateways/#{gateway_mac}/edit")

    assert html =~ "Edit Gateway"
    assert html =~ gateway_mac
    assert has_element?(view, "#gateway-location-map")

    view
    |> form("#resource-form", %{
      "change" => %{
        "area" => area_name,
        "tx_rfch" => "1",
        "ant_gain" => "4",
        "desc" => "Updated gateway",
        "latitude" => "55.0",
        "longitude" => "24.0",
        "gpsalt" => "120.5"
      }
    })
    |> render_submit(%{"save-type" => "save"})

    assert_redirect(view, "/gateways")

    key = :bumblebee_utils.hex_to_binary(gateway_mac)

    assert [
             {:gateway, ^key, ^area_name, 1, 4, "Updated gateway", {55.0, 24.0}, 120.5,
              :undefined, :undefined, :undefined, :undefined, [], [], _alerts, _decay, _reported,
              _next}
           ] = :mnesia.dirty_read(:gateway, key)
  end
end
