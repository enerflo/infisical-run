#!/usr/bin/env bash
#
# Run a command after loading the environment from the Infisical secrets manager and other sources.
# See the usage text below for documentation.

version="1.0.0"

set -e -o pipefail

declare verbose

# Determine if stdout is a terminal. If not, we don't want to try to use color in log or error
# messages.
if [ -t 1 ]; then
    is_tty=1
fi

if [ -n "$VERBOSE" ]; then
    verbose=1
fi

function usage() {
    cat << EOF
USAGE:
    infisical-run.sh [options] -- <command>

OPTIONS:
    --client-id, -i <ID>        provide the Infisical client ID (\$INFISICAL_CLIENT_ID)
    --cd, -C <PATH>             change directories to the given path before doing anything
    --env-file, -E <PATH>       provide an additional dotenv file, may be given multiple times
    --environment, -e <ENV>     provide the Infisical project environment (\$INFISICAL_ENVIRONMENT)
    --force-infisical           load secrets from Infisical even if it has been determined to have already been loaded
    --help, -h:                 print this help message and exit
    --no-default-env-file       do not load .env
    --no-infisical              do not load secrets from Infisical
    --no-keep-shell-env         give shell environment variables lowest precedence instead of highest
    --project-id, -p <ID>       provide the Infisical project ID (\$INFISICAL_PROJECT_ID)
    --secret, -s <SECRET>       provide the Infisical client secret (\$INFISICAL_CLIENT_SECRET)
    --token, -t <TOKEN>         provide an already obtained Infisical authentication token (\$INFISICAL_TOKEN)
    --verbose, -v               print debugging log messages
    --version                   print the version and exit

DESCRIPTION:
    This script acts as a wrapper around the Infisical CLI to provide additional functionality and
    ergonomics that are otherwise missing. Any process that should be provided with the environment
    variables and secrets in Infisical should use this script as a command wrapper.

    Variables can come from one of four places:
    - The existing shell session or the command line of the root command
    - A .env file in the current directory
    - Other files using the "dotenv" convention
    - Infisical

    This script supports loading environment variables from all of these locations and resolves the
    final set of variables according to a precedence logic.

    Variables set on the command line have the highest precedence. This allows you to do things like
    this:
            FOO=bar infisical-run.sh -- some-command

    The Infisical secrets have the lowest precedence. Any variables that are set through the shell
    session or via a dotenv file will overwrite variables set through Infisical. If for whatever
    reason you don't want to load secrets from Infisical you can use --no-infisical, in which case
    all other variable sources are loaded but Infisical is skipped. If the _SECRETS_MANAGER_LOADED
    environment variable is set and has the value "true", Infisical is assumed to have already been
    loaded and it is skipped. The dotenv files are still loaded as normal. If the --force-infisical
    flag is given, this overrides both of the above conditions and forces Infisical to be loaded
    regardless.

    If a .env file is found in the current directory it will be loaded at higher precedence than the
    Infisical secrets. You can disable loading the .env file using the --no-default-env-file flag.
    You can also point to other files using the same dotenv convention using the --env-file flag.
    You can specify the flag any number of times, and the files will be loaded in the same order
    that they are given. The .env file is loaded first, so any additional dotenv files will be
    loaded at higher precedence.

    You MUST use -- to delimit flags to this script from the command to be run.

EOF
}

function error() {
    if [ -n "$is_tty" ]; then
        echo -e "\e[31mERROR\e[0m: $@"
    else
        echo "ERROR: $@"
    fi
}

function bail() {
    error $@
    exit 1
}

function debug() {
    if [ -n "$verbose" ]; then
        if [ -n "$is_tty" ]; then
            echo -e "\e[36mDEBUG\e[0m: $@"
        else
            echo "DEBUG: $@"
        fi
    fi
}

function load_dotenv() {
    debug "loading env file $1"
    set -a
    source "$1"
    set +a
}

function default_dotenv() {
    if [ -z "$no_default_env_file" ]; then
        if [ -f .env ]; then
            load_dotenv ./.env
        else
            debug "default .env file not found"
        fi
    fi
}

function load_project_id() {
    if [ -z "$INFISICAL_PROJECT_ID" ]; then
        if [ -f .infisical.json ]; then
            if command -v jq &>/dev/null; then
                debug "loading project ID from .infisical.json using jq"
                INFISICAL_PROJECT_ID=$(jq -r '.workspaceId' < .infisical.json)
            else
                debug "loading project ID from .infisical.json using awk"
                INFISICAL_PROJECT_ID=$(awk -F': ' '/workspaceId/ { print $2 }' < .infisical.json | tr -d '",')
            fi
        else
            debug "no .infisical.json file found"
        fi
    fi
}

function load_default_environment() {
    if [ -z "$INFISICAL_ENVIRONMENT" ]; then
        if [ -f .infisical.json ]; then
            if command -v jq &>/dev/null; then
                debug "loading default environment from .infisical.json using jq"
                INFISICAL_ENVIRONMENT=$(jq -r '.defaultEnvironment' < .infisical.json)
            else
                debug "loading default environment from .infisical.json using awk"
                INFISICAL_ENVIRONMENT=$(awk -F': ' '/defaultEnvironment/ { print $2 }' < .infisical.json | tr -d '",')
            fi
        else
            debug "no .infisical.json file found"
        fi
    fi
}

if [ ! command -v infisical &>/dev/null ]; then
    bail "The infisical CLI not found. See https://infisical.com/docs/cli/overview for installation instructions."
fi

declare -a dotenv_files

# Parse command line flags until '--' is found. Any flags before that delimiter are flags for this
# script itself, anything after the delimiter is taken as the command to invoke after loading the
# environment.
while [ $# -gt 0 ]; do
    case "$1" in
        "--help" | "-h")
            usage
            exit 0
            ;;
        "--version")
            echo "infisical-run $version"
            exit 0
            ;;
        "--client-id" | "-i")
            INFISICAL_CLIENT_ID="$2"
            shift
            ;;
        "--cd" | "-C")
            cd "$2"
            shift
            ;;
        "--env-file" | "-E")
            dotenv_files+=("$2")
            shift
            ;;
        "--environment" | "-e")
            INFISICAL_ENVIRONMENT="$2"
            shift
            ;;
        "--force-infisical")
            force_infisical=1
            ;;
        "--no-default-env-file")
            no_default_env_file=1
            ;;
        "--no-infisical")
            no_infisical=1
            ;;
        "--no-keep-shell-env")
            no_keep_shell_env=1
            ;;
        "--project-id" | "-p")
            INFISICAL_PROJECT_ID="$2"
            shift
            ;;
        "--secret" | "-s")
            INFISICAL_CLIENT_SECRET="$2"
            shift
            ;;
        "--token" | "-t")
            INFISICAL_TOKEN="$2"
            shift
            ;;
        "--verbose" | "-v")
            verbose=1
            ;;
        "--")
            shift
            break
            ;;
        *)
            bail "unknown argument: $1"
            ;;
    esac
    shift
done

debug "infisical-run $version"

# If we wind up with an instance of this script invoking a command that also invokes this script we
# want the first instance to take precedence, so we prevent ourselves from running again by
# short-circuiting to launch the target command.
if [ -n "$_INFISICAL_RUN" ]; then
    debug "already launched by an earlier instance of the script, short-circuiting to launch the command"
    exec $@
fi

export _INFISICAL_RUN=true

if [ "$_SECRETS_MANAGER_LOADED" = "true" ] || [ "$INFISICAL_LOADED" = "true" ]; then
    no_infisical=1
fi

if [ -n "$force_infisical" ]; then
    unset no_infisical
fi

# Create a backup of the extant environment variables that come in from the shell session. We need
# to restore these variables later after having loaded all of the other variable sources.
declare -A env_backup
if [ -z "$no_keep_shell_env" ]; then
    debug "backing up shell session environment variables"
    while IFS='=' read -r k v; do
        env_backup["$k"]="$v"
    done < <(env)
fi

# Load the .env before attempting Infisical authentication, in case the values we need to
# authenticate are to be found there. Any variables shared between .env and Infisical will be
# overwritten by the latter, but we will load .env again afterwards to ensure they take precedence.
default_dotenv

# Load secrets from Infisical. Using a machine identity we need to perform a login to obtain a
# token, and then we need to use that token when fetching the secrets. A machine identity consists
# of an ID and a secret. These may be provided through the environment to this script, through the
# .env file, or explicitly on the command line. If you already have a token we can skip the login
# step and go right to fetching the secrets.
if [ -z "$no_infisical" ]; then
    if [ -z "$INFISICAL_TOKEN" ]; then
        if [ -z "$INFISICAL_CLIENT_ID" ]; then
            error "missing INFISICAL_CLIENT_ID"
            auth_fail=1
        fi

        if [ -z "$INFISICAL_CLIENT_SECRET" ]; then
            error "missing INFISICAL_CLIENT_SECRET"
            auth_fail=1
        fi

        if [ -n "$auth_fail" ]; then
            bail "no INFISICAL_TOKEN available, unable to authenticate to obtain a token"
        fi

        debug "obtaining infisical token"
        INFISICAL_TOKEN=$(\
            infisical login \
                --silent \
                --method=universal-auth \
                --client-id=$INFISICAL_CLIENT_ID \
                --client-secret=$INFISICAL_CLIENT_SECRET \
                --plain \
        );
    fi

    # When using token-based authentication, infisical will not read the project ID from the
    # .infisical.json file. If we don't already have a project ID set in the environment, load it by
    # reading it out of .infisical.json.
    load_project_id
    if [ -z "$INFISICAL_PROJECT_ID" ]; then
        bail "missing INFISICAL_PROJECT_ID"
    fi

    # If not otherwise set, the default Infisical environment is "dev".
    load_default_environment
    : ${INFISICAL_ENVIRONMENT:="dev"}

    # Load the Infisical secrets into the local shell session environment.
    debug "fetching secrets from infisical"
    set -a
    eval "$(infisical export --silent --token $INFISICAL_TOKEN --projectId $INFISICAL_PROJECT_ID --env $INFISICAL_ENVIRONMENT)"
    set +a

    # Load the default .env file, if it exists. We already loaded it before fetching Infisical
    # secrets, but in order to give it higher precedence we load it again afterwards.
    default_dotenv
fi

# Load any additional dotenv files that were specified on the command line. These have higher
# priority than Infisical, so they must be loaded afterwards. They have higher priority than the
# default .env file, and are loaded in the order that they are specified on the command line.
for f in "${dotenv_files[@]}"; do
    if [ ! -f "$f" ]; then
        bail "requested dotenv file $f not found"
    fi

    load_dotenv "$f"
done

# Having loaded Infisical and any dotenv files, we restore the variables that were set in the local
# shell session environment. These have the highest priority, so they must be set last.
if [ -z "$no_keep_shell_env" ]; then
    debug "restoring shell environment"
    for k in "${!env_backup[@]}"; do
        export "$k=${env_backup[$k]}"
    done
fi

debug "loading complete, launching command"
exec $@
