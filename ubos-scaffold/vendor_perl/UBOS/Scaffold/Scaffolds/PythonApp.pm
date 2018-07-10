#!/usr/bin/perl
#
# A scaffold for Python app packages on UBOS.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::PythonApp;

use base qw( UBOS::Scaffold::AbstractScaffold );

use UBOS::Scaffold::ScaffoldUtils;

####
sub generate {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    $self->SUPER::generate( $pars, $dir );
    
    my $packageName = $pars->{name};

    my $wsgiTmpl = $self->wsgiTmplContent( $pars, $dir );
    if( $wsgiTmpl ) {
        unless( -d "$dir/tmpl" ) {
            UBOS::Utils::mkdir( "$dir/tmpl" );
        }
        UBOS::Utils::saveFile( "$dir/tmpl/wsgi.py.tmpl", $wsgiTmpl, 0644 );
    }
}

####
sub pkgbuildContentVars {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $ret = $self->pkgbuildContentVars( $pars, $dir );
    $ret->{depends} = <<END;
(
# Insert your UBOS package dependencies here as a bash array, like this:
#     'python' 'python-lxml' 'python-pillow' 'python-psycopg2' 'python-setuptools'
# and close with a parenthesis
)
END
    $ret->{makedepends} = <<END;
(
# Insert the UBOS build-time package dependencies here, like this:
#     'python-virtualenv'
)
END
    return $ret;
}

####
sub pkgbuildContentBuild {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    return <<END;
# Insert your python build commands here, like this:
#     cd "\${srcdir}/\${pkgname}-\${pkgver}"
#     [ -d site-packages ] || mkdir site-packages
#     PYTHONPATH=\$(pwd)/site-packages python2 setup.py develop --verbose --install-dir \$(pwd)/site-packages
END
}

####
sub pkgbuildContentPackage {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $ret = $self->pkgbuildContentPackage( $pars, $dir );
    $ret .= <<END;
# Python
# install your Python files here, such as:
# mkdir -p -m0755 \${pkgdir}/ubos/share/\${pkgname}/site-packages
# cp -a \${startdir}/site-packages \${pkgdir}/ubos/share/\${pkgname}/site-packages
END
    return $ret;
}

####
sub manifestContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};

    return <<END;
{
    "type" : "app",

    "roles" : {
        "apache2" : {
            "defaultcontext"          : "/$name",
            "depends" : [
                "mod_wsgi"
            ],
            "apache2modules" : [
                "wsgi"
            ],
            "appconfigitems" : [
                {
                    "type"            : "directory",
                    "name"            : "\${appconfig.datadir}",
                    "uname"           : "\${apache2.uname}",
                    "gname"           : "\${apache2.gname}"
                },
                {
                    "type"            : "directory",
                    "names" : [
                        "\${appconfig.cachedir}",
                        "\${appconfig.cachedir}/egg-cache",
                    ],
                    "uname"           : "\${apache2.uname}",
                    "gname"           : "\${apache2.gname}"
                },
                {
                    "type"            : "file",
                    "name"            : "\${appconfig.apache2.dir}/wsgi.py",
                    "template"        : "tmpl/wsgi.py.tmpl",
                    "templatelang"    : "varsubst"
                },
                {
                    "type"            : "file",
                    "name"            : "\${appconfig.datadir}/$name.ini",
                    "template"        : "tmpl/$name.ini.tmpl",
                    "templatelang"    : "varsubst"
                },
                {
                    "type"            : "file",
                    "name"            : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"        : "tmpl/htaccess.tmpl",
                    "templatelang"    : "varsubst"
                }
            ]
        },
        "postgresql" : {
            "appconfigitems" : [
                {
                    "type"            : "database",
                    "name"            : "maindb",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "maindb",
                    "privileges"      : "all privileges"
                }
            ]
        }
    }
}
END
}

####
sub htAccessTmplContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};

    return <<END;
Alias \${appconfig.context}/static/ \${package.codedir}/web/static/

WSGIScriptAlias \${appconfig.contextorslash} \${appconfig.apache2.dir}/wsgi.py

WSGIPassAuthorization On
WSGIDaemonProcess $name-\${appconfig.appconfigid} processes=2 threads=10 \
       umask=0007 inactivity-timeout=900 maximum-requests=1000 \
       python-path=\${package.codedir}
WSGIProcessGroup $name-\${appconfig.appconfigid}

# Can't do this because there may be more than one WSGI app:
# WSGIApplicationGroup %{GLOBAL}

<Directory "\${package.codedir}/static">
    Require all granted
</Directory>
END
}

####
sub wsgiTmplContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    return <<END;
#!\${package.codedir}/bin/python2

import os
os.environ['PYTHON_EGG_CACHE'] = '\${appconfig.cachedir}/egg-cache'

import site
site.addsitedir('\${package.codedir}/site-packages')

from paste.deploy import loadapp

CONFIG_PATH = '\${appconfig.datadir}/paste.ini'
application = loadapp('config:' + CONFIG_PATH)
END
}

####
# Return help text.
# return: help text
sub help {
    return 'Python app using WSGI';
}

1;

