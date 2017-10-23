#!/usr/bin/env python

# Adapted from http://code.activestate.com/recipes/577708-check-for-package-updates-on-pypi-works-best-in-pi/
# Changelog:
# - patch to python 3.6

import xmlrpc
import pip

pypi = xmlrpc.client.ServerProxy('https://pypi.python.org/pypi')
include_hidden_releases = True

latest_versions = []
for project_name in ('awscli', 'botocore'):
    available = pypi.package_releases(project_name, include_hidden_releases)
    if not available:
        # Try to capitalize pkg name
        available = pypi.package_releases(project_name.capitalize())
    latest_versions.append('{project_name}-{latest_version}'.format(project_name=project_name, latest_version=available[0]))
print('|'.join(latest_versions))
