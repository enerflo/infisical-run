# infisical-run

A wrapper script around the [Infisical CLI](https://infisical.com/docs/cli/overview) that adds
additional features, improves ergonomics, and provides consistency across a variety of different
applications and deployment contexts.

It is optimized for use with machine identities and requires the following environment variables to
be set, corresponding to a machine identity's client ID and secret:
- `INFISICAL_CLIENT_ID`
- `INFISICAL_CLIENT_SECRET`

Additionally, the script reads (but does not necessarily require) the following environment
variables:

- `INFISICAL_PROJECT_ID` for the project/workspace ID
- `INFISICAL_ENVIRONMENT` for the app environment (dev/staging/prod)
- `INFISICAL_TOKEN` to skip authentication when an auth token is already in hand

Any of these may be supplied as command line flags instead of environment variables.

The project ID can be scraped out of the `.infisical.json` file if one exists. These files are
created using `infisical init`. If the file can't be found or doesn't exist, then you will need to
set the `INFISICAL_PROJECT_ID` as either an environment variable or in a `.env` file.

The `.infisical.json` file can also contain the default app environment. If not set or if the file
cannot be found or doesn't exist, the hard fallback default used is "dev".

The script provides the following features:
- Ensures that existing environment variables set in the shell session or via the command line have
  the highest precedence
- Ensures that the `.env` file, if it exists, is loaded with higher precedence than Infisical
  secrets (but lower precedence than shell variables)
- Optionally supports loading other "dotenv" style files
- Authenticates with Infisical using a machine identity (or token)
- Loads the project ID and default app environment from `.infisical.json`
- Fetches and exports secrets from Infisical
- Launches a command under the resolved environment

## Setup for using the script

Obtain the client ID of an Infisical machine identity, creating one when necessary. Store the ID in
the `INFISICAL_CLIENT_ID` environment variable. Create a secret key on the identity and copy the
value, and store it in the `INFISICAL_CLIENT_SECRET` environment variable.

You can store these variables in a `.env` file, since the script will read the `.env` file (if it
exists) before it authenticates with Infisical specifically for this purpose.

The recommended approach, however, is to set the variables in your shell initialization file
(`~/.bashrc`, `~/.zshrc`, etc). That way it is set all of the time for any of the applications you
may want to run using the script. Note, however, than variables set this way will not pass through
into Docker container environments naturally and you may need to set then in a `.env` file in these
cases, or use some other method of setting them.

If you're running MacOS then your pre-installed version of bash is from 2007 and is too old to be
supported. You will need to upgrade your bash to a current version using Homebrew.

```
brew install bash
```

## Using the script from another repo

Install the package as a dev dependency:

```sh
yarn add --dev @enerflo/infisical-run@git+https://github.com/enerflo/infisical-run#v1.0.0
```

Then invoke it using `npx`:

```sh
npx infisical-run -- some-command
```
