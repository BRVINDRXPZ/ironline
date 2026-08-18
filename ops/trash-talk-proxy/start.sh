#!/bin/bash
export PROXY_TOKEN=$(cat "$(dirname "$0")/.token")
exec /opt/homebrew/bin/node "$(dirname "$0")/server.js"
