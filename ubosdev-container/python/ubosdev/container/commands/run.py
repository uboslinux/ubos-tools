#!/usr/bin/python
#
# Run a development Linux container
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import ubosdev.container.utils

def run( args ) :
    """
    Run this command.
    """
    ubosdev.container.runContainer( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='Run a UBOS development container on Arch Linux' )

    parser.add_argument( '--name',               required=True,    help='Name of the systemd-nspawn container' )
    parser.add_argument( '--containerdirectory', default=None,     help='Directory for the UBOS Linux container' )
    parser.add_argument( '--sitetemplate',       default=None,     help='URL of the site JSON template to deploy in the container' )
