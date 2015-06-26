#!/usr/bin/perl
#
# Provision an entry in ~ubos-repo/.ssh/authorized_keys
#
# Expects the entire content of id_rsa.pub to be provided as publicsshkey

use strict;
use warnings;

use UBOS::Utils;

my $appConfigId = $config->getResolve( 'appconfig.appconfigid' );
my $sshKey      = $config->getResolve( 'installable.customizationpoints.publicsshkey.value' );

$sshKey =~ s!^\s+!!;
$sshKey =~ s!\s+$!!;

my( $name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam( 'ubos-repo' ) ;

my $sshDir            = "$dir/.ssh";
my $authorizedKeyFile = "$sshDir/authorized_keys";
my $content           = '';

unless( -d $sshDir ) {
    UBOS::Utils::mkdir( $sshDir, 0700, $uid, $gid );
}

if( -e $authorizedKeyFile ) {
    $content = UBOS::Utils::slurpFile( $authorizedKeyFile );
}
# From the man page:
# Each  line of the file contains one key (empty lines and lines starting with a `#' are
# ignored as comments).
# Protocol 2 public key consist of: options, keytype, base64-encoded key, comment.
# The options field is optional; its presence is determined by
# whether the line starts with a number or not (the options field never starts with a number).
# For protocol version 2 the keytype is ``ecdsa-sha2-nistp256'', ``ecdsa-sha2-nistp384'',
# ``ecdsa-sha2-nistp521'', ``ssh-ed25519'', ``ssh-dss'' or ``ssh-rsa''.
#
# e.g.
# ssh-rsa AAAAB3...Y3yjYd user@example.com
#
# The options (if present) consist of comma-separated option specifications. No spaces are
# permitted, except within double quotes.
#
# command="command"
# Specifies that the command is executed whenever this key is used for authentication.
# The command supplied by the user (if any) is ignored.
# A quote may be included in the command by quoting it with a  backslash.
# This  option might be useful to restrict certain public keys to perform just a specific
# operation. The  command  originally  supplied by the client is available in the
# SSH_ORIGINAL_COMMAND environment variable. Note that this option applies to shell,
# command or subsystem execution. Also note that this command may be  superseded by either
# a sshd_config(5) ForceCommand directive or a command embedded in a certificate.

if( 'deploy' eq $operation ) {
    # Add entry
    $content .= <<LINE;
command="/usr/share/ubos-repo/bin/safe-rsync.pl $appConfigId" $sshKey $appConfigId
LINE
    UBOS::Utils::saveFile( $authorizedKeyFile, $content, 0600, $uid, $gid );
}
if( 'undeploy' eq $operation ) {
    # Remove entry
    $content =~ s!^(.+) \Q$sshKey\E (.+)$!!m;
    UBOS::Utils::saveFile( $authorizedKeyFile, $content, 0600, $uid, $gid );
}


1;
