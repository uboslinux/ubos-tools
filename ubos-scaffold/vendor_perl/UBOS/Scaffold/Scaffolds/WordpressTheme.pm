#!/usr/bin/perl
#
# A scaffold for Wordpress themes on UBOS.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::WordpressTheme;

use base qw( UBOS::Scaffold::Scaffolds::WordpressPlugin );

use UBOS::Scaffold::ScaffoldUtils;

####
sub pkgbuildContentPackage {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};

    return <<END;
# Manifest
install -D -m0644 \${startdir}/ubos-manifest.json \${pkgdir}/ubos/lib/ubos/manifests/\${pkgname}.json

# Icons
install -D -m0644 \${startdir}/appicons/{72x72,144x144}.png -t \${pkgdir}/ubos/http/_appicons/\${pkgname}/

# Source
mkdir -p \${pkgdir}/ubos/share/\${pkgname}
cp -a \${startdir}/src/$name \${pkgdir}/ubos/share/\${pkgname}/
END
}

####
sub manifestContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};

    return <<END;
{
    "type"  : "accessory",

    "accessoryinfo" : {
        "appid"         : "wordpress",
        "accessoryid"   : "$name",
        "accessorytype" : "theme"
    },

    "roles" : {
        "apache2" : {
            "appconfigitems" : [
                {
                    "type"   : "directorytree",
                    "name"   : "wp-content/themes/$name",
                    "source" : "$pname",
                }
            ],
            "installers" : [
                {
                    "type"   : "perlscript",
                    "source" : "/usr/share/wordpress/bin/activate-theme.pl"
                }
            ]
        }
    }
}
END
}

####
# Return help text.
# return: help text
sub help {
    return 'Wordpress theme';
}

1;
