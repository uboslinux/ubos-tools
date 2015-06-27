#!/usr/bin/perl
#
# Limit rsync to the appconfig's data directory

use strict;
use warnings;

use UBOS::Utils;

my $appConfigId = $ARGV[0];
my $org         = $ENV{SSH_ORIGINAL_COMMAND};
# something like:
# rsync --server -logDtpre.iLsfx . bar

UBOS::Utils::saveFile( '/tmp/foo', $org );

unless( $org =~ m!^rsync(( -\S+)+) \. (.+)$! ) {
    print STDERR "ERROR: This server only accepts rsync commands.\n";
    exit 1;
}
my $options = $1;
my $dest    = $3;

if( $dest =~ m!^/! ) {
    print STDERR "ERROR: Only relative destination paths accepted.\n";
    exit 2;
}
if( $dest =~ m!\.\.! ) {
    print STDERR "ERROR: Destination path must not contain ..\n";
    exit 3;
}

my $fullDest = "/var/lib/ubos-repo/$appConfigId/$dest";
my $cmd = "rsync$options . $fullDest";

UBOS::Utils::myexec( $cmd );

1;
