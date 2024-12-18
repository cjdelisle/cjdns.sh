# cjdns.sh

Shell script for auto-installing cjdns.

This script is meant to install cjdns, and keep it updated. It is accessible from https://pkt.cash/special/cjdns/cjdns.sh so you can run it as follows:

```bash
curl https://pkt.cash/special/cjdns/cjdns.sh | sh
```

Or:

```bash
wget -qO - https://pkt.cash/special/cjdns/cjdns.sh | sh
```

## Environment Variables

This script reacts to certain environment variables, variables which you will likely want to use include:

* `CJDNS_PORT`: The UDP port number which will be used for peering. This must be accessible from the outside. The default
port number is 3478.
* `CJDNS_PEERID`: For PKT yielding, you must set this to your ID as registered on the PKT dashboard.

Example:

```bash
curl https://pkt.cash/special/cjdns/cjdns.sh | CJDNS_PEERID=PUB_helloWorld sh
```

There are some additional env vars which you probably will not need:

* `CJDNS_SECONDARY`: If you set this to anything other than 'false', your cjdns node will be configured to run along side
another cjdns node on the same machine. This changes `CJDNS_TUN` default to false, and `CJDNS_ADMIN_PORT` to the
`CJDNS_PORT` plus one.
* `CJDNS_TUN`: If you set this to 'false', your cjdns node will not have a TUN device, and you will not be able to access the cjdns network.
* `CJDNS_PATH`: Where the cjdroute and cjdnstool binaries will be stored (default: `/usr/local/bin`)
* `CJDNS_CONF_PATH`: Where the cjdroute.conf will be stored (default: `/etc/cjdroute_${CJDNS_PORT}.conf`)
  * **NOTE:** Because the conf contains the port number, this will not interfere with other cjdns installations on the machine, however cjdns-sh is only capable of operating a single cjdns node.
* `CJDNS_SOCKET`: The name of the admin socket file (default: `cjdroute_${CJDNS_PORT}.sock`)
* `CJDNS_ADMIN_PORT`: The number of the cjdns admin port (default: `CJDNS_PORT + 1`)
  * **NOTE:** If you set this to 11234 then you can use cjdnstool without specifying the port.
* `CJDNS_IPV4`: Most of the time, cjdns is able to detect your public IP address on it's own, but in some cases
such as with advanced NAT configurations, you may need to manually configure your public address.
With the `CJDNS_IPV4` environment variable, you can manually set the IP only (`x.x.x.x`) or the port only
(`0.0.0.0:xxx`) or both the IP and port (`x.x.x.x:xxx`). Whichever part is not manually configured will be
automatically detected.
* `CJDNS_IPV6`: Like your IPv4 address, you can configure an IPv6 address. For address only, use `xxxx:xxxx::`,
for port only, use `[::]:xxx` and for IP+Port, use `[xxxx:xxxx::]:xxx`.

## How it works
When systemd/openrc launches cjdns, it runs `cjdns.sh`, causing it to check itself and update if necessary.
It also checks for updates of `cjdroute` and `cjdnstool`. Once all executables are up to date, it updates the
`cjdroute.conf` file to match its env vars and it runs cjdns.

When this script is run manually, either by `cjdns.sh` or by `curl https://pkt.cash/special/cjdns/cjdns.sh | sh`,
it does all of these things, but it also installs `/etc/systemd/system/cjdns-sh.service` or `/etc/init.d/cjdns-sh`
for systemd or openrc automatic startup. Finally it persists its env variables in `/etc/cjdns.sh.env` so that
they will be used on every launch.

So if you wish to change a setting like the admin port number, you can simply enter:

```bash
CJDNS_ADMIN_PORT=11234 cjdns.sh
```

And the script will re-run, check for updates, and then store the new port number.