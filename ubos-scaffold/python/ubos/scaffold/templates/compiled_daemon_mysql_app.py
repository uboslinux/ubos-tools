#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import os.path
from ubos.scaffold.template import AbstractTemplate
import ubos.scaffold.utils
import ubos.utils


class CompiledDaemonMysqlApp( AbstractTemplate ):

    def generate( self, pars, directory ):

        super().generate( pars, directory )

        systemdService = self.systemdServiceContent( pars, directory )
        if systemdService is not None:
            if not os.path.isdir( directory + "/tmpl" ) :
                ubos.utils.mkdir( directory + "/tmpl" )

            ubos.utils.saveFile( f"{ directory }/tmpl/{ pars['name'] }@.service", systemdService.encode(), 0o644 )


    def pkgbuildContentPackage( self, pars, directory ):

        ret = super().pkgbuildContentPackage( pars, directory );
        ret += """
    # Systemd
    install -D -m0644 \${startdir}/tmpl/*.service \${pkgdir}/usr/lib/systemd/system/
"""
        return ret


    def manifestContent( self, pars, directory ):
        return f"""\
{{
    "type" : "app",

    "roles" : {{
        "apache2" : {{
            "defaultcontext" : "/{ pars['name'] }",
            "apache2modules" : [
                "proxy",
                "proxy_http",
                "headers",
                "proxy_wstunnel",
                "rewrite"
            ],
            "appconfigitems" : [
                {{
                    "type"            : "tcpport",
                    "name"            : "mainport"
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
                }},
                {{
                    "type"            : "file",
                    "name"            : "/etc/{ pars['name'] }/${{appconfig.appconfigid}}.json",
                    "template"        : "tmpl/config.json.tmpl",
                    "templatelang"    : "varsubst"
                }},
                {{
                    "type"            : "systemd-service",
                    "name"            : "{ pars['name'] }@\${{appconfig.appconfigid}}",
                }}
            ]
        }},
        "mysql" : {{
            "appconfigitems" : [
                {{
                    "type"            : "database",
                    "name"            : "maindb",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "maindb",
                    "privileges"      : "all privileges"
                }}
            ]
        }}
    }}
}}
"""

    def htAccessTmplContent( self, pars, directory ):

        return """\
ProxyPass /robots.txt !
ProxyPass /favicon.ico !
ProxyPass /sitemap.xml !
ProxyPass /.well-known !
ProxyPass /_common !
ProxyPass /_errors !

ProxyPass ${appconfig.contextorslash} http://127.0.0.1:${appconfig.tcpport.mainport}${appconfig.contextorslash}
ProxyPassReverse ${appconfig.contextorslash} http://127.0.0.1:${appconfig.tcpport.mainport}${appconfig.contextorslash}
ProxyPassReverseCookieDomain 127.0.0.1 ${site.hostname}

ProxyPreserveHost On

RequestHeader set X-Forwarded-Host "${site.hostname}"
RequestHeader set X-Forwarded-Proto "${site.protocol}"
RequestHeader set X-Frame-Options SAMEORIGIN
"""


    def systemdServiceContent( self, pars, directory ):

        return f"""\
[Unit]
Description={ pars['description'] }

[Service]
WorkingDirectory=/ubos/share/{ pars['name'] }
ExecStart=/usr/share/{ pars['name'] }/bin/{ pars['name'] }d --config=/etc/{ pars['name'] }/%I.json
Restart=always

[Install]
WantedBy=multi-user.target
"""


def create() :
    """
    Factory function
    """
    return CompiledDaemonMysqlApp()


def help() :
    return 'a compiled daemon is run that speaks HTTP at a non-standard port with MySQL or Mariadb'

