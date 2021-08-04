#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import argparse
import traceback
import ubos.scaffold.utils
import ubos.logging
import ubos.utils
import sys

def run():
    """
    Main entry point: looks for available subcommands and
    executes the correct one.
    """
    cmds = ubos.scaffold.utils.findCommands()

    parser = argparse.ArgumentParser( description='Generate scaffolds for UBOS packages.')
    parser.add_argument('-v', '--verbose', action='count',       default=0,  help='Display extra output. May be repeated for even more output.')
    parser.add_argument('--logConfig',                                       help='Use an alternate log configuration file for this command.')
    parser.add_argument('--debug',         action='store_const', const=True, help='Suspend execution at certain points for debugging' )
    cmdParsers = parser.add_subparsers( dest='command', required=True )

    for cmdName, cmd in cmds.items():
        cmd.addSubParser( cmdParsers, cmdName )

    args,remaining = parser.parse_known_args(sys.argv[1:])
    cmdName = args.command

    ubos.logging.initialize('ubos-scaffold', cmdName, args.verbose, args.logConfig, args.debug)

    if len(remaining)>0 :
        parser.print_help()
        exit(0)

    if cmdName in cmds:
        try :
            ret = cmds[cmdName].run(args)
            exit( ret )

        except Exception as e:
            if args.verbose > 1:
                traceback.print_exc( e )
            ubos.logging.fatal( str(type(e)), '--', e )

    else:
        ubos.logging.fatal('Sub-command not found:', cmdName, '. Add --help for help.' )
