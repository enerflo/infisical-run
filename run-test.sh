#!/usr/bin/env bash

export TEST_SECRET_FOUR=set-in-shell

TEST_SECRET_SEVEN=set-in-shell TEST_SECRET_EIGHT=set-in-shell \
    ./infisical-run.sh -v --env-file ./dotenv --env-file ./other_env -- ./test.sh
