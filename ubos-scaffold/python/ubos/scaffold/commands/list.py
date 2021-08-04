#!/usr/bin/python
#
# List all available scaffolds.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import ubos.logging
import ubos.scaffold.utils
import ubos.utils

def run( args ) :
    """
    Run this command.
    """

    templates = ubos.scaffold.utils.findTemplates()

    print( ubos.utils.dictAsColumns( templates, lambda x: x.help() ), end="" )


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='List all available templates from which to generate.' )
