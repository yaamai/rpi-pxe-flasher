#!/bin/sh

ip=$1
user=root

ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $user@$ip '
  uname -a
  date
  uptime
  ip a
  ip r
  cat /etc/resolv.conf
  free -m
  df -h
  ls -al /dev/sd*
'
