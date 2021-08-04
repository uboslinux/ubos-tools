#!/usr/bin/python
#
# Setup the package.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from pathlib import Path
from setuptools import setup
import ubos.scaffold

setup(name='ubos-scaffold',
      version=Path('../../PKGVER').read_text().strip(),
      packages=[
          'ubos.scaffold',
          'ubos.scaffold.commands',
          'ubos.scaffold.templates'
      ],
      zip_safe=True)
