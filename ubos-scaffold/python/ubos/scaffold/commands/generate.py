#!/usr/bin/python
#
# Generate a new package from a scaffold
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import argparse
import os
import ubos.logging
import ubos.utils


def run( args ) :
    """
    Run this command.
    """

    template = ubos.scaffold.utils.findTemplate( args.template )
    if template is None:
        ubos.logging.fatal( 'Cannot find template:', args.template )

    instance = template.create()

    if args.json is not None:
        parValues = ubos.utils.readJsonFromFile( args.json )
        if parValues is None:
            ubos.logging.fatal( 'Failed to read file:', args.json )
    else:
        parValues = {}

    parValues['template']  = args.template

    first = True
    pars = instance.pars()
    if pars :
        for key in sorted( pars, key = lambda x : pars[x]['index'] ) :
            if not key in parValues :
                if first :
                    print( "To parameterize things properly, we still need to know a few things." )

                value = ubos.scaffold.utils.ask( pars[key]['description'] )
                parValues[key] = value

                first = False

    print( f"Generating UBOS files for package { parValues['name'] } using template { args.template } into directory { args.directory }." )

    instance.generate( parValues, args.directory )

    print( "Done." )


def addSubParser( parentParser, cmdName ) :
    """
    Enable this command to add its own command-line options
    parentParser: the parent argparse parser
    cmdName: name of this command
    """
    parser = parentParser.add_parser( cmdName, help='Generate a new UBOS package scaffold.' )
    parser.add_argument( '--directory', required=True,  help='Directory where to create the package scaffold')
    parser.add_argument( '--template',  required=True,  help='Name of the template to use' )
    parser.add_argument( '--json',      required=False, help='Settings file' )

