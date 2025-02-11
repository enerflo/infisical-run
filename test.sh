#!/usr/bin/env bash

declare failed

function fail() {
    echo -e "\e[1;31mfail\e[0m $1"
    failed=1
}

function pass() {
    echo -e "\e[1;32mpass\e[0m $1"
}

function assert_defined() {
    if [ -z "${!1}" ]; then
        fail "\e[36m${1}\e[0m should have a value, but it is not set"
    else
        pass "\e[36m${1}\e[0m is defined"
    fi
}

function assert_value() {
    if [ "${!1}" != "${2}" ]; then
        fail "\e[36m${1}\e[0m should have value '\e[32m${2}\e[0m', but got '\e[31m${!1}\e[0m'"
    else
        pass "\e[36m${1}\e[0m is '\e[32m${2}\e[0m'"
    fi
}

assert_defined "INFISICAL_LOADED"

# ONE infisical only
assert_defined "TEST_SECRET_ONE"
assert_value "TEST_SECRET_ONE" "set-in-infisical"

# TWO .env only
assert_defined "TEST_SECRET_TWO"
assert_value "TEST_SECRET_TWO" "set-in-dotenv"

# THREE other_env only
assert_defined "TEST_SECRET_THREE"
assert_value "TEST_SECRET_THREE" "set-in-other-env"

# FOUR shell only
assert_defined "TEST_SECRET_FOUR"
assert_value "TEST_SECRET_FOUR" "set-in-shell"

# FIVE infisical and .env
assert_defined "TEST_SECRET_FIVE"
assert_value "TEST_SECRET_FIVE" "set-in-dotenv"

# SIX .env and other_env
assert_defined "TEST_SECRET_SIX"
assert_value "TEST_SECRET_SIX" "set-in-other-env"

# SEVEN other_env and shell
assert_defined "TEST_SECRET_SEVEN"
assert_value "TEST_SECRET_SEVEN" "set-in-shell"

# EIGHT all
assert_defined "TEST_SECRET_EIGHT"
assert_value "TEST_SECRET_EIGHT" "set-in-shell"

if [ -n "$failed" ]; then
    fail
    exit 1
else
    pass
fi
