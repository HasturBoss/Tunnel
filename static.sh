#!/usr/bin/env bash

# author:HasturBoss
identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
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
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
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
    echo "The architecture: $MACHINE"
  fi
}

modify_static_ip() {
  echo -e "\033[31mPlease select network card driver and static ip: \033[0m"
  read -p "network card driver: " ncd
  read -p "static ip: " sip
  read -p "gateway ip: " gip
  sed -i "s/<drivers>/${ncd}/g" ./Tunnel/sources/static-localhost-network.txt
  sed -i "s/<ip1>/${sip}/g" ./Tunnel/sources/static-localhost-network.txt
  sed -i "s/<ip2>/${gip}/g" ./Tunnel/sources/static-localhost-network.txt
  tr -d "\015" <./Tunnel/sources/static-localhost-network.txt> ./Tunnel/sources/static-localhost-network_bak.txt
  cat ./Tunnel/sources/static-localhost-network_bak.txt >> /etc/network/interfaces
  echo "The network card driver and static ip have been changed!"
}

main() {
  identify_the_operating_system_and_architecture
  if [ -d "./Tunnel/sources" ]; then
      echo "Please confirm whether to change the ip?"
      read -p "Please input y or n, Y or N: " char
      if [ $char = "y" -o $char = "Y" ]; then
          modify_static_ip
      elif [ $char = "n" -o $char = "N" ]; then
          return 1
      else
          echo "The invalid symbol!"
          return 1
      fi
  else
      echo -e "\033[31mThe static.sh runs successfully!\033[0m"
  fi
}

main
