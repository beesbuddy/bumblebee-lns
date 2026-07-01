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

  test "dashboard shows migrated traffic graph, events, frames, and server tables" do
    event_id = <<System.unique_integer([:positive])::64>>
    frame_id = <<System.unique_integer([:positive])::64>>
    devaddr = <<1, 2, 3, 4>>
    occurred_at = :calendar.universal_time()
    server_name = node()
    previous_server = :mnesia.dirty_read(:server, server_name)

    :ok =
      :mnesia.dirty_write(
        {:event, event_id, :error, occurred_at, occurred_at, 1, :server, node(), "Test incident",
         "dashboard"}
      )

    :ok =
      :mnesia.dirty_write(
        {:rxframe, frame_id, "up", "test-network", "test-app", devaddr, :undefined, [],
         :undefined, 14, 12, false, 1, <<1, 2, 3>>, occurred_at}
      )

    :ok =
      :mnesia.dirty_write({:server, server_name, [{occurred_at, {42, 3}}]})

    on_exit(fn ->
      :mnesia.dirty_delete(:event, event_id)
      :mnesia.dirty_delete(:rxframe, frame_id)

      case previous_server do
        [server] -> :mnesia.dirty_write(server)
        [] -> :mnesia.dirty_delete(:server, server_name)
      end
    end)

    {:ok, view, _html} = live(build_conn(), "/")

    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "Dashboard")
    assert has_element?(view, "#dashboard-traffic-graph")
    assert has_element?(view, "#dashboard-router-traffic-chart")

    assert has_element?(
             view,
             "#dashboard-traffic-graph-navigator[phx-hook='TrafficGraphNavigator'][data-chart-spec]"
           )

    assert has_element?(view, "#dashboard-traffic-window-1h")
    assert has_element?(view, "#dashboard-traffic-window-previous")
    assert has_element?(view, "#dashboard-traffic-zoom-in")
    assert has_element?(view, "#dashboard-traffic-zoom-out")

    assert has_element?(
             view,
             "#dashboard-observability-event-#{:bumblebee_utils.binary_to_hex(event_id)}"
           )

    assert has_element?(
             view,
             "#dashboard-observability-frame-#{:bumblebee_utils.binary_to_hex(frame_id)}"
           )

    assert has_element?(view, "#dashboard-servers")
    assert has_element?(view, "#dashboard-events")
    assert has_element?(view, "#dashboard-frames")
    assert has_element?(view, "#dashboard-event-#{:bumblebee_utils.binary_to_hex(event_id)}")
    assert has_element?(view, "#dashboard-frame-#{:bumblebee_utils.binary_to_hex(frame_id)}")

    view
    |> element("#dashboard-traffic-window-24h")
    |> render_click()

    assert has_element?(view, "#dashboard-router-traffic-chart")

    view
    |> element("#dashboard-traffic-zoom-in")
    |> render_click()

    assert has_element?(view, "#dashboard-traffic-window-6h.btn-primary")

    view
    |> element("#dashboard-traffic-zoom-out")
    |> render_click()

    assert has_element?(view, "#dashboard-traffic-window-24h.btn-primary")

    view
    |> element("#dashboard-traffic-graph-navigator")
    |> render_hook("zoom_traffic_window", %{"direction" => "in"})

    assert has_element?(view, "#dashboard-traffic-window-6h.btn-primary")

    view
    |> element("#dashboard-traffic-graph-navigator")
    |> render_hook("zoom_traffic_interval", %{"start" => 0.75, "end" => 1.0, "mode" => "in"})

    assert has_element?(view, "#dashboard-router-traffic-chart")
  end

  test "area list shows configured areas", %{area_name: area_name} do
    {:ok, view, html} = live(build_conn(), "/areas")

    assert has_element?(view, "#admin-breadcrumbs a[href='/']", "Dashboard")
    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "Areas")
    refute has_element?(view, "h1", "Areas")
    assert html =~ "Areas"
    assert html =~ area_name
    assert html =~ "EU 863-870MHz"
  end

  test "user list shows server users from the migrated admin section" do
    user_name = "liveview-user-#{System.unique_integer([:positive])}"
    user_key = :erlang.iolist_to_binary(user_name)

    :ok =
      :mnesia.dirty_write(
        {:user, user_key, "existing-ha1", [<<"unlimited">>], "user@example.com", true}
      )

    on_exit(fn ->
      :mnesia.dirty_delete(:user, user_key)
    end)

    {:ok, view, html} = live(build_conn(), "/users")

    assert has_element?(view, "#admin-breadcrumbs a[href='/']", "Dashboard")
    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "Users")
    refute has_element?(view, "h1", "Users")
    assert html =~ user_name
    assert html =~ "user@example.com"
  end

  test "connector list shows backend connectors from the migrated admin section" do
    connector_id = "liveview-connector-#{System.unique_integer([:positive])}"

    :ok =
      :mnesia.dirty_write(
        {:connector, connector_id, "test-app", "json", "mqtt://localhost", 1, "uplinks/{devaddr}",
         "events/{devaddr}", 0, "downlinks/{devaddr}", :undefined, true, [], "client-1", "basic",
         "user", "secret", :undefined, :undefined, [], 0, 0, :undefined}
      )

    on_exit(fn ->
      :mnesia.dirty_delete(:connector, connector_id)
    end)

    {:ok, view, html} = live(build_conn(), "/connectors")

    assert has_element?(view, "#admin-breadcrumbs a[href='/']", "Dashboard")
    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "Connectors")
    refute has_element?(view, "h1", "Connectors")
    assert html =~ connector_id
    assert html =~ "mqtt://localhost"
  end

  test "user new page persists a user with digest password hash" do
    user_name = "created-user-#{System.unique_integer([:positive])}"
    user_key = :erlang.iolist_to_binary(user_name)

    on_exit(fn ->
      :mnesia.dirty_delete(:user, user_key)
    end)

    {:ok, view, _html} = live(build_conn(), "/users/new")

    assert has_element?(view, "#admin-breadcrumbs a[href='/users']", "Users")
    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "New User")
    assert has_element?(view, "#resource-form")

    view
    |> form("#resource-form", %{
      "change" => %{
        "name" => user_name,
        "pass" => "secret",
        "scopes" => ["unlimited"],
        "email" => "created@example.com",
        "send_alerts" => "true"
      }
    })
    |> render_submit(%{"save-type" => "save"})

    assert_redirect(view, "/users")

    expected_ha1 =
      :bumblebee_http_digest.ha1({user_key, <<"bumblebee_lns">>, <<"secret">>})

    assert [
             {:user, ^user_key, ^expected_ha1, [<<"unlimited">>], "created@example.com", true}
           ] = :mnesia.dirty_read(:user, user_key)
  end

  test "area new page persists a new area" do
    new_area_name = "created-area-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      :mnesia.dirty_delete(:area, new_area_name)
    end)

    {:ok, view, _html} = live(build_conn(), "/areas/new")

    assert has_element?(view, "#admin-breadcrumbs a[href='/areas']", "Areas")
    assert has_element?(view, "#admin-breadcrumbs [aria-current='page']", "New Area")
    refute has_element?(view, "h1", "New Area")
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

  test "profile new page shows group field validation errors" do
    profile_name = "invalid-profile-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      :mnesia.dirty_delete(:profile, profile_name)
    end)

    {:ok, view, _html} = live(build_conn(), "/profiles/new")

    assert has_element?(view, "#resource-form")

    html =
      view
      |> form("#resource-form", %{
        "change" => %{
          "name" => profile_name,
          "group" => "",
          "app" => "test-app",
          "join" => "1",
          "adr_mode" => "0"
        }
      })
      |> render_submit(%{"save-type" => "save"})

    assert html =~ "There are errors in the form."
    assert html =~ "can&#39;t be blank"
  end

  test "profile form groups fields and explains accepted values" do
    {:ok, view, _html} = live(build_conn(), "/profiles/new")

    assert has_element?(view, "#resource-form legend", "General")
    assert has_element?(view, "#resource-form legend", "Activation")
    assert has_element?(view, "#resource-form legend", "ADR")
    assert has_element?(view, "#resource-form legend", "Status")
    assert has_element?(view, "#resource-form input[placeholder='default-profile']")
    assert has_element?(view, "#resource-form input[placeholder='16384']")
    assert has_element?(view, "#resource-form input[placeholder='5']")
    assert has_element?(view, "#resource-form", "ABP uses existing session keys")
  end

  test "profile group field is searchable" do
    group_name = "searchable-group-#{System.unique_integer([:positive])}"

    :ok =
      :mnesia.dirty_write({:group, group_name, "test-network", :undefined, [], :undefined, false})

    on_exit(fn ->
      :mnesia.dirty_delete(:group, group_name)
    end)

    {:ok, view, _html} = live(build_conn(), "/profiles/new")

    assert has_element?(
             view,
             "#resource-form [data-searchable-select] input[type='hidden'][name='change[group]'][data-searchable-select-value]"
           )

    assert has_element?(
             view,
             "#resource-form [data-searchable-select] input[type='text'][data-searchable-select-input]"
           )

    assert has_element?(
             view,
             "#resource-form [data-searchable-select] button[data-value='#{group_name}']"
           )
  end

  test "profile create context rejects group values that do not exist in mnesia" do
    profile_name = "missing-group-profile-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      :mnesia.dirty_delete(:profile, profile_name)
    end)

    assert {:error, %{group: "does not exist"}} =
             BumblebeeLns.Devices.create_profile(%{
               "name" => profile_name,
               "group" => "group-that-does-not-exist",
               "app" => "test-app",
               "join" => "1",
               "adr_mode" => "0"
             })

    assert [] = :mnesia.dirty_read(:profile, profile_name)
  end

  test "group form groups fields and explains accepted values" do
    {:ok, view, _html} = live(build_conn(), "/groups/new")

    assert has_element?(view, "#resource-form legend", "General")
    assert has_element?(view, "#resource-form legend", "Access")
    assert has_element?(view, "#resource-form legend", "Notifications")
    assert has_element?(view, "#resource-form input[placeholder='#lorawan-alerts']")

    assert has_element?(
             view,
             "#resource-form",
             "Allow devices in this group to complete OTAA joins"
           )

    assert has_element?(view, "#resource-form", "Use a channel name such as #lorawan-alerts")
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
