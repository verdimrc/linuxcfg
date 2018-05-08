#!/usr/bin/env python

# Adapted from http://code.activestate.com/recipes/577708-check-for-package-updates-on-pypi-works-best-in-pi/
# Changelog:
# - patch to python 3.6
# - include hidden releases

import xmlrpc.client

try:
    # pip 9
    from pip import get_installed_distributions
except ImportError:
    # pip 10
    import pkg_resources
    def get_installed_distributions():
        return pkg_resources.workingset

pypi = xmlrpc.client.ServerProxy('https://pypi.python.org/pypi')
for dist in get_installed_distributions():
    available = pypi.package_releases(dist.project_name, True)
    if not available:
        # Try to capitalize pkg name
        available = pypi.package_releases(dist.project_name.capitalize())

    if not available:
        msg = 'no releases at pypi'
    elif available[0] != dist.version:
        msg = '{} available'.format(available[0])
    else:
        msg = 'up to date'
    pkg_info = '{dist.project_name} {dist.version}'.format(dist=dist)
    print('{pkg_info:40} {msg}'.format(pkg_info=pkg_info, msg=msg))
