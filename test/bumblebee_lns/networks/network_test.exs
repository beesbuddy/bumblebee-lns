defmodule BumblebeeLns.Networks.NetworkTest do
  use ExUnit.Case, async: true

  alias BumblebeeLns.Networks.Network

  test "changeset normalizes and validates legacy network fields" do
    changeset =
      Network.changeset(%Network{}, %{
        "name" => " test-network ",
        "netid" => " 0123ab ",
        "region" => "EU868",
        "tx_codr" => "4/5",
        "join1_delay" => "5",
        "join2_delay" => "6",
        "rx1_delay" => "1",
        "rx2_delay" => "2",
        "gw_power" => "16",
        "max_eirp" => "16",
        "max_power" => "0",
        "min_power" => "5",
        "max_datr" => "5",
        "dcycle_init" => "0",
        "rx1_dr_offset" => "0",
        "rx2_dr" => "0",
        "rx2_freq" => "869.525",
        "init_chans" => "0-2, 5",
        "cflist" => "867.1, 0, 5"
      })

    assert changeset.valid?
    network = Ecto.Changeset.apply_changes(changeset)

    assert network.name == "test-network"
    assert network.netid == "0123AB"
  end

  test "changeset rejects invalid channel syntax" do
    changeset =
      Network.changeset(%Network{}, %{
        "name" => "test-network",
        "netid" => "000000",
        "region" => "EU868",
        "tx_codr" => "4/5",
        "join1_delay" => "5",
        "join2_delay" => "6",
        "rx1_delay" => "1",
        "rx2_delay" => "2",
        "gw_power" => "16",
        "max_eirp" => "16",
        "max_power" => "0",
        "min_power" => "5",
        "max_datr" => "5",
        "dcycle_init" => "0",
        "rx1_dr_offset" => "0",
        "rx2_dr" => "0",
        "rx2_freq" => "869.525",
        "init_chans" => "two"
      })

    refute changeset.valid?

    assert {"must be channel intervals like 0-2, 5-7", []} in Keyword.get_values(
             changeset.errors,
             :init_chans
           )
  end
end
