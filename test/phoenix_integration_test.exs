defmodule BumblebeeLns.PhoenixIntegrationTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint BumblebeeLnsWeb.Endpoint

  setup do
    area_name = "liveview-area-#{System.unique_integer([:positive])}"

    :ok =
      :mnesia.dirty_write({:area, area_name, "EU868", [], :undefined, true})

    on_exit(fn -> :mnesia.dirty_delete(:area, area_name) end)

    %{area_name: area_name}
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
end
