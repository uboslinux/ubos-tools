#!/usr/bin/perl
#
# A scaffold for some kind of application accessory package on UBOS.
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

package UBOS::Scaffold::Scaffolds::Accessory;

##
# Declare which parameters should be provided for this scaffold.
sub pars {
    return [
        {
            'name'        => 'name',
            'description' => <<DESC
Name of the accessory package (should be <appname>-<accname>)
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
        },
        {
            'name'        => 'app',
            'description' => <<DESC
Package name of the app to which this is an accessory
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
#
# PKGBUILD for package $pars->{name}, generated by ubos-scaffold.
# For the syntax of this file, please refer to the description on the
# Arch Linux wiki here: https://wiki.archlinux.org/index.php/PKGBUILD
#

developer='$pars->{developer}'
url='$pars->{url}'
maintainer='\${developer}'
pkgname='$pars->{name}'
pkgver=0.1
pkgrel=1
pkgdesc='$pars->{description}'
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
source=(
    # Insert URLs to the source(s) of your code here, usually one or more tar files
    # or such, like this:
    #     "https://download.nextcloud.com/server/releases/nextcloud-\${pkgver}.tar.bz2"
)
sha512sums=(
    # List the checksums for one source at a time, same sequence as the in
    # the sources array, like this:
    #     '1c1e59d3733d4c1073c19f54c8eda48f71a7f9e8db74db7ab761fcd950445f7541bce5d9ac800238ab7099ff760cb51bd59b7426020128873fa166870c58f125'
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

# Code
    mkdir -p \${pkgdir}/usr/share/\${pkgname}
    # install your code here, such as:
    #     install -m0755 \${startdir}/my-\${pkgname}-script \${pkgdir}/usr/bin/
}
END

    my $manifest = <<END;
{
    "type"  : "accessory",

    "accessoryinfo" : {
        "appid"         : "$pars->{app}",
        "accessoryid"   : "$pars->{name}"
    },

    "roles" : {
        "apache2" : {
            "appconfigitems" : [
            ]
        }
    }
}

END

    UBOS::Utils::mkdir( "$dir/appicons" );

    UBOS::Utils::saveFile( "$dir/PKGBUILD",           $pkgBuild,     0644 );
    UBOS::Utils::saveFile( "$dir/ubos-manifest.json", $manifest,     0644 );

    UBOS::Scaffold::ScaffoldUtils::copyIcons( "$dir/appicons" );
    }

##
# Return help text.
# return: help text
sub help {
    return 'generic accessory';
}

1;