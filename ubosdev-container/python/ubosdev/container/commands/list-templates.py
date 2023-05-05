#!/usr/bin/python
#
# List the templates that are available for development Linux containers
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import ubos.logging
import ubos.utils
import ubosdev.container.utils

def run( args ) :
    """
    Run this command.
    """
    ubosdev.container.listContainerTemplates( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='List the templates that are available for UBOS development containers' )
    parser.add_argument( '--imagesdirectory', default=None, help='Directory containing the downloaded images and unpacked container templates' )
