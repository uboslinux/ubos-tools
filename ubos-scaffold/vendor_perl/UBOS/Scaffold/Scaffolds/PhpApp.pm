#!/usr/bin/perl
#
# A scaffold for PHP app packages on UBOS.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::PhpApp;

use base qw( UBOS::Scaffold::AbstractScaffold );

use UBOS::Scaffold::ScaffoldUtils;

####
sub pkgbuildContentPackage {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $ret = $self->pkgbuildContentPackage( $pars, $dir );
    $ret .= <<END;
# PHP
# install your PHP files here, such as:
# mkdir -p -m0755 \${pkgdir}/ubos/share/\${pkgname}/php
# cp -a \${startdir}/php \${pkgdir}/ubos/share/\${pkgname}/php/

# Webserver configuration
install -D -m0644 \${startdir}/tmpl/htaccess.tmpl \${pkgdir}/ubos/share/\${pkgname}/tmpl/
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
            "defaultcontext" : "/$name",
            "depends" : [
                "php-apache",
                "php-apcu",
                "php-gd"
            ],
            "apache2modules" : [
                "php7",
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
                {
                    "type"            : "directorytree",
                    "names"           : [
                        "index.php",
                    ],
                    "source"          : "$name/\$1",
                    "uname"           : "root",
                    "gname"           : "root",
                    "filepermissions" : "preserve",
                    "dirpermissions"  : "preserve"
                },
                {
                    "type"            : "directory",
                    "name"            : "\${appconfig.datadir}"
                },
                {
                    "type"            : "directory",
                    "name"            : "\${appconfig.datadir}/data",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "datadir",
                    "dirpermissions"  : "0750",
                    "filepermissions" : "0640",
                    "uname"           : "\${apache2.uname}",
                    "gname"           : "\${apache2.gname}"
                },
                {
                    "type"            : "file",
                    "name"            : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"        : "tmpl/htaccess.tmpl",
                    "templatelang"    : "varsubst"
                }
            ]
        },
        "mysql" : {
            "appconfigitems" : [
                {
                    "type"             : "database",
                    "name"             : "maindb",
                    "retentionpolicy"  : "keep",
                    "retentionbucket"  : "maindb",
                    "privileges"       : "all privileges"
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

    return <<END;
<Directory "\${appconfig.apache2.dir}">
  <IfModule php7_module>
    php_admin_value open_basedir        \${appconfig.apache2.dir}:/tmp/:/usr/share/:/dev:\${appconfig.datadir}
    php_value       post_max_size       1G
    php_value       upload_max_filesize 1G
  </IfModule>
</Directory>
<IfModule mod_headers.c>
  Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
</IfModule>
END
}

####
# Return help text.
# return: help text
sub help {
    return 'PHP web app';
}

1;
