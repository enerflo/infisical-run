#!/usr/bin/env bash
#
# Install infisical CLI in ubuntu, for use in CI

curl -1sLf \
    'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' \
    | sudo -E bash
sudo apt-get update && sudo apt-get install -y infisical
