#!/bin/sh

if [ -e /etc/cjdns.sh.env ] ; then
    . "/etc/cjdns.sh.env"
fi

: "${CJDNS_PATH:=/usr/local/bin}"
: "${CJDNS_PORT:=3478}"
: "${CJDNS_CONF_PATH:=/etc/cjdroute_${CJDNS_PORT}.conf}"
: "${CJDNS_SOCKET:=cjdroute_${CJDNS_PORT}.sock}"
: "${CJDNS_TUN:=false}"
if [ -z "$CJDNS_ADMIN_PORT" ]; then
    CJDNS_ADMIN_PORT=$((CJDNS_PORT + 1))
fi

cjdns_sh_env() {
    echo "#!/bin/sh"
    echo ": \"\${CJDNS_PATH:=$CJDNS_PATH}\""
    echo ": \"\${CJDNS_PORT:=$CJDNS_PORT}\""
    echo ": \"\${CJDNS_CONF_PATH:=$CJDNS_CONF_PATH}\""
    echo ": \"\${CJDNS_SOCKET:=$CJDNS_SOCKET}\""
    echo ": \"\${CJDNS_TUN:=$CJDNS_TUN}\""
}

die() {
    echo "ERROR: $1"
    exit 100
}
need() {
    if ! command -v "$1" >/dev/null ; then
        die "Need $1"
    fi
}
dlod() {
    if command -v wget >/dev/null ; then
        wget -Qo - "$1"        
    elif command -v curl >/dev/null ; then
        curl "$1"
    else
        die "Need either wget or curl"
    fi
}

check() {
    need uname
    need tar
    need sha256sum
    need cut
    need chmod
    need grep
    need jq

    if command -v wget >/dev/null ; then
        true
    elif command -v curl >/dev/null ; then
        true
    else
        die "Need either wget or curl"
    fi
    if ! [ "$(id -u)" = '0' ] ; then
        die "This script must be run as root"
    fi
}

do_manifest() {
    download_path=$1
    dlod "$download_path/manifest.txt" | while read -r line; do
        hash="$(echo "$line" | cut -f 1 -d ' ')"
        file="$(echo "$line" | cut -f 3 -d ' ')"
        if ! [ "$file" = "" ] ; then
            if [ -e "$CJDNS_PATH/$file" ] ; then
                if ! [ "$(sha256sum "$CJDNS_PATH/$file" 2>/dev/null | cut -f 1 -d ' ')" = "$hash" ] ; then
                    echo "File $file has different hash (likely update) - re-downloading"
                    rm "$CJDNS_PATH/$file" 2>/dev/null
                fi
            fi
            if ! [ -e "$CJDNS_PATH/$file" ] ; then
                dlod "$download_path/$file" > "$CJDNS_PATH/$file"
            fi
            chmod a+x "$CJDNS_PATH/$file"
        fi
    done
}

update() {
    libc=$1
    # raw.githubusercontent.com/cjdelisle/cjdns.sh/refs/heads/main
    do_manifest "https://pkt.cash/special/cjdns"
    do_manifest "https://pkt.cash/special/cjdns/binaries/$(uname -s)-$(uname -m)-$libc"
    if ! [ -e "/etc/cjdns.sh.env" ] ; then
        cjdns_sh_env > "/etc/cjdns.sh.env"
    fi
}

mk_conf() {
    if ! [ -e "$CJDNS_CONF_PATH" ] ; then
        cjdroute --genconf > "$CJDNS_CONF_PATH" || die "Unable to launch cjdns"
    fi
}

update_conf() {
    tun_iface='del(.router.interface)'
    if ! [ "$CJDNS_TUN" = "false" ] ; then
        tun_iface='(.router.interface) |= {"type":"TUNInterface"}'
    fi
    cjdroute --cleanconf < "$CJDNS_CONF_PATH" | jq "\
        (.interfaces.UDPInterface[0].bind) |= \"0.0.0.0:$CJDNS_PORT\" | \
        (.interfaces.UDPInterface[1].bind) |= \"[::]:$CJDNS_PORT\" | \
        (.admin.bind) |= \"127.0.0.1:$CJDNS_ADMIN_PORT\" | \
        (.router.publicPeer) |= \"$USER_CODE\" | \
        (.pipe) |= \"$CJDNS_SOCKET\" | \
        (.noBackground) |= 1 | \
        $tun_iface" > "$CJDNS_CONF_PATH.upd"
    mv "$CJDNS_CONF_PATH.upd" "$CJDNS_CONF_PATH"
}

install_launcher_systemd() {
    need systemctl
        echo '
[Unit]
Description=cjdns.sh: Automated cjdns installer and runner
Wants=network.target
After=network-pre.target
Before=network.target network.service

[Service]
ProtectHome=true
ProtectSystem=true
SyslogIdentifier=cjdroute
ExecStart=/usr/local/bin/cjdns.sh exec
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
' > "/usr/lib/systemd/system/cjdns-sh.service"
    systemctl enable cjdns-sh.service
    systemctl start cjdns-sh.service
}

install_launcher_openrc() {
    echo '
#!/sbin/openrc-run

description="Automated cjdns installer and runner"

command="/usr/local/bin/cjdns.sh"
command_args="exec"
command_user="root"  # Adjust the user as needed

depend() {
    need net
    before net
}

supervisor=supervise-daemon
output_log="/var/log/cjdns.log"
error_log="/var/log/cjdns.log"
pidfile="/var/run/cjdns.pid"
respawn_delay=5
respawn_max=0  # Unlimited respawns, similar to `Restart=always` in systemd

start_pre() {
    ebegin "Starting cjdns service"
}

stop_pre() {
    ebegin "Stopping cjdns service"
}

start() {
    ebegin "Running cjdns.sh"
    supervise-daemon --start cjdns --pidfile "$pidfile" --respawn --respawn-delay $respawn_delay --stdout "$output_log" --stderr "$error_log" -- "$command" "$command_args"
    eend $?
}

stop() {
    ebegin "Stopping cjdns"
    supervise-daemon --stop cjdns --pidfile "$pidfile"
    eend $?
}
' > /etc/init.d/cjdns
    chmod a+x /etc/init.d/cjdns
    rc-update add cjdns default
    rc-service cjdns start
}

install_launcher() {
    if [ -e /usr/lib/systemd/system ] ; then
        install_launcher_systemd
    elif command -v rc-service >/dev/null 2>/dev/null ; then
        install_launcher_openrc
    fi
}

main() {
    check

    if ldd /bin/sh | grep -q 'libc.so.6'; then
        libc="GNU"
    elif ldd /bin/sh | grep -q 'musl'; then
        libc="MUSL"
    else
        die "Only glibc or musl libc are supported"
    fi

    update "$libc"
    mk_conf
    update_conf

    for arg in "$@"; do
        if [ "$arg" = "exec" ]; then
            exec cjdroute < "$CJDNS_CONF_PATH"
            exit 100
        fi
    done

    # We check and install the launcher only if we're not being launched from it
    install_launcher
}
main "$@"