#!/usr/bin/python
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import os.path
from ubos.scaffold.template import AbstractTemplate
import ubos.scaffold.utils


class PythonMysqlApp( AbstractTemplate ):

    def generate( self, pars, directory ):

        super().generate( pars, directory )

        wsgiTmpl = self.wsgiTmplContent( pars, directory );
        if wsgiTmpl :
            if not os.path.isdir( directory + "/tmpl" ) :
                ubos.utils.mkdir( directory + "/tmpl" )

            ubos.utils.saveFile( f"{ directory }/tmpl/wsgi.py.tmpl", wsgiTmpl.encode(), 0o644 )


    def pkgbuildContentVars( self, pars, directory ):

        ret = super().pkgbuildContentVars( pars, directory )
        ret['pkgver']  = "$(cat PKGVER) # Maintain the package version in a separate file"
        ret['depends'] = """\
(
    # Insert your UBOS package dependencies here as a bash array, like this:
    'python'
    # 'python-lxml'
    # 'python-pillow'
)\
"""
        ret['makedepends'] = """\
(
    # Insert the UBOS build-time package dependencies here, like this:
    'python-setuptools'
)\
"""
        return ret


    def pkgbuildContentBuild( self, pars, directory ):

        return """\
    # Insert your python build commands here
"""

    def pkgbuildContentPackage( self, pars, directory ):

        ret = super().pkgbuildContentPackage( pars, directory );
        ret += """\
    # Insert your python install commands here, like this:
    [[ -d "${srcdir}/build" ]] || mkdir -p "${srcdir}/build"
    cd "${srcdir}/build"

    cp -a "${startdir}/python/"* .

    python setup.py install --root=${pkgdir} --optimize=1
"""
        return ret


    def manifestContent( self, pars, directory ):
        return f"""\
{{
    "type" : "app",

    "roles" : {{
        "apache2" : {{
            "defaultcontext"       : "/{ pars['name'] }",
            "depends" : [
                "mod_wsgi"
            ],
            "apache2modules" : [
                "wsgi"
            ],
            "appconfigitems" : [
                {{
                    "type"         : "directory",
                    "name"         : "${{appconfig.datadir}}",
                    "uname"        : "${{apache2.uname}}",
                    "gname"        : "${{apache2.gname}}"
                }},
                {{
                    "type"         : "directory",
                    "names" : [
                        "${{appconfig.cachedir}}",
                        "${{appconfig.cachedir}}/egg-cache",
                    ],
                    "uname"        : "${{apache2.uname}}",
                    "gname"        : "${{apache2.gname}}"
                }},
                {{
                    "type"         : "file",
                    "name"         : "${{appconfig.apache2.dir}}/wsgi.py",
                    "template"     : "tmpl/wsgi.py.tmpl",
                    "templatelang" : "varsubst"
                }},
                {{
                    "type"         : "file",
                    "name"         : "${{appconfig.datadir}}/{ pars['name'] }.ini",
                    "template"     : "tmpl/$name.ini.tmpl",
                    "templatelang" : "varsubst"
                }},
                {{
                    "type"         : "file",
                    "name"         : "${{appconfig.apache2.appconfigfragmentfile}}",
                    "template"     : "tmpl/htaccess.tmpl",
                    "templatelang" : "varsubst"
                }}
            ]
        }},
        "postgresql" : {{
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
        return f"""\
Alias ${{appconfig.context}}/static/ ${{package.codedir}}/web/static/

WSGIScriptAlias ${{appconfig.contextorslash}} ${{appconfig.apache2.dir}}/wsgi.py

WSGIPassAuthorization On
WSGIDaemonProcess { pars['name'] }-${{appconfig.appconfigid}} processes=2 threads=10 umask=0007 inactivity-timeout=900 maximum-requests=1000 python-path=${{package.codedir}}
WSGIProcessGroup { pars['name'] }-${{appconfig.appconfigid}}

# Can't do this because there may be more than one WSGI app:
# WSGIApplicationGroup %{{GLOBAL}}

<Directory "${{package.codedir}}/static">
    Require all granted
</Directory>
"""


    def wsgiTmplContent( self, pars, directory ):
        return """\
#!${package.codedir}/bin/python

import os
os.environ['PYTHON_EGG_CACHE'] = '${appconfig.cachedir}/egg-cache'

import site
site.addsitedir('${package.codedir}/site-packages')

from paste.deploy import loadapp

CONFIG_PATH = '${appconfig.datadir}/paste.ini'
application = loadapp('config:' + CONFIG_PATH)
"""


def create() :
    """
    Factory function
    """
    return PythonMysqlApp()


def help() :
    return 'Python web app using WSGI with MySQL or Mariadb'

