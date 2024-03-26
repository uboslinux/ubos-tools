#!/usr/bin/python
#
# Delete an existing development container
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
    ubosdev.container.deleteContainer( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='Delete an existing development container' )
    parser.add_argument( "--name",                             help="Name of the container to delete" )
    parser.add_argument( '--containerdirectory', default=None, help='Directory where the UBOS Linux containers are stored' )
