# Expose Udp during local development

This guide explains how to expose the LoRaWAN UDP listener (`1680/udp`) for
local development only.

## Goal

Open `1680/udp` temporarily so gateways on your LAN can reach the server,
without making a permanent firewall change.

## Check that the server listens on UDP 1680

```bash
ss -lunp | rg ':1680\b'
```

Expected output should include `0.0.0.0:1680` (or your interface IP) and the
`beam.smp` process.

## Firewalld (runtime-only, not permanent)

1. Find your active zone and interface:

```bash
sudo firewall-cmd --get-active-zones
```

2. Open port `1680/udp` in that zone for runtime only:

```bash
sudo firewall-cmd --zone=<your-zone> --add-port=1680/udp
```

3. Verify:

```bash
sudo firewall-cmd --zone=<your-zone> --query-port=1680/udp
sudo firewall-cmd --zone=<your-zone> --list-ports
```

Use `--add-port` without `--permanent` to keep the change temporary.

## Close the port again

```bash
sudo firewall-cmd --zone=<your-zone> --remove-port=1680/udp
sudo firewall-cmd --zone=<your-zone> --query-port=1680/udp
```

## Optional: auto-close on shell exit

This opens the port and removes it automatically when your terminal session
ends:

```bash
export FW_ZONE=<your-zone>
sudo firewall-cmd --zone="$FW_ZONE" --add-port=1680/udp
trap 'sudo firewall-cmd --zone="$FW_ZONE" --remove-port=1680/udp' EXIT
```

## Trace packet forwarder traffic

### Network-level trace (quick check)

Use `tcpdump` to confirm packets are reaching the server:

```bash
sudo tcpdump -ni any udp port 1680 -vv
```

Useful filters:

```bash
# only incoming to server
sudo tcpdump -ni any 'udp dst port 1680' -vv

# only one gateway
sudo tcpdump -ni any 'host <gateway-ip> and udp port 1680' -vv
```

### Erlang-level trace (inside bumblebee)

Open an Erlang console attached to the running node:

```bash
bin/bumblebee remote_console
```

Then trace the `lorawan_gw_forwarder` process:

```erlang
Pid = whereis(lorawan_gw_forwarder).
sys:get_state(Pid).

dbg:tracer().
dbg:p(Pid, [r]).
dbg:tpl(lorawan_gw_forwarder, handle_info, 2, [{'_', [], [{return_trace}]}]).
```

Expected packet types in traces:
- `<<Version, Token:16, 0, ...>>` = `PUSH_DATA`
- `<<Version, Token:16, 2, ...>>` = `PULL_DATA`
- `<<Version, Token:16, 5, ...>>` = `TX_ACK`

Stop tracing:

```erlang
dbg:stop_clear().
```

## Notes

- Runtime rules are not permanent and are not written to disk.
- Runtime rules are usually cleared by firewall reload/restart/reboot.
- User logout does not always remove runtime rules unless you explicitly remove
  them (or use the `trap` method above).
