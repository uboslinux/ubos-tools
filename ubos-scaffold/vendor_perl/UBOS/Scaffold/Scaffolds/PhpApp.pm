#!/usr/bin/perl
#
# A scaffold for PHP app packages on UBOS.
#
# This file is part of ubos-scaffold.
# (C) 2017 Indie Computing Corp.
#
# ubos-scaffold is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ubos-scaffold is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ubos-scaffold.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::PhpApp;

##
# Declare which parameters should be provided for this scaffold.
sub pars {
    return [
        {
            'name'        => 'name',
            'description' => <<DESC
Name of the package
DESC
        },
        {
            'name'        => 'developer',
            'description' => <<DESC
URL of the developer, such as your company URL
DESC
        },
        {
            'name'        => 'url',
            'description' => <<DESC
URL of the package, such as a product information page on your company website
DESC
        },
        {
            'name'        => 'description',
            'description' => <<DESC
One-line description of your package, which will be shown to the user when
they ask pacman about your package (-i flag to pacman)
DESC
        },
        {
            'name'        => 'license',
            'description' => <<DESC
License of your package, such as GPL, Apache, or Proprietary
DESC
        }
    ];
}

##
# Do the generation
# $pars: the parameters to use
# $dir: the output directory
sub generate {
    my $pars = shift;
    my $dir  = shift;

    my $pkgBuild = <<END;
developer="$pars->{developer}"
url="$pars->{url}"
maintainer=\${developer}
pkgname=$pars->{name}
pkgver=0.1
pkgrel=1
pkgdesc="$pars->{description}"
arch=('any')
license=('$pars->{license}')
depends=(
    # Insert your UBOS package dependencies here as a bash array, like this:
    #     'perl-archive-zip' 'ubos-perl-utils'
    # and close with a parenthesis
)
backup=(
    # List any config files your package uses that should NOT be overridden
    # upon the next package update if the user has modified them.
)

# If your package requires compilation, uncomment this build() function
# and insert your build code.
# build () {
#     echo -n 'Build starts in directory:'
#     pwd
# }

package() {
# Manifest
    mkdir -p \${pkgdir}/var/lib/ubos/manifests
    install -m0644 \${startdir}/ubos-manifest.json \${pkgdir}/var/lib/ubos/manifests/\${pkgname}.json

# Icons
    mkdir -p \${pkgdir}/srv/http/_appicons/\${pkgname}
    install -m644 \${startdir}/appicons/{72x72,144x144}.png \${pkgdir}/srv/http/_appicons/\${pkgname}/

# Data
    mkdir -p \${pkgdir}/var/lib/\${pkgname}

# Code
    mkdir -p \${pkgdir}/usr/share/\${pkgname}
    # install your code here, such as:
    #     install -m0755 \${startdir}/my-\${pkgname}-script \${pkgdir}/usr/bin/

# Webserver configuration
    mkdir -p \${pkgdir}/usr/share/\${pkgname}/tmpl
    install -m644 \${startdir}/tmpl/htaccess.tmpl \${pkgdir}/usr/share/\${pkgname}/tmpl/
}
END

    my $manifest = <<END;
{
    "type" : "app",

    "roles" : {
        "apache2" : {
            "defaultcontext" : "/$pars->{name}",
            "depends" : [
                "php-apache",
                "php-apcu",
                "php-gd",
                "sudo"
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
                    "type" : "directorytree",
                    "names" : [
                        "index.php",
                    ],
                    "source" : "$pars->{name}/\$1",
                    "uname" : "root",
                    "gname" : "root",
                    "filepermissions" : "preserve",
                    "dirpermissions"  : "preserve"
                },
                {
                    "type"  : "directory",
                    "name"  : "\${appconfig.datadir}"
                },
                {
                    "type"  : "directory",
                    "name"  : "\${appconfig.datadir}/data",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "datadir",
                    "dirpermissions"  : "0750",
                    "filepermissions" : "0640",
                    "uname"       : "\${apache2.uname}",
                    "gname"       : "\${apache2.gname}"
                },
                {
                    "type"         : "file",
                    "name"         : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"     : "tmpl/htaccess.tmpl",
                    "templatelang" : "varsubst"
                }
            ]
        },
        "mysql" : {
            "appconfigitems" : [
                {
                    "type"       : "database",
                    "name"       : "maindb",
                    "retentionpolicy"  : "keep",
                    "retentionbucket"  : "maindb",
                    "privileges" : "all privileges"
                }
            ]
        }
    }
}
END

    my $htAccessTmpl = <<END;
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

    UBOS::Utils::mkdir( "$dir/tmpl" );
    UBOS::Utils::mkdir( "$dir/appicons" );

    UBOS::Utils::saveFile( "$dir/PKGBUILD",           $pkgBuild,     0644 );
    UBOS::Utils::saveFile( "$dir/ubos-manifest.json", $manifest,     0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/htaccess.tmpl", $htAccessTmpl, 0644 );

    UBOS::Scaffold::ScaffoldUtils::copyIcons( "$dir/appicons" );
}

##
# Return help text.
# return: help text
sub help {
    return 'A PHP app';
}

1;
