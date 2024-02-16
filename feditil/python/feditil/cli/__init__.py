"""
Main entry point for CLI invocation
"""

from ast import Module
from argparse import ArgumentParser
import importlib
import sys
import traceback

import ubos.logging
from ubos.utils import findSubmodules
import feditil.cli.commands

def main():
    """
    Main entry point for CLI invocation.
    """

    # Discover and install sub-commands

    cmds = find_commands()

    parser = ArgumentParser(description='Feditil: Fediverse utilities')
    parser.add_argument('-v', '--verbose', action='count', default=0,
            help='Display extra output. May be repeated for even more output' )
    cmd_parsers = parser.add_subparsers(dest='command', required=True)

    for cmd_name, cmd in cmds.items():
        cmd.add_sub_parser(cmd_parsers, cmd_name)

    args,remaining = parser.parse_known_args(sys.argv[1:])
    cmd_name = args.command

    ubos.logging.initialize( 'feditil', None, args.verbose )

    if cmd_name in cmds:
        try :
            ret = cmds[cmd_name].run(parser, args, remaining)
            sys.exit( ret )

        except Exception as e: # pylint: disable=broad-exception-caught
            ubos.logging.fatal( e )

    else:
        ubos.logging.fatal('Sub-command not found:', cmd_name, '. Add --help for help.' )


def find_commands() -> dict[str,Module]:
    """
    Find available commands.
    """
    cmd_names = findSubmodules( feditil.cli.commands )

    cmds = {}
    for cmd_name in cmd_names:
        mod = importlib.import_module('feditil.cli.commands.' + cmd_name)
        cmds[cmd_name.replace('_', '-')] = mod

    return cmds


if __name__ == '__main__':
    main()
