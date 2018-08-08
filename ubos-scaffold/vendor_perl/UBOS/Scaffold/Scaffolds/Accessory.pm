#!/usr/bin/perl
#
# A scaffold for some kind of application accessory package on UBOS.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::Accessory;

use base qw( UBOS::Scaffold::AbstractScaffold );

use UBOS::Scaffold::ScaffoldUtils;

####
sub pars {
    my $self = shift;

    my $ret = $self->SUPER::pars();
    $ret->{name} = {
        'index'       => 10,
        'description' => <<DESC
Name of the accessory package (should be <appname>-<accname>)
DESC
    };
    $ret->{app} = {
        'index'       => 100,
        'description' => <<DESC
Package name of the app to which this is an accessory
DESC
    };
    return $ret;
}

####
sub manifestContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};
    my $app  = $pars->{app};

    return <<END;
{
    "type"  : "accessory",

    "accessoryinfo" : {
        "appid"         : "$app",
        "accessoryid"   : "$name"
    },

    "roles" : {
        "apache2" : {
            "appconfigitems" : [
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
    return 'generic accessory';
}

1;
