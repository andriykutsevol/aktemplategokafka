#!/bin/bash

# Check if the network already exists
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  echo "Network ${NETWORK_NAME} does not exist. Creating it..."
  docker network create --subnet="${SUBNET}" --gateway="${GATEWAY}" "${NETWORK_NAME}"
else
  echo "Network ${NETWORK_NAME} already exists."
fi 
