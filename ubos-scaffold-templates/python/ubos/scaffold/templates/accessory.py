#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from ubos.scaffold.template import AbstractAppOrAccessoryTemplate
import ubos.scaffold.utils


class Accessory( AbstractAppOrAccessoryTemplate ):
    def pars( self ) :
        ret = super().pars()

        ret['name'] = {
            'index'       : 10,
            'description' : """\
Name of the accessory package (should be <appname>-<accname>)
"""
        }

        ret['app'] = {
            'index'       : 100,
            'description' : """\
Package name of the app to which this is an accessory
"""
        }

        return ret


    def manifestContent( self, pars, directory ):
        return f"""\
{{
    "type"  : "accessory",

    "accessoryinfo" : {{
        "appid"         : "{ pars['app'] }",
        "accessoryid"   : "{ pars['name'] }"
    }},

    "roles" : {{
        "apache2" : {{
            "depends" : [
            ],
            "apache2modules" : [
            ],
            "phpmodules" : [
            ],
            "appconfigitems" : [
            ]
        }}
    }}
    "customizationpoints" : {{
        "title" : {{
            "name"    : "Blog Title",
            "type"    : "string",
            "required" : false,
            "default" : {{
                "value" : "My New Blog"
            }}
        }}
    }}
}}
"""


def create() :
    """
    Factory function
    """
    return Accessory()


def help() :
    return 'generic accessory'

