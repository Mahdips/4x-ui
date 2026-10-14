#!/bin/bash
#
# 4X-UI quick install.
#
# Upstream 3x-ui ships a prebuilt release archive; this fork does not publish
# releases yet, so the installer builds the panel from source on the server:
# it installs Go + Node, clones the repo, compiles the frontend and backend,
# and wires up the systemd service. Re-running it upgrades an existing install.
#
# Usage:
#   bash <(curl -Ls https://raw.githubusercontent.com/Mahdips/4x-ui/main/install.sh)
#
# Environment variables:
#   XUI_MAIN_FOLDER   install prefix          (default /usr/local/x-ui)
#   XUI_SERVICE       systemd unit folder     (default /etc/systemd/system)
#   XUI_REPO          git source URL          (default Mahdips/4x-ui)
#   XUI_BRANCH        branch/commit/tag       (default main)
#   XUI_SKIP_FAIL2BAN set to 1 to skip fail2ban setup
#
# A database at /etc/x-ui/x-ui.db is left untouched; settings are read from
# /etc/default/x-ui if it exists.

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"
xui_repo="${XUI_REPO:-https://github.com/Mahdips/4x-ui.git}"
xui_branch="${XUI_BRANCH:-main}"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo -e "${green}The OS release is: ${release}${plain}"

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${red}Unsupported CPU architecture! ${plain}" && exit 1 ;;
    esac
}

echo -e "${green}Arch: $(arch)${plain}"

# Non-interactive mode: triggered explicitly via XUI_NONINTERACTIVE=1, or
# implicitly when stdin is not a TTY (e.g. `curl ... | bash`, cloud-init).
if [[ "${XUI_NONINTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
    NONINTERACTIVE=1
else
    NONINTERACTIVE=0
fi
export NONINTERACTIVE

confirm() {
    if [[ x"${NONINTERACTIVE}" == x"1" ]]; then
        return 0
    fi
    read -rp "$1 [y/n] " choices
    case "$choices" in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Make sure the build toolchain is present: Go for the backend, Node/npm for
# the frontend. Both are installed from the system package manager when they
# are missing or too old.
install_dependencies() {
    if [[ x"${release}" == x"centos" || x"${release}" == x"rocky" || x"${release}" == x"almalinux" || x"${release}" == x"rhel" || x"${release}" == x"oracle" || x"${release}" == x"amzn" ]]; then
        dnf install -y wget curl tar git || yum install -y wget curl tar git
    else
        apt-get update -y
        apt-get install -y wget curl tar git build-essential
    fi

    # Go: the panel needs a recent toolchain. Install from go.dev when the
    # system package is missing or older than 1.24.
    need_go=1
    if command -v go >/dev/null 2>&1; then
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        major_minor=$(echo "$go_version" | cut -d. -f1,2)
        if [[ $(printf '%s\n' "1.24" "$major_minor" | sort -V | head -n1) == "1.24" ]]; then
            need_go=0
            echo -e "${green}Found Go ${go_version}, sufficient${plain}"
        fi
    fi
    if [[ $need_go == 1 ]]; then
        # Find the newest stable Go for this arch. go.dev/dl/?mode=json lists
        # every version; the first non-beta/rc filename for our platform wins.
        goarch=$(arch)
        [[ "$goarch" == "armv7" ]] && goarch="armv6"
        [[ "$goarch" == "armv5" ]] && goarch="armv6"
        go_filename=$(curl -fsSL --retry 3 "https://go.dev/dl/?mode=json&include=all" |
            grep -oE "go[0-9]+\.[0-9]+(\.[0-9]+)?\.linux-${goarch}\.tar\.gz" | head -n1)
        if [[ -z "$go_filename" ]]; then
            echo -e "${red}Could not resolve a Go toolchain for ${goarch}${plain}"
            exit 1
        fi
        echo -e "${green}Installing ${go_filename}${plain}"
        rm -rf /usr/local/go
        curl -fsSL --retry 3 -o /tmp/go-toolchain.tar.gz "https://go.dev/dl/${go_filename}"
        tar -C /usr/local -xzf /tmp/go-toolchain.tar.gz
        rm -f /tmp/go-toolchain.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        grep -q "/usr/local/go/bin" /etc/profile 2>/dev/null ||
            echo 'export PATH=$PATH:/usr/local/go/bin' >>/etc/profile
    fi

    # Node: the frontend build needs npm. Use the system package, or fall back
    # to the NodeSource binary tarball when the distro ships something ancient.
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        if [[ x"${release}" == x"centos" || x"${release}" == x"rocky" || x"${release}" == x"almalinux" || x"${release}" == x"rhel" || x"${release}" == x"oracle" || x"${release}" == x"amzn" ]]; then
            if [[ x"${NONINTERACTIVE}" != x"1" ]] && ! command -v node >/dev/null 2>&1; then
                echo -e "${yellow}Node.js is required to build the frontend.${plain}"
                if confirm "Install Node.js 22.x from NodeSource?"; then
                    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
                    dnf install -y nodejs || yum install -y nodejs
                fi
            else
                dnf install -y nodejs || yum install -y nodejs
            fi
        else
            if [[ x"${NONINTERACTIVE}" != x"1" ]] && ! command -v node >/dev/null 2>&1; then
                echo -e "${yellow}Node.js is required to build the frontend.${plain}"
                if confirm "Install Node.js 22.x from NodeSource?"; then
                    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
                    apt-get install -y nodejs
                fi
            else
                apt-get install -y nodejs
            fi
        fi
    fi
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        echo -e "${red}Node.js/npm is still missing; cannot build the frontend${plain}"
        exit 1
    fi
    echo -e "${green}Node $(node -v), npm $(npm -v)${plain}"
}

# fail2ban enforces the per-client IP limit feature. Optional.
setup_fail2ban() {
    if [[ x"${XUI_SKIP_FAIL2BAN:-0}" == x"1" ]]; then
        echo -e "${yellow}Skipping fail2ban (XUI_SKIP_FAIL2BAN=1)${plain}"
        return 0
    fi
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        if [[ x"${release}" == x"centos" || x"${release}" == x"rocky" || x"${release}" == x"almalinux" || x"${release}" == x"rhel" || x"${release}" == x"oracle" || x"${release}" == x"amzn" ]]; then
            dnf install -y epel-release fail2ban || yum install -y epel-release fail2ban
        else
            apt-get install -y fail2ban
        fi
    fi
    if command -v fail2ban-client >/dev/null 2>&1; then
        cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd
EOF
        systemctl enable fail2ban
        systemctl restart fail2ban
        echo -e "${green}fail2ban installed and running${plain}"
    else
        echo -e "${yellow}fail2ban not available; per-client IP limits will not be enforced${plain}"
    fi
}

# The systemd unit. The panel reads its config from /etc/default/x-ui when
# present, so an existing install keeps its database path and env vars.
install_service() {
    if [[ ! -f ${xui_service}/x-ui.service ]]; then
        cat >${xui_service}/x-ui.service <<EOF
[Unit]
Description=4X-UI Service
Documentation=https://github.com/Mahdips/4x-ui
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/x-ui
EnvironmentFile=/etc/default/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        chmod 644 ${xui_service}/x-ui.service
        chown root:root ${xui_service}/x-ui.service
        systemctl daemon-reload
        systemctl enable x-ui
        echo -e "${green}x-ui.service installed${plain}"
    fi
}

# Build the panel from source and install it into ${xui_folder}.
install_x-ui() {
    build_dir=$(mktemp -d)
    trap 'rm -rf ${build_dir}' EXIT

    echo -e "${green}Cloning ${xui_repo} (${xui_branch})...${plain}"
    if ! git clone --depth 1 --branch "${xui_branch}" "${xui_repo}" "${build_dir}/4x-ui"; then
        echo -e "${red}Failed to clone the source repository${plain}"
        exit 1
    fi
    src=${build_dir}/4x-ui

    echo -e "${green}Building the frontend...${plain}"
    cd ${src}/frontend
    if ! npm install --no-audit --no-fund; then
        echo -e "${red}npm install failed${plain}"
        exit 1
    fi
    if ! npm run build; then
        echo -e "${red}frontend build failed${plain}"
        exit 1
    fi
    cd ${src}

    echo -e "${green}Building the panel binary...${plain}"
    export CGO_ENABLED=1
    if ! go build -o x-ui main.go; then
        echo -e "${red}go build failed${plain}"
        exit 1
    fi
    if [[ ! -s x-ui ]]; then
        echo -e "${red}The build did not produce the x-ui binary${plain}"
        exit 1
    fi

    # Stop the running panel before swapping files, then back up the current
    # install so a failed cutover can be rolled back.
    systemctl stop x-ui 2>/dev/null
    if [[ -d ${xui_folder} ]]; then
        backup=${xui_folder}.bak.$(date +%s)
        cp -a ${xui_folder} "${backup}"
        echo -e "${green}Backed up the previous install to ${backup}${plain}"
    fi

    mkdir -p ${xui_folder}/bin
    cp x-ui ${xui_folder}/x-ui
    chmod +x ${xui_folder}/x-ui

    # Ship the management script and service files shipped in the repo.
    if [[ -f ${src}/x-ui.sh ]]; then
        cp ${src}/x-ui.sh ${xui_folder}/x-ui.sh
        chmod +x ${xui_folder}/x-ui.sh
    fi
    if [[ -f ${src}/x-ui.rc ]]; then
        cp ${src}/x-ui.rc ${xui_folder}/x-ui.rc
    fi
    for f in x-ui.service.debian x-ui.service.arch x-ui.service.rhel; do
        if [[ -f ${src}/${f} ]]; then
            cp ${src}/${f} ${xui_folder}/${f}
        fi
    done

    # The release archives bundle Xray; a source build is not allowed to
    # redistribute it, so fetch the core from the Xray-core releases. An
    # already-present core (fresh install on top of an old one, or a hand
    # placed binary) is never overwritten.
    xray_arch=$(arch)
    [[ "$xray_arch" == "armv7" || "$xray_arch" == "armv6" || "$xray_arch" == "armv5" ]] && xray_arch="arm32"
    xray_version=$(curl -fsSL --retry 3 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" |
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -n "$xray_version" ]] && [[ ! -f ${xui_folder}/bin/xray-linux-$(arch) ]]; then
        echo -e "${green}Fetching Xray-core ${xray_version}...${plain}"
        curl -fL --retry 3 -o /tmp/xray-bin.zip "https://github.com/XTLS/Xray-core/releases/download/${xray_version}/Xray-linux-$(arch).zip"
        if [[ -s /tmp/xray-bin.zip ]] && unzip -o /tmp/xray-bin.zip -d /tmp/xray-extract >/dev/null 2>&1; then
            cp /tmp/xray-extract/xray ${xui_folder}/bin/xray-linux-$(arch)
            chmod +x ${xui_folder}/bin/xray-linux-$(arch)
        fi
        rm -f /tmp/xray-bin.zip
        rm -rf /tmp/xray-extract
    fi

    # Default env file for the panel (database location).
    if [[ ! -f /etc/default/x-ui ]]; then
        mkdir -p /etc/x-ui
        cat >/etc/default/x-ui <<EOF
XUI_DB_TYPE=sqlite
XUI_DB_FOLDER=/etc/x-ui
EOF
    fi

    install_service
    setup_fail2ban

    systemctl start x-ui
    sleep 2
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}4X-UI installed and running${plain}"
    else
        echo -e "${red}The service did not start; check 'journalctl -u x-ui'${plain}"
        exit 1
    fi

    echo -e ""
    echo -e "${green}If this is a fresh install, the panel creates a random admin"
    echo -e "username/password on first boot and prints them to the service log:"
    echo -e "  journalctl -u x-ui | grep -iE 'username|password'${plain}"
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐"
    echo -e "│  ${blue}x-ui${plain}              - Admin Management Script          │"
    echo -e "│  ${blue}x-ui start${plain}        - Start                            │"
    echo -e "│  ${blue}x-ui stop${plain}         - Stop                             │"
    echo -e "│  ${blue}x-ui restart${plain}      - Restart                          │"
    echo -e "│  ${blue}x-ui status${plain}       - Current Status                   │"
    echo -e "│  ${blue}x-ui settings${plain}     - Current Settings                 │"
    echo -e "│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │"
    echo -e "│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │"
    echo -e "│  ${blue}x-ui log${plain}          - Check logs                       │"
    echo -e "│  ${blue}x-ui update${plain}       - Update                           │"
    echo -e "│  ${blue}x-ui uninstall${plain}    - Uninstall                        │"
    echo -e "└───────────────────────────────────────────────────────┘"
}

echo -e "${green}Running...${plain}"
install_dependencies
install_x-ui
