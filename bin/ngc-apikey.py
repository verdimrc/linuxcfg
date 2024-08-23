#!/usr/bin/env python3

'''Utility similar to awsume, but to deal with multiple ngc cli profiles.

NOTE: you must let this tool manage `NGC_CLI_HOME`. Do not set this env var by yourself.

This script requires you to organize your NGC CLI config files in the following structure:

.. code-block:: text

    # Every config file has one-and-only section [CURRENT].
    $HOME/.ngc
    ├── aaa
    │   └── .ngc
    │       └── config                        # Profile name: aaa
    ├── xxx
    │   ├── yyy
    │   │   └── .ngc
    │   │       └── config                    # Profile name: xxx/yyy
    │   └── zzz
    │       └── .ngc                          # Profile name: xxx/zzz
    │           └── config
    ├── ...
    └── config                                # Default profile

Fetch just the API key, typically for scripting purposes:

.. code-block:: console

    $ ngc-apikey-v2.py
    <api_key>

    $ ngc-apikey-v2.py org/team
    <api_key>

    $ export NGC_CLI_PROFILE=profile
    $ ngc-apikey-v2.py
    <api_key>

Set a few `NGC_CLI_*` `environment variables <https://docs.ngc.nvidia.com/cli/script.html>`_ on
current shell:

.. code-block:: console

    # NOTE: NGC_CLI_PROFILE is a custom env var.

    $ source <(ngc-apikey.py --assume profile)
    $ env | grep NGC_CLI
    NGC_CLI_PROFILE=profile
    NGC_CLI_HOME=/home/xxx/.ngc/profile

    $ source <(ngc-apikey.py --assume-with-key profile)
    $ env | grep NGC_CLI
    NGC_CLI_PROFILE=profile
    NGC_CLI_HOME=/home/xxx/.ngc/profile
    NGC_API_KEY=<api_key>

Unset the `NGC_CLI_*` environment variables on current shell:

.. code-block:: console

    $ source <(ngc-apikey.py --unassume)
    $ env | grep NGC_CLI
    <No more NGC_CLI_{PROFILE,HOME,API_KEY}>

'''

import argparse
import configparser
import os
import sys
from abc import ABC, abstractmethod

try:
    from rich.console import Console

    printerr = Console(force_terminal=True, force_jupyter=False, stderr=True).out
except ModuleNotFoundError:
    def printerr(*args, **kwargs):
        print(*args, file=sys.stderr, **kwargs)
    pass


class SectionNotFoundError(ValueError):
    pass


class Profile:
    def __init__(self, profile=""):
        self.profile = profile
        self.ngc_cli_home = os.path.expanduser('~')
        if self.profile:
            self.ngc_cli_home = os.path.join(self.ngc_cli_home, f'.ngc/{self.profile}')
        self.ngc_cli_config_file = os.path.join(self.ngc_cli_home, '.ngc/config')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('profile',
                        nargs='?',
                        default='',
                        help='To search either in section [${PROFILE}]')
    parser.add_argument('--assume',
                        action='store_true',
                        help='To set NGC_CLI_* env vars (excluding NGC_CLI_API_KEY) instead of showing the API key')
    parser.add_argument('--assume-with-key',
                        action='store_true',
                        help='To set NGC_CLI_* env vars instead of showing the API key')
    parser.add_argument('--unassume',
                        action='store_true',
                        help='To unset NGC_CLI_* env vars instead of showing the API key')
    args = parser.parse_args()

    if args.assume_with_key:
        args.assume = True

    if args.profile:
        command = Profile(args.profile)
    else:
        profile = os.environ.get('NGC_CLI_PROFILE', "")    # This is our custom env var.
        command = Profile(profile)

    config = configparser.ConfigParser()
    config.read(os.path.join(command.ngc_cli_config_file))
    section_name = 'CURRENT'
    if not section_name in config:
        raise SectionNotFoundError(f'Section "CURRENT" not found in {command.ngc_cli_config_file}')
    section = config[section_name]

    if args.unassume:
        print('unset NGC_CLI_{PROFILE,HOME,API_KEY}')
    elif args.assume:
        print('unset NGC_CLI_{PROFILE,HOME,API_KEY}')
        if command.profile:
            print(f'export NGC_CLI_PROFILE={command.profile}',
                f'export NGC_CLI_HOME={command.ngc_cli_home}',
                sep='\n'
            )
            if args.assume_with_key:
                print(f'export NGC_CLI_API_KEY={section["apikey"]}')
    else:
        print(section['apikey'])

if __name__ == '__main__':
    main()
