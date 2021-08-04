#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import importlib
import ubos.logging
import ubos.scaffold.commands
import ubos.scaffold.templates
import ubos.scaffold.utils
import ubos.utils


def findCommands():
    """
    Find available commands.
    """
    cmdNames = ubos.utils.findSubmodules( ubos.scaffold.commands )

    cmds = {}
    for cmdName in cmdNames:
        mod = importlib.import_module('ubos.scaffold.commands.' + cmdName)
        cmds[cmdName] = mod

    return cmds


def findTemplates():
    """
    Find available templates.
    """
    templateNames = ubos.utils.findSubmodules( ubos.scaffold.templates )

    templates = {}
    for templateName in templateNames:
        mod = importlib.import_module('ubos.scaffold.templates.' + templateName)
        templates[templateName] = mod

    return templates


def findTemplate( name ) :
    """
    Find a named template

    name: name of the template
    """

    templates = findTemplates()
    ret       = templates[name]

    return ret


def ask( description ):
    """
    Ask the user for parameter values.

    description: the description of the parameter
    """

    fullQuestion = description.strip() + ': '

    while 1:
        userinput = input( fullQuestion )
        userinput = userinput.strip()

        if userinput:
            break

    return userinput;
