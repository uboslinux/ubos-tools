#!/usr/bin/perl
#
# Limit rsync to the appconfig's data directory

use strict;
use warnings;

use UBOS::Utils;

unless( exists( $ENV{SSH_ORIGINAL_COMMAND} )) {
    print STDERR "ERROR: Only invoke as part of an rsync transaction.\n";
    exit 1;
}

my $org = $ENV{SSH_ORIGINAL_COMMAND};
# rsync --server -logDtpre.iLsfx . <appconfigid>/bar

# Don't give away the farm
if( $org =~ m![&\(\)\{\};<>`\|]! ) {
    print STDERR "ERROR: Invalid operation.\n";
    exit 2;
}
unless( $org =~ m!^rsync(( -\S+)+) \. (.+)$! ) {
    print STDERR "ERROR: This server only accepts rsync commands.\n";
    exit 3;
}
my $options = $1;
my $dest    = $3;

if( $dest =~ m!\.\.! ) {
    print STDERR "ERROR: Destination path must not contain ..\n";
    exit 4;
}
if( $dest =~ m!\s! ) {
    print STDERR "ERROR: Destination path must not contain white space\n";
    exit 5;
}
unless( $dest =~ m!^(a[0-9a-f]{40})/(.*)$! ) {
    print STDERR "ERROR: Destination path must be of form <appconfigid>/<relpath>\n";
    exit 6;
}
my $appConfigId = $1;
my $relPath     = $2;

my $found = 0;
foreach my $arg ( @ARGV ) {
    if( $appConfigId eq $arg ) {
        $found = 1;
        last;
    }
}
unless( $found ) {
    print STDERR "ERROR: Not permitted\n";
    exit 7;
}

my $fullDest = "/var/lib/ubos-repo/$appConfigId/$relPath";
my $cmd = "rsync$options . $fullDest";

UBOS::Utils::myexec( $cmd );

1;
