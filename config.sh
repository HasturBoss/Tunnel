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

manual_switch_sources_list() {
  echo -e "  \033[31m<0.system not found>\n\033[0m" \
  " \033[31m<1.debian buster>\n\033[0m" \
  " \033[31m<2.debian bullseye>\n\033[0m" \
  " \033[31m<3.raspberry buster>\n\033[0m" \
  " \033[31m<4.raspberry bullseye>\n\033[0m"
  read -p "Please enter the current system(0 to 4): " key
  case "$key" in
    '0')
      echo "error: The system not found!"
      ;;
    '1')
      tr -d "\015" <./Tunnel/sources/sources-debian-buster.txt> ./Tunnel/sources/sources-debian-buster_bak.txt
      cp /etc/apt/sources.list /etc/apt/sources.list.bak
      cp ./Tunnel/sources/sources-debian-buster_bak.txt /etc/apt/sources.list
      echo "The source file was copied successfully!"
      ;;
    '2')
      tr -d "\015" <./Tunnel/sources/sources-debian-bullseye.txt> ./Tunnel/sources/sources-debian-bullseye_bak.txt
      cp /etc/apt/sources.list /etc/apt/sources.list.bak
      cp ./Tunnel/sources/sources-debian-bullseye_bak.txt /etc/apt/sources.list
      echo "The source file was copied successfully!"
      ;;
    '3')
      tr -d "\015" <./Tunnel/sources/sources-raspberry-buster.txt> ./Tunnel/sources/sources-raspberry-buster_bak.txt
      tr -d "\015" <./Tunnel/sources/raspi-raspberry-buster.txt> ./Tunnel/sources/raspi-raspberry-buster_bak.txt
      cp /etc/apt/sources.list /etc/apt/sources.list.bak
      cp /etc/apt/sources.list.d/raspi.list /etc/apt/sources.list.d/raspi.list.bak
      cp ./Tunnel/sources/sources-raspberry-buster_bak.txt /etc/apt/sources.list
      cp ./Tunnel/sources/raspi-raspberry-buster_bak.txt /etc/apt/sources.list.d/raspi.list
      echo "The source file was copied successfully!"
      ;;
    '4')
      tr -d "\015" <./Tunnel/sources/sources-raspberry-bullseye.txt> ./Tunnel/sources/sources-raspberry-bullseye_bak.txt
      tr -d "\015" <./Tunnel/sources/raspi-raspberry-bullseye.txt> ./Tunnel/sources/raspi-raspberry-bullseye_bak.txt
      cp /etc/apt/sources.list /etc/apt/sources.list.bak
      cp /etc/apt/sources.list.d/raspi.list /etc/apt/sources.list.d/raspi.list.bak
      cp ./Tunnel/sources/sources-raspberry-bullseye_bak.txt /etc/apt/sources.list
      cp ./Tunnel/sources/raspi-raspberry-bullseye_bak.txt /etc/apt/sources.list.d/raspi.list
      echo "The source file was copied successfully!"
      ;;
    *)
      echo "The invalid symbol!"
      ;;
  esac
}

recover_switch_sources_list() {
  echo -e "  \033[31m<0.system not found>\n\033[0m" \
  " \033[31m<1.debian buster>\n\033[0m" \
  " \033[31m<2.debian bullseye>\n\033[0m" \
  " \033[31m<3.raspberry buster>\n\033[0m" \
  " \033[31m<4.raspberry bullseye>\n\033[0m"
  read -p "Please enter the current system(0 to 4): " key
  case "$key" in
    '0')
      echo "error: The system not found!"
      ;;
    '1')
      cp /etc/apt/sources.list.bak /etc/apt/sources.list
      echo "The source file was copied successfully!"
      ;;
    '2')
      cp /etc/apt/sources.list.bak /etc/apt/sources.list
      echo "The source file was copied successfully!"
      ;;
    '3')
      cp /etc/apt/sources.list.bak /etc/apt/sources.list
      cp /etc/apt/sources.list.d/raspi.list.bak /etc/apt/sources.list.d/raspi.list
      echo "The source file was copied successfully!"
      ;;
    '4')
      cp /etc/apt/sources.list.bak /etc/apt/sources.list
      cp /etc/apt/sources.list.d/raspi.list.bak /etc/apt/sources.list.d/raspi.list
      echo "The source file was copied successfully!"
      ;;
    *)
      echo "The invalid symbol!"
      ;;
  esac
}

main() {
  identify_the_operating_system_and_architecture
  if [ -d "./Tunnel/sources" ]; then
      echo "Please confirm whether to change the source file?"
      read -p "Please input y or n, Y or N: " char
      if [ $char = "y" -o $char = "Y" ]; then
          manual_switch_sources_list
      elif [ $char = "n" -o $char = "N" ]; then
          recover_switch_sources_list
      else
          echo "The invalid symbol!"
          return 1
      fi
  else
      echo -e "\033[31mThe config.sh runs successfully!\033[0m"
  fi
}

main