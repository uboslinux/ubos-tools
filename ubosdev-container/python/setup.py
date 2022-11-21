#!/usr/bin/python
#
# Setup the package.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from pathlib import Path
from setuptools import setup

setup(name='ubosdev-container',
      version=Path('../../PKGVER').read_text().strip(),
      packages=[
          'ubosdev.container',
          'ubosdev.container.commands'
      ],
      zip_safe=True)
