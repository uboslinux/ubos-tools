#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from ubos.scaffold.template import AbstractAppOrAccessoryTemplate
import ubos.scaffold.utils


class WordpressTheme( AbstractAppOrAccessoryTemplate ):

    def pkgbuildContentPackage( self, pars, directory ):
        return """
    # Manifest
    install -D -m0644 ${startdir}/ubos-manifest.json ${pkgdir}/ubos/lib/ubos/manifests/${pkgname}.json

    # Icons
    install -D -m0644 ${startdir}/appicons/{72x72,144x144}.png -t ${pkgdir}/ubos/http/_appicons/${pkgname}/

    # Source
    mkdir -p ${pkgdir}/ubos/share/${pkgname}
    cp -a ${startdir}/src/$name ${pkgdir}/ubos/share/${pkgname}/\
"""

    def manifestContent( self, pars, directory ):
        return f"""
{{
    "type"  : "accessory",

    "accessoryinfo" : {{
        "appid"         : "wordpress",
        "accessoryid"   : "{ pars['name'] }",
        "accessorytype" : "theme"
    }},

    "roles" : {{
        "apache2" : {{
            "appconfigitems" : [
                {{
                    "type"   : "directorytree",
                    "name"   : "wp-content/themes/{ pars['name'] }",
                    "source" : "{ pars['name'] }",
                }}
            ],
            "installers" : [
                {{
                    "type"   : "perlscript",
                    "source" : "/usr/share/wordpress/bin/activate-themes.pl"
                }}
            ]
        }}
    }}
}}
"""


def create() :
    """
    Factory function
    """
    return WordpressTheme()


def help() :
    return 'Wordpress theme'

