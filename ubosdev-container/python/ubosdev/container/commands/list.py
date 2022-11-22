#!/usr/bin/python
#
# List the available development Linux containers
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import ubosdev.container.utils

def run( args ) :
    """
    Run this command.
    """
    ubosdev.container.listContainers( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='List the available UBOS development containers' )
    parser.add_argument( '--dir', default=None,     help='Parent directory in which too look' )
