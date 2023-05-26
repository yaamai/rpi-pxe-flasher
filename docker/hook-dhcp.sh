#!/usr/bin/env bash

action=$1
mac=$2
ip=$3
retry=${PXE_FLASH_RETRY:-5}
retry_wait=${PXE_FLASH_RETRY_WAIT:-3}
retry_timeout=${PXE_FLASH_RETRY_TIMEOUT:-3}

check_ssh() {
  local ip=$1

  for i in $(seq $retry); do
    ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=$retry_timeout" root@$ip exit 0
    if [[ $? -eq 0 ]]; then
      return 0
    fi

    sleep $retry_wait
  done
  return 1
}

if [[ $action = "old" ]]; then
  echo "hook-dhcp: $*"

  if [[ ! -x /deploy.sh ]]; then
    echo "/deploy.sh not found"
    exit 0
  fi

  check_ssh $ip
  if [[ $? -ne 0 ]]; then
    echo "hook-dhcp: timeout to connect target $mac $ip"
    exit 0
  fi

  /deploy.sh $ip
  echo "hook-dhcp: script successfully called"
fi
