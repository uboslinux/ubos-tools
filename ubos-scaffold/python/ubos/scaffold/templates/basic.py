#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from ubos.scaffold.template import AbstractTemplate
import ubos.scaffold.utils


class Basic( AbstractTemplate ):
    pass

def create() :
    """
    Factory function
    """
    return Basic()


def help() :
    return 'basic package'

