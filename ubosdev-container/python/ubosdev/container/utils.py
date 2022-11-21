#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import importlib
import ubosdev.container.commands
import ubos.utils


def findCommands():
    """
    Find available commands.
    """
    cmdNames = ubos.utils.findSubmodules( ubosdev.container.commands )

    cmds = {}
    for cmdName in cmdNames:
        mod = importlib.import_module('ubosdev.container.commands.' + cmdName)
        cmds[cmdName] = mod

    return cmds
