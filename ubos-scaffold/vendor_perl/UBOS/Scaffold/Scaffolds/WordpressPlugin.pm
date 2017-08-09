#!/usr/bin/perl
#
# A scaffold for Wordpress plugins on UBOS.
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

package UBOS::Scaffold::Scaffolds::WordpressPlugin;

use UBOS::Scaffold::ScaffoldUtils;

##
# Declare which parameters should be provided for this scaffold.
sub pars {
    return [
        {
            'name'        => 'name',
            'description' => <<DESC
Name of the Wordpress plugin
DESC
        },
        {
            'name'        => 'version',
            'description' => <<DESC
Current version of the plugin
DESC
        },
        {
            'name'        => 'developer',
            'description' => <<DESC
URL of the developer, such as your company URL
DESC
        },
        {
            'name'        => 'description',
            'description' => <<DESC
One-line description of your package, which will be shown to the user when
they ask pacman about your package (-i flag to pacman)
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

    my $packageName = 'wordpress-theme-' . $pars->{name};
    unless( $dir ) {
        $dir = $packageName;
        UBOS::Scaffold::ScaffoldUtils::ensurePackageDirectory( $dir );
    }

    my $pkgBuild = <<END;
#
# PKGBUILD for package $pars->{name}, generated by ubos-scaffold.
# For the syntax of this file, please refer to the description on the
# Arch Linux wiki here: https://wiki.archlinux.org/index.php/PKGBUILD
#

developer='$pars->{developer}'
url='url=https://wordpress.org/plugins/$pars->{name}/'
maintainer='\${developer}'
pkgname='$packageName'
pkgver=$pars->{version}
pkgrel=1
pkgdesc='$pars->{description}'
arch=('any')
license=('GPL')
depends=(
    # Insert your UBOS package dependencies here as a bash array, like this:
    #     'wordpress'
    # and close with a parenthesis
)
source=(
    "http://downloads.wordpress.org/plugin/$pars->{name}.\${pkgver}.zip"
)
sha512sums=(
    # Change this checksum to the correct one. Find out what it is by
    # running "makepkg -g"
    'fixme'
)

package() {
# Manifest
    mkdir -p \${pkgdir}/var/lib/ubos/manifests
    install -m0644 \${startdir}/ubos-manifest.json \${pkgdir}/var/lib/ubos/manifests/\${pkgname}.json

# Icons
    mkdir -p \${pkgdir}/srv/http/_appicons/\${pkgname}
    install -m644 \${startdir}/appicons/{72x72,144x144}.png \${pkgdir}/srv/http/_appicons/\${pkgname}/

# Source
    mkdir -p \${pkgdir}/usr/share/\${pkgname}

    cp -a \${startdir}/src/$pars->{name} \${pkgdir}/usr/share/\${pkgname}/
}
END

    my $manifest = <<END;
{
    "type"  : "accessory",

    "accessoryinfo" : {
        "appid"         : "wordpress",
        "accessoryid"   : "$pars->{name}",
        "accessorytype" : "plugin"
    },

    "roles" : {
        "apache2" : {
            "appconfigitems" : [
                {
                    "type"   : "directorytree",
                    "name"   : "wp-content/plugins/$pars->{name}",
                    "source" : "$pars->{name}",
                }
            ],
            "installers" : [
                {
                    "type"   : "perlscript",
                    "source" : "/usr/share/wordpress/bin/activate-plugin.pl"
                }
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
    return 'Wordpress plugin';
}

1;
