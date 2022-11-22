#!/usr/bin/python
#
# Setup a container
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import ubosdev.container.utils

def run( args ) :
    """
    Run this command.
    """
    ubosdev.container.setupContainer( args );


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='Set up a container-based development environment for UBOS Mesh on Arch Linux' )

    parser.add_argument( '--name',               default=None,     help='Name of the systemd-nspawn container' )
    parser.add_argument( '--channel',            default='yellow', help='Release channel (default: yellow)' )
    parser.add_argument( '--arch',               default=None,     help='Processor architecture' )
    parser.add_argument( '--containerdirectory', default=None,     help='Directory for the UBOS Linux container' )
    parser.add_argument( '--imagesdirectory',    default=None,     help='Directory where downloaded images are stored' )
    parser.add_argument( '--sitetemplate',       default=None,     help='URL of the site JSON template to deploy in the container' )
    parser.add_argument( '--flavor', choices=['linux', 'mesh'], default='linux', help='Choose whether to do base UBOS development or Mesh development' )

