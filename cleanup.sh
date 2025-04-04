#!/usr/bin/env bash

docker-safe() {
  if ! command -v docker &>/dev/null; then
    echo "docker is not installed on this machine"
    exit 1
  fi

  if ! docker $@; then
    echo "Trying again with sudo..."
    sudo docker $@
  fi
}

#rm ./output.log

echo "down exiting stack"
./docker-down.sh

echo "delete existing image"
docker-safe rmi $(docker images | grep test-dashboard | awk {' print $3 '})

echo "done."