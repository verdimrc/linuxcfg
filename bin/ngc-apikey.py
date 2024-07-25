#!/usr/bin/env python3

'''Utility similar to awsume, but to deal with multiple ngc cli profiles.

Fetch just the API key, typically for scripting purposes:

.. code-block:: console

    $ ngc-apikey.py
    <api_key>

    $ ngc-apikey.py org/team
    <api_key>

    $ export NGC_CLI_PROFILE=profile
    $ ngc-apikey.py
    <api_key>

    $ export NGC_CLI_ORG=org
    $ export NGC_CLI_TEAM=team
    $ ngc-apikey.py
    <api_key>

Set `NGC_CLI_*` environment variables on current shell:

.. code-block:: console

    $ source <(ngc-apikey.py --assume profile)
    $ env | grep NGC_CLI
    NGC_CLI_ORG=org
    NGC_CLI_TEAM=team
    NGC_CLI_PROFILE=profile

    $ source <(ngc-apikey.py --assume-with-key profile)
    $ env | grep NGC_CLI
    NGC_CLI_ORG=org
    NGC_CLI_TEAM=team
    NGC_CLI_PROFILE=profile
    NGC_API_KEY=<api_key>

Unset `NGC_CLI_*` environment variables on current shell:

.. code-block:: console

    $ source <(ngc-apikey.py --unassume)
    $ env | grep NGC_CLI
    <No more NGC_CLI_{PROFILE,API_KEY,ORG,TEAM}>

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


class Command(ABC):
    @abstractmethod
    def get_section_name(self, *args):
        pass


class Selector:
    def __init__(self, profile):
        self.profile = profile

    def get_section_name(self, config):
        if not self.profile in config:
            raise SectionNotFoundError('Section not found: profile={self.profile}')
        return self.profile


class Finder:
    def __init__(self, org, team):
        self.org = org
        self.team = team

    def get_section_name(self, config):
        for section_name in config:
            section = config[section_name]
            if (section.get('org') == self.org) and (section.get('team') == self.team):
                return section_name
        raise SectionNotFoundError(f'Section not found: org/team={self.org}/{self.team}')


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

    if args.profile:
        # To use the specific profile defined by the CLI
        command = Selector(args.profile)
    else:
        # Probe env vars to determine the profile
        profile = os.environ.get('NGC_CLI_PROFILE')    # This is our custom env var.
        if profile:
            # To use the profile env var
            command = Selector(profile)
        else:
            # To find the profile of the org/team env vars.
            # https://docs.ngc.nvidia.com/cli/script.html#environment-variables
            org = os.environ.get('NGC_CLI_ORG')
            team = os.environ.get('NGC_CLI_TEAM')

            if ([org, team] == [None, None] or [org, team] == ['', '']):
                # No org/team env vars, and no profile specified (CLI, env var).
                # Hence, to use the CURRENT profile.
                command = Selector('CURRENT')
            elif (
                    ([type(org), type(team)] != [str, str])
                    or (org == '')
                    or (team == '')
            ):
                # Bail out on invalid env vars.
                printerr('Only one of these are defined:',
                         f'NGC_CLI_ORG={org}',
                         f'NGC_CLI_TEAM={team}',
                        sep='\n')
                sys.exit(-1)
            else:
                # Org/team env vars defined. Hence, to find the profile.
                command = Finder(org, team)

    config = configparser.ConfigParser()
    config.read(os.path.expanduser(os.environ.get('NGC_CLI_HOME', '~/.ngc/config')))
    try:
        # Fetch the section
        section_name = command.get_section_name(config)
        section = config[section_name]
    except SectionNotFoundError as e:
        printerr(e)
        sys.exit(1)

    if args.unassume:
        print('unset NGC_CLI_{ORG,TEAM,PROFILE,API_KEY}')
    elif args.assume_with_key:
        print(f'export NGC_CLI_ORG={section["org"]}',
              f'export NGC_CLI_TEAM={section["team"]}',
              f'export NGC_CLI_PROFILE={section_name}',
              f'export NGC_CLI_API_KEY={section["apikey"]}',
              sep='\n'
        )
    elif args.assume:
        print(f'export NGC_CLI_ORG={section["org"]}',
              f'export NGC_CLI_TEAM={section["team"]}',
              f'export NGC_CLI_PROFILE={section_name}',
              sep='\n'
        )
    else:
        print(section['apikey'])

if __name__ == '__main__':
    main()
