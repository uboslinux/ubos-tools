#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

from ubos.scaffold.template import AbstractAppOrAccessoryTemplate
import ubos.scaffold.utils


class PhpMysqlApp( AbstractAppOrAccessoryTemplate ):

    def pkgbuildContentPackage( self, pars, directory ):

        ret = super().pkgbuildContentPackage( pars, directory )
        ret += """
    # PHP
    # mkdir -p -m0755 ${pkgdir}/ubos/share/${pkgname}/php
    # cp -a ${startdir}/php ${pkgdir}/ubos/share/${pkgname}/php/

    # Webserver configuration
    install -D -m0644 ${startdir}/tmpl/htaccess.tmpl ${pkgdir}/ubos/share/${pkgname}/tmpl/
"""
        return ret


    def manifestContent( self, pars, directory ):
        return f"""\
{{
    "type" : "app",

    "roles" : {{
        "apache2" : {{
            "defaultcontext" : "/{ pars['name'] }",
            "depends" : [
                "php-apache",
                "php-apcu",
                "php-gd"
            ],
            "apache2modules" : [
                "php",
                "rewrite",
                "headers",
                "env",
                "setenvif"
            ],
            "phpmodules" : [
                "apcu",
                "gd",
                "iconv",
                "mysqli",
                "pdo_mysql"
            ],
            "appconfigitems" : [
                {{
                    "type"            : "directorytree",
                    "names"           : [
                        "index.php",
                    ],
                    "source"          : "{ pars['name'] }/$1",
                    "uname"           : "root",
                    "gname"           : "root",
                    "filepermissions" : "preserve",
                    "dirpermissions"  : "preserve"
                }},
                {{
                    "type"            : "directory",
                    "name"            : "${{appconfig.datadir}}"
                }},
                {{
                    "type"            : "directory",
                    "name"            : "${{appconfig.datadir}}/data",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "datadir",
                    "dirpermissions"  : "0750",
                    "filepermissions" : "0640",
                    "uname"           : "${{apache2.uname}}",
                    "gname"           : "${{apache2.gname}}"
                }},
                {{
                    "type"            : "file",
                    "name"            : "${{appconfig.apache2.appconfigfragmentfile}}",
                    "template"        : "tmpl/htaccess.tmpl",
                    "templatelang"    : "varsubst"
                }}
            ]
        }},
        "mysql" : {{
            "appconfigitems" : [
                {{
                    "type"             : "database",
                    "name"             : "maindb",
                    "retentionpolicy"  : "keep",
                    "retentionbucket"  : "maindb",
                    "privileges"       : "all privileges"
                }}
            ]
        }}
    }}
}}
"""


    def htAccessTmplContent( self, pars, directory ):

        return """\
<Directory "${appconfig.apache2.dir}">
  <IfModule php_module>
    php_admin_value open_basedir        ${appconfig.apache2.dir}:/tmp/:/usr/share/:/dev:${appconfig.datadir}
    php_value       post_max_size       1G
    php_value       upload_max_filesize 1G
  </IfModule>
</Directory>
<IfModule mod_headers.c>
  Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
</IfModule>
"""


def create() :
    """
    Factory function
    """
    return PhpMysqlApp()


def help() :
    return 'PHP web app with MySQL or Mariadb'

