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
* `CJDNS_TUN`: If you set this to anything other than 'false', your cjdns node will have a TUN device, allowing you to access the network.
* `CJDNS_PEERID`: For PKT yielding, you must set this to your ID as registered on the PKT dashboard.

Example:

```bash
curl https://pkt.cash/special/cjdns/cjdns.sh | CJDNS_PEERID=PUB_helloWorld CJDNS_TUN=1 sh
```

There are some additional env vars which you probably will not need:

* `CJDNS_PATH`: Where the cjdroute and cjdnstool binaries will be stored (default: `/usr/local/bin`)
* `CJDNS_CONF_PATH`: Where the cjdroute.conf will be stored (default: `/etc/cjdroute_${CJDNS_PORT}.conf`)
  * **NOTE:** Because the conf contains the port number, this will not interfere with other cjdns installations on the machine, however cjdns-sh is only capable of operating a single cjdns node.
* `CJDNS_SOCKET`: The name of the admin socket file (default: `cjdroute_${CJDNS_PORT}.sock`)
* `CJDNS_ADMIN_PORT`: The number of the cjdns admin port (default: `CJDNS_PORT + 1`)
  * **NOTE:** If you set this to 11234 then you can use cjdnstool without specifying the port.

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