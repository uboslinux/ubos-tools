#!/usr/bin/python
#
# Setup the package.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from pathlib import Path
from setuptools import setup
import ubos.scaffold.templates

setup(name='ubos-scaffold-templates',
      version=Path('../../PKGVER').read_text().strip(),
      install_requires=[
          'ubos-scaffold'
      ],
      packages=[
          'ubos.scaffold.templates'
      ],
      zip_safe=True)
