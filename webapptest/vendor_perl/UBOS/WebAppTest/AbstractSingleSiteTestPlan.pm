#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans that use a single site.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::AbstractSingleSiteTestPlan;

use base   qw( UBOS::WebAppTest::AbstractTestPlan );
use fields qw( siteJson appConfigJson );

use UBOS::Logging;

##
# Instantiate the TestPlan.
# $test: the test to run
# $options: options for the test plan
# $tlsData: if given, the TLS section of the Site JSON to use
sub new {
    my $self    = shift;
    my $test    = shift;
    my $options = shift;
    my $tlsData = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $test, $options );

    my $hostname;
    my $context;

    if( exists( $options->{siteJson} )) {
        unless( exists( $options->{appConfigJson} )) {
            fatal( 'If specifying siteJson, you also need to specify appConfigJson' );
        }
        if( exists( $options->{hostname} )) {
            fatal( 'If specifying siteJson, you must not specify hostname' );
        }
        if( exists( $options->{context} )) {
            fatal( 'If specifying siteJson, you must not specify context' );
        }
        $self->{siteJson}      = $options->{siteJson};
        $self->{appConfigJson} = $options->{appConfigJson};
        delete $options->{siteJson};
        delete $options->{appConfigJson};

    } elsif( exists( $options->{appConfigJson} )) {
        fatal( 'If specifying appConfigJson, you also need to specify siteJson' );

    } else {
        if( exists( $options->{hostname} )) {
            if( $options->{hostname} ne '*' && $options->{hostname} !~ m!^[-.a-z0-9_]+$! ) {
                fatal( 'Test plan hostname parameter must be a valid hostname, or *' );
            }

            $hostname = $options->{hostname};
            delete $options->{hostname};
        }
        unless( $hostname ) {
            my $temp = ref $self;
            $temp =~ s!^.*::!!;
            $hostname = 'testhost-' . lc( $temp ) . UBOS::Utils::randomHex( 8 );
        }

        $context = $test->getFixedTestContext();
        if( defined( $context )) {
            if( defined( $options->{context} )) {
                warning( 'Context', $options->{context}, 'provided as argument to test plan ignored: WebAppTest requires fixed test context', $self->{context} );
            }
            delete $options->{context};
        } elsif( defined( $options->{context} )) {
            $context = $options->{context};
            delete $options->{context};
        } else {
            $context = '/ctxt-' . UBOS::Utils::randomHex( 8 );
        }
        if( $context ne '' && $context !~ m!^/[-_.a-z0-9%]+$! ) {
            fatal( 'Context parameter must be a single-level relative path starting with a slash, or be empty' );
        }

        $self->{appConfigJson} = {
            'context'     => $context,
            'appid'       => $test->appPackageName()
        };
        if( $test->accessoryPackageNames() ) {
            $self->{appConfigJson}->{accessoryids} = [ $test->accessoryPackageNames() ];
        }

        my $custPointValues = $test->getCustomizationPointValues();
        if( $custPointValues ) {
            foreach my $package ( $test->appPackageName(), $test->accessoryPackageNames()) {
                if( exists( $custPointValues->{$package} )) {
                    my $jsonHash = {};
                    $self->{appConfigJson}->{customizationpoints}->{$package} = $jsonHash;

                    foreach my $name ( keys %{$custPointValues->{$package}} ) {
                        my $value = $custPointValues->{$package}->{$name};

                        $jsonHash->{$name}->{value} = $value;
                    }
                }
            }
        }

        my $admin = {
                'userid'     => 'testuser',
                'username'   => 'Test User',
                'credential' => 'verys3cr3t', # This is of course not secure, but we're trying
                                              # to be memorable here so the user can easily log
                                              # on in interactive mode. To be secure, override
                                              # this method in your test.
                'email'      => 'testing@ignore.ubos.net'
        };

        $self->{siteJson} = {
                'siteid'     =>  's' . UBOS::Utils::randomHex( 40 ), # Generate here so we know what it is
                'hostname'   => $hostname,
                'admin'      => $admin,
                'appconfigs' => [ $self->{appConfigJson} ]
        };
    }
    if( defined( $tlsData )) {
        $self->{siteJson}->{tls} = $tlsData;
    }

    return $self;
}

##
# Run this TestPlan
# $scaffold: the Scaffold to use
# $interactive: if 1, ask the user what to do after each error
# $verbose: verbosity level from 0 (not verbose) upwards
sub run {
    my $self        = shift;
    my $scaffold    = shift;
    my $interactive = shift;
    my $verbose     = shift;

    error( 'Must override UBOS::WebAppTest::AbstractSingleSiteTestPlan::run' );
}

##
# Determine the protocol through which the test is performed.
# return: http, or https
sub protocol {
    my $self = shift;

    if( exists( $self->{siteJson}->{tls} )) {
        return 'https';
    } else {
        return 'http';
    }
}

##
# Obtain the hostname at which the test is performed.
# return: hostname
sub hostname {
    my $self = shift;

    return $self->{siteJson}->{hostname};
}

##
# Obtain the context at which the test is performed.
# return: context
sub context {
    my $self = shift;

    return $self->{appConfigJson}->{context};
}

##
# Obtain the siteId of the site currently being tested.
# return: the siteId
sub siteId {
    my $self = shift;

    return $self->{siteJson}->{siteid};
}

##
# Obtain the appconfigid of the AppConfiguration currently being tested.
# return the appconfigid
sub appConfigId {
    my $self = shift;

    return $self->{appConfigJson}->{appconfigid};
}

##
# Obtain the Site JSON for this test.
# return the Site JSON
sub getSiteJson {
    my $self = shift;

    return $self->{siteJson};
}

##
# Some test plans need to change the Site JSON
# $json: the new Site JSON
sub setSiteJson {
    my $self = shift;
    my $json = shift;

    $self->{siteJson} = $json;
}

##
# Obtain the AppConfig JSON for this test.
# return: the AppConfig JSON
sub getAppConfigJson {
    my $self = shift;

    return $self->{appConfigJson};
}

##
# Some test plans need to change the AppConfig JSON
# $json: the new AppConfig JSON
sub setAppConfigJson {
    my $self = shift;
    my $json = shift;

    $self->{appConfigJson} = $json;
}

##
# Returns the admin information for the Site.
# return: hash
sub getAdminData {
    my $self = shift;

    return $self->{siteJson}->{admin};
}

1;
