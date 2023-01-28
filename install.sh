#!/usr/bin/env bash

# export check_all_service_files='yes'
# change "DOWNLOAD_LINK" in '230' line

# export DAT_PATH='/etc/clash'
DAT_PATH=${DAT_PATH:-/etc/clash}

# export CLASH_PATH='/etc/systemd/system/'
CLASH_PATH=${CLASH_PATH:-/etc/systemd/system}

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}

systemd_cat_config() {
  if systemd-analyze --help | grep -qw 'cat-config'; then
    systemd-analyze --no-pager cat-config "$@"
    echo
  else
    echo "${aoi}~~~~~~~~~~~~~~~~"
    cat "$@" "$1".d/*
    echo "${aoi}~~~~~~~~~~~~~~~~"
    echo "${red}warning: ${green}The systemd version on the current operating system is too low."
    echo "${red}warning: ${green}Please consider to upgrade the systemd or the operating system.${reset}"
    echo
  fi
}

check_if_running_as_root() {
  if [[ "$UID" -ne '0' ]]; then
    echo "WARNING: The user currently executing this script is not root. You may encounter the insufficient privilege error."
    read -r -p "Are you sure you want to continue? [y/n] " cont_without_been_root
    if [[ x"${cont_without_been_root:0:1}" = x'y' ]]; then
      echo "Continuing the installation with current user..."
    else
      echo "Not running with root, exiting..."
      exit 1
    fi
  fi
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='i386'
        ;;
      'amd64' | 'x86_64')
        MACHINE='amd64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'arm64' | 'aarch64')
        MACHINE='arm64'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

user_parameters() {
  while [[ "$#" -gt '0' ]]; do
    case "$1" in
      '--remove' | '-r')
        if [[ "$#" -gt '1' ]]; then
          echo 'error: Please enter the correct parameters.'
          exit 1
        fi
        REMOVE='1'
        ;;
      '--check' | '-c')
        CHECK='1'
        break
        ;;
      '--help' | '-h')
        HELP='1'
        break
        ;;
      '--local' | '-l')
        LOCAL_INSTALL='1'
        LOCAL_FILE="${2:?error: Please specify the correct local file.}"
        break
        ;;
      *)
        echo "$0: unknown option -- -"
        exit 1
        ;;
    esac
    shift
  done
}

install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name"; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

get_current_version() {
  if /usr/local/bin/clash -v >/dev/null 2>&1;then
    VERSION="$(/usr/local/bin/clash -v | awk 'NR==1 {print $2}')"
  else
    echo "info: clash not found!"
  fi
  CURRENT_VERSION="v${VERSION#v}"
}

get_version() {
  # 0: Install or update Clash.
  # 1: Installed or no new version of Clash.
  # 2: Install the specified version of Clash.
  if [[ -n "$VERSION" ]]; then
    RELEASE_VERSION="v${VERSION#v}"
    return 2
  fi
  # Determine the version number for Clash installed from a local file
  if [[ -f '/usr/local/bin/clash' ]]; then
    get_current_version
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
      RELEASE_VERSION="$CURRENT_VERSION"
      return
    fi
  fi
  # Get Clash release version number
  RELEASE_VERSION="v1.12.0"
  # Compare Clash version numbers
  if [[ "$RELEASE_VERSION" != "$CURRENT_VERSION" ]]; then
    RELEASE_VERSIONSION_NUMBER="${RELEASE_VERSION#v}"
    RELEASE_MAJOR_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER%%.*}"
    RELEASE_MINOR_VERSION_NUMBER="$(echo "$RELEASE_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
    RELEASE_MINIMUM_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER##*.}"
    CURRENT_VERSION_NUMBER="$(echo "${CURRENT_VERSION#v}" | sed 's/-.*//')"
    CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSION_NUMBER%%.*}"
    CURRENT_MINOR_VERSION_NUMBER="$(echo "$CURRENT_VERSION_NUMBER" | awk -F '.' '{print $2}')"
    CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSION_NUMBER##*.}"
    if [[ "$RELEASE_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      return 0
    elif [[ "$RELEASE_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      if [[ "$RELEASE_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        return 0
      elif [[ "$RELEASE_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        if [[ "$RELEASE_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
          return 0
        else
          return 1
        fi
      else
        return 1
      fi
    else
      return 1
    fi
  elif [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
    return 1
  fi
}

download_clash() {
  # DOWNLOAD_LINK="https://github.com/HasturBoss/Tunnel/releases/download/$RELEASE_VERSION/clash-linux-$MACHINE.zip"
  DOWNLOAD_LINK="https://gitee.com/HasturBoss/Tunnel/releases/download/$RELEASE_VERSION/clash-linux-$MACHINE.zip"
  echo "Downloading Clash archive: $DOWNLOAD_LINK"
  if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  echo "Downloading verification file for Clash archive: $DOWNLOAD_LINK.dgst"
  if ! curl -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
    echo 'error: This version does not support verification. Please replace with another version.'
    return 1
  fi
  # Verification of V2Ray archive
  CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' < "${ZIP_FILE}.dgst")
  LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
  if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
    echo 'info: SHA256 does not match, may be modified!'
  fi
}

decompression() {
  if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
    echo 'error: Clash decompression failed.'
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the Clash package to $TMP_DIRECTORY and prepare it for installation."
}

install_file() {
  NAME="$1"
  if [[ "$NAME" == 'clash' ]]; then
    PACKAGE="${NAME}-linux-${MACHINE}"
    CLASH="/usr/local/bin/clash"
    # Install Clash /path/to/bin
    install -m 755 "${TMP_DIRECTORY}/$PACKAGE" "$CLASH"
  elif [[ "$NAME" == 'Country.mmdb' ]]; then
    # Install Clash Country.mmdb
    install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  elif [[ "$NAME" == 'config.yaml' ]]; then
    # Install Clash config.yaml
    install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  elif [[ "$NAME" == 'clash.service' ]]; then
    # Install Clash clash.service
    install -m 644 "${TMP_DIRECTORY}/$NAME" "${CLASH_PATH}/$NAME"
  fi
}

install_clash() {
  install -d "$DAT_PATH"
  install_file clash
  install -d "${DAT_PATH}/folder"
  # If the file exists, Country.mmdb will not be installed or updated
  if [[ ! -f "${DAT_PATH}/Country.mmdb" ]]; then
    install_file Country.mmdb
  fi
  # Install Clash configuration file to $DAT_PATH
  if [[ ! -f "${DAT_PATH}/config.yaml" ]]; then
    install_file config.yaml
  fi
}

install_startup_service_file() {
  # If the file exists, clash.service will not be installed or updated
  if [[ ! -f "${CLASH_PATH}/clash.service" ]]; then
    install_file clash.service
  fi
  echo "info: Systemd service files have been installed successfully!"
  echo "${red}warning: ${green}The following are the actual parameters for the v2ray service startup."
  echo "${red}warning: ${green}Please make sure the configuration file path is correctly set.${reset}"
  systemd_cat_config "${CLASH_PATH}/clash.service"
  systemctl daemon-reload
  SYSTEMD='1'
}

start_clash() {
  if [[ -f "${CLASH_PATH}/clash.service" ]]; then
    if systemctl start "${CLASH_CUSTOMIZE:-clash}"; then
      echo 'info: Start the Clash service.'
    else
      echo 'error: Failed to start Clash service.'
      exit 1
    fi
  fi
}

stop_clash() {
  CLASH_CUSTOMIZE="$(systemctl list-units | grep 'clash' | awk -F ' ' '{print $1}')"
  if [[ -z "$CLASH_CUSTOMIZE" ]]; then
    local clash_daemon_to_stop='clash.service'
  else
    local clash_daemon_to_stop="$CLASH_CUSTOMIZE"
  fi
  if ! systemctl stop "$clash_daemon_to_stop"; then
    echo 'error: Stopping the Clash service failed.'
    exit 1
  fi
  echo 'info: Stop the Clash service.'
}

check_update() {
  if [[ -f "${CLASH_PATH}/clash.service" ]]; then
    get_version
    local get_ver_exit_code=$?
    if [[ "$get_ver_exit_code" -eq '0' ]]; then
      echo "info: Found the latest release of Clash $RELEASE_VERSION . (Current release: $CURRENT_VERSION)"
    elif [[ "$get_ver_exit_code" -eq '1' ]]; then
      echo "info: No new version. The current version of Clash is $CURRENT_VERSION ."
    fi
    exit 0
  else
    echo 'error: Clash is not installed.'
    exit 1
  fi
}

remove_clash() {
  if [[ -n "$(pidof clash)" ]] || [[ -z "$(pidof clash)" ]]; then
    stop_clash
    "rm" "${CLASH_PATH}/clash.service"
    echo -e "\033[31mManually remove clash: /usr/local/bin/clash\033[0m"
    "rm" -rf "${DAT_PATH}"
  else
    echo 'error: Clash is not installed.'
    exit 1
  fi
}

# Explanation of parameters in the script
show_help() {
  echo "usage: $0 [--remove | --help]"
  echo 'Clash: [--version number | -l | -c | -r | -h ]'
  echo '  -l, --local     Install Clash from a local file'
  echo '  -c, --check     Check if Clash can be updated'
  echo '  -r, --remove    Remove Clash'
  echo '  -h, --help      Show help'
  exit 0
}

main() {
  check_if_running_as_root
  identify_the_operating_system_and_architecture
  user_parameters "$@"
  install_software "$package_provide_tput" 'tput'
  red=$(tput setaf 1)
  green=$(tput setaf 2)
  aoi=$(tput setaf 6)
  reset=$(tput sgr0)
  # Parameter information
  [[ "$HELP" -eq '1' ]] && show_help
  [[ "$CHECK" -eq '1' ]] && check_update
  [[ "$REMOVE" -eq '1' ]] && remove_clash
  # Two very important variables
  TMP_DIRECTORY="$(mktemp -d)"
  ZIP_FILE="${TMP_DIRECTORY}/clash-linux-$MACHINE.zip"
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
    echo 'warn: Install Clash from a local file, but still need to make sure the network is available.'
    echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
    read -r
    install_software 'unzip' 'unzip'
    decompression "$LOCAL_FILE"
  else
    # Normal way
    install_software 'curl' 'curl'
    get_version
    NUMBER="$?"
    if [[ "$NUMBER" -eq '0' ]] || [[ "$NUMBER" -eq 2 ]]; then
      echo "info: Installing Clash $RELEASE_VERSION for $(uname -m)"
      download_clash
      if [[ "$?" -eq '1' ]]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
      fi
      install_software 'unzip' 'unzip'
      decompression "$ZIP_FILE"
    elif [[ "$NUMBER" -eq '1' ]]; then
      echo "info: No new version. The current version of Clash is $CURRENT_VERSION ."
      exit 0
    fi
  fi
  # Determine if Clash is running
  if systemctl list-unit-files | grep -qw 'clash'; then
    if [[ -n "$(pidof clash)" ]] || [[ -z "$(pidof clash)" ]]; then
      stop_clash
      CLASH_RUNNING='1'
    fi
  fi
  install_clash
  install_startup_service_file
  echo 'installed: /usr/local/bin/clash'
  # If the file exists, the content output of installing or updating Country.mmdb will not be displayed
  if [[ -f "${DAT_PATH}/Country.mmdb" ]]; then
    echo "installed: ${DAT_PATH}/Country.mmdb"
  fi
  if [[ -f "${DAT_PATH}/config.yaml" ]]; then
    echo "installed: ${DAT_PATH}/config.yaml"
  fi
  if [[ "$SYSTEMD" -eq '1' ]]; then
    echo "installed: ${CLASH_PATH}//clash.service"
  fi
  "rm" -r "$TMP_DIRECTORY"
  echo "removed: $TMP_DIRECTORY"
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
    get_version
  fi
  echo "info: Clash $RELEASE_VERSION is installed."
  echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
  if [[ "$CLASH_RUNNING" -eq '1' ]]; then
    start_clash
  else
    echo 'Please execute the command: systemctl enable clash; systemctl start clash'
  fi
}

main "$@"
