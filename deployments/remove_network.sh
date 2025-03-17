#!/bin/bash

# Check if the network exists
if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  echo "Network ${NETWORK_NAME} exists. Removing it..."
  docker network rm "${NETWORK_NAME}"
else
  echo "Network ${NETWORK_NAME} does not exist. Nothing to remove."
fi
