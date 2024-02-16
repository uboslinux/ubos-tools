"""
"""

from argparse import ArgumentParser, Namespace

import json
import ubos.logging
import feditil
import feditil.cli


def run(parser: ArgumentParser, args: Namespace, remaining: list[str]) -> None:
    """
    Run this command.
    """
    if len(remaining) == 0:
        parser.print_help();
        return 0

    for candidate in remaining:
        ubos.logging.info( 'Resolving', candidate )

        toResolve = feditil.normalize_id(candidate)
        if not toResolve :
            ubos.logging.error( 'Not a resolvable identifier:', candidate )
            next

        try:
            wfJson = feditil.perform_webfinger_query(toResolve)

            print(json.dumps(wfJson))

        except Exception as e:
            ubos.logging.error('Failed resolving', toResolve, ':', e )



def add_sub_parser(parent_parser: ArgumentParser, cmd_name: str) -> None:
    """
    Enable this command to add its own command-line options
    parent_parser: the parent argparse parser
    cmd_name: name of this command
    """
    parser = parent_parser.add_parser( cmd_name, help='Run a Webfinger query')
