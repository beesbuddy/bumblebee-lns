defmodule BumblebeeLns.DashboardTest do
  use ExUnit.Case, async: true

  alias BumblebeeLns.Dashboard

  describe "router_traffic_chart/3" do
    test "builds chart data for traffic and observability markers" do
      occurred_at = {{2026, 6, 30}, {12, 0, 0}}

      chart =
        Dashboard.router_traffic_chart(
          [
            %{
              id: "server-1",
              server: "server",
              datetime: occurred_at,
              timestamp: "2026-06-30T12:00:00",
              label: "2026-06-30 12:00:00",
              short_label: "12:00",
              requests: 42,
              errors: 3
            }
          ],
          [
            %{
              id: "event-1",
              kind: :event,
              severity: "error",
              label: "Incident",
              detail: "dashboard",
              started_at: occurred_at,
              ended_at: occurred_at
            },
            %{
              id: "frame-1",
              kind: :frame,
              severity: "up",
              label: "01020304",
              detail: "1",
              started_at: occurred_at,
              ended_at: occurred_at
            }
          ],
          %{start_at: nil, end_at: nil}
        )

      assert chart.chart_spec["data"]["values"] == [
               %{
                 metric: "Requests per min",
                 server: "server",
                 timestamp: "2026-06-30T12:00:00",
                 value: 42
               },
               %{
                 metric: "Errors per min",
                 server: "server",
                 timestamp: "2026-06-30T12:00:00",
                 value: 3
               }
             ]

      assert [
               %{
                 id: "event-1",
                 kind: "event",
                 severity: "error",
                 icon: "Error",
                 label: "Incident"
               },
               %{
                 id: "frame-1",
                 kind: "frame",
                 severity: "up",
                 icon: "Frame",
                 label: "01020304"
               }
             ] = chart.chart_spec["observability"]["values"]
    end

    test "uses a low traffic y bound that gives distinct integer ticks" do
      occurred_at = {{2026, 6, 30}, {12, 0, 0}}

      chart =
        Dashboard.router_traffic_chart(
          [
            %{
              id: "server-1",
              server: "server",
              datetime: occurred_at,
              timestamp: "2026-06-30T12:00:00",
              label: "2026-06-30 12:00:00",
              short_label: "12:00",
              requests: 1,
              errors: 0
            }
          ],
          [],
          %{start_at: nil, end_at: nil}
        )

      assert chart.chart_spec["bounds"]["y_max"] == 4
    end
  end
end
