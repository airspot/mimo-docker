#!/usr/bin/env bash

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root, please run sudo or log in as root first." 1>&2
    exit 1
  fi
}

check_linux_memory() {
  echo `free -g --si | awk ' /Mem:/  {print $2} '`
}

check_docker () {
  docker_path=`which docker.io || which docker`
  if [ -z $docker_path ]; then
    read  -p "Docker not installed. Hit enter to install from https://get.docker.com/ or type Ctrl+C to exit"
    curl https://get.docker.com/ | sh
  fi
  docker_path=`which docker.io || which docker`
  if [ -z $docker_path ]; then
    echo Installing Docker failed. Exiting.
    exit
  fi
}

check_disk_and_memory() {
  mem_free=$(check_linux_memory)

  if [ "$mem_free" -lt 1 ]; then
    echo "WARNING: MIMO requires 1GB RAM. This system doesn't have"
    echo "sufficient memory."
    echo
    echo "Please provision a server with at least 1GB RAM"
    exit 1
  fi

  free_disk="$(df /var | tail -n 1 | awk '{print $4}')"
  if [ "$free_disk" -lt 5000 ]; then
    echo "WARNING: MIMO requires at least 5GB free disk space. This system"
    echo "doesn't have enough disk space."
    echo
    echo "Please free up some space or expand your disk before continuing."
    echo
    exit 1
  fi
}

check_port() {
  if lsof -Pi :${1} -sTCP:LISTEN -t >/dev/null; then
    echo ${1} is in use
    echo "Please ensure you stop any services that are running on port ${1}"
    exit 1
  fi
}

check_ports() {
  check_port "80"
  check_port "443"
}

update_config() {

  local ok_config='no'
  local production_config='docker-compose.prod.yml'
  local changelog='change.log'

  hostname='example.com'
  admin_user='user@example.com'
  smtp_host='smtp.example.com'
  smtp_port=25
  smtp_user='token'
  smtp_pass='password'

  while [[ "$ok_config" == "no" ]]
  do
    if [ ! -z "$hostname" ]
    then
      read -p "What's the domain for your MIMO installation? [$hostname]: " new_value
      if [ ! -z "$new_value" ]
      then
        hostname="$new_value"
      fi
      if [[ ! $hostname =~ ^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$ ]]
      then
        echo
        echo "[WARNING!!!] MIMO needs a valid hostname. IP addresses are not supported!"
        echo ""
        echo "A valid hostname should look like 'example.com' and not 'test.example.com'"
        echo "Setting your hostname to example.com"
        echo
        hostname="example.com"
      fi
    fi

    if [ ! -z "$admin_user" ]
    then
      read -p "Enter your admin email, this will be your master login? [$admin_user]: " new_value
      if [ ! -z "$new_value" ]
      then
        admin_user="$new_value"
      fi
      if [[ ! $admin_user =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]
      then
        echo
        echo "[WARNING!!!] MIMO needs a valid email, please try again!"
        echo
        admin_user="user@example.com"
      fi
    fi

    if [ ! -z "$smtp_host" ]
    then
      read -p "Enter your SMTP hostname [$smtp_host]: " new_value
      if [ ! -z "$new_value" ]
      then
        smtp_host="$new_value"
      fi
      if [ "$smtp_host" == "smtp.sendgrid.net" ]
      then
        smtp_port=2525
      fi
      if [ "$smtp_address" == "smtp.mailgun.org" ]
      then
        smtp_port=587
      fi
    fi

    if [ ! -z "$smtp_port" ]
    then
      read -p "Enter your SMTP port [$smtp_port]: " new_value
      if [ ! -z "$new_value" ]
      then
        smtp_port="$new_value"
      fi
    fi

    if [ ! -z "$smtp_user" ]
    then
      read -p "Enter your SMTP username [$smtp_user]: " new_value
      if [ ! -z "$new_value" ]
      then
        smtp_user="$new_value"
      fi
    fi

    if [ ! -z "$smtp_pass" ]
    then
      read -p "Enter your SMTP password [$smtp_pass]: " new_value
      if [ ! -z "$new_value" ]
      then
        smtp_pass="$new_value"
      fi
    fi

    echo -e "\nDoes this look right?\n"
    echo "Hostname      : $hostname"
    echo "Admin Email   : $admin_user"
    echo "SMTP Host     : $smtp_host"
    echo "SMTP Port     : $smtp_port"
    echo "SMTP User     : $smtp_user"
    echo "SMTP Password : $smtp_pass"
    echo ""
    read -p "Hit ENTER to continue. Type 'no' to try again. Ctrl+C will exit: " ok_config

    echo "Writing configs to $production_config. Then we'll start the magic"

    cp $production_config $production_config.backup

    sed -i -e "s/MIMO_TEST_URL=SOME_SECRET/MIMO_TEST_URL=$hostname/w $changelog" $production_config

    if [ -s $changelog ]
    then
      echo "OK done some stuff = ${hostname}"
      rm $changelog
    fi

  done
}

check_root
check_docker
check_disk_and_memory
check_ports
update_config
