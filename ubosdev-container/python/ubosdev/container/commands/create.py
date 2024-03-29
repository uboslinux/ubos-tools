#!/usr/bin/python
#
# Create a new development container from a template
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
    ubosdev.container.createContainer( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='Create a development container from a template' )
    parser.add_argument( "--name",                             help="Name of the container to create" )
    parser.add_argument( "--templatename",                     help="Name of the template to instantiate" )
    parser.add_argument( '--containerdirectory', default=None, help='Directory where the UBOS Linux containers are stored' )
    parser.add_argument( '--imagesdirectory',    default=None, help='Directory where downloaded images are stored' )
    parser.add_argument( '--sitetemplate',       default=None, help='URL of the site JSON template to deploy in the container' )
    parser.add_argument( '--flavor', choices=['gears', 'mesh'], default='gears', help='Choose whether to developed for UBOS Gears or also for UBOS Mesh' )
