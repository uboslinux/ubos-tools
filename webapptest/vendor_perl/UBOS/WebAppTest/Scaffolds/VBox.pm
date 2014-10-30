#!/usr/bin/perl
#
# A scaffold for running tests on the local machine inside a
# VirtualBox virtual machine.
#
# The virtual machine is configured with two network interfaces:
# 1: uses NAT networking, so it can access the public internet and
#    download new packages if the test requires that.
# 2: uses hostonly, so the host can do HTTP get on web apps
#
# The following options can be provied:
# * vmdktemplate (required): name of a VMDK file containing a VirtualBox
#   virtual Indie Box. This file will only be copied as a template, and
#   not modified by tests
# * vmdkfile (optional): name of the copy of the VMDK template file
# * ram (optional): amount of RAM to allocate to the guest
# * ubos-admin-private-key-file and ubos-admin-public-key-file (required):
#   private and public ssh key for the ubos-admin user on the guest, so the
#   scaffold can create an ubos-admin user and invoke 'sudo ubos-admin' on
#   the guest
# * vncsecret (optional): if provided, the guest will be instantiated
#   with its display available via VNC, and this password
#
# This file is part of webapptest.
# (C) 2012-2014 Indie Computing Corp.
#
# webapptest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# webapptest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with webapptest.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package UBOS::WebAppTest::Scaffolds::VBox;

use base qw( UBOS::WebAppTest::AbstractScaffold );
use fields qw( vmdkTemplate vmdkFile ubosAdminPublicKeyFile ubosAdminPrivateKeyFile vmName hostOnlyIp configVmdkFile );

use File::Temp;
use UBOS::Logging;
use UBOS::Utils;

# name of the hostonly interface
my $hostonlyInterface = 'vboxnet0';

# how many seconds until we give up waiting for boot
my $bootMaxSeconds = 240;
# how many seconds until we give up that pacman keys have been initialized
my $keysMaxSeconds = 60;

# how many seconds until we give up waiting for shutdown
my $shutdownMaxSeconds = 120;

##
# Instantiate the Scaffold.
# $options: hash of options
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup();

    $self->{isOk} = 0; # until we decide otherwise

    my $vmName = 'webapptest-' . UBOS::Utils::time2string( time() );
    $self->{vmName} = $vmName;

    debug( 'Creating VBox VM', $vmName );

    unless( exists( $options->{vmdktemplate} )) {
        fatal( 'No value provided for vmdktemplate' );
    }
    unless( $options->{vmdktemplate} =~ m!\.vmdk$! ) {
        fatal( 'Vmdktemplate file must have extension .vmdk, is:', $options->{vmdktemplate} );
    }
    unless( -r $options->{vmdktemplate} ) {
        fatal( 'Vmdktemplate file does not exist or cannot be read:', $options->{vmdktemplate} );
    }

    unless( exists( $options->{vmdkfile} )) {
        $options->{vmdkfile} = "$vmName.vmdk";
    }
    unless( $options->{vmdkfile} =~ m!\.vmdk$! ) {
        fatal( 'Vmdkfile file must have extension .vmdk, is:', $options->{vmdkfile} );
    }
    if( -e $options->{vmdkfile} ) {
        fatal( 'Vmdkfile file exists already:', $options->{vmdkfile} );
    }

    unless( exists( $options->{'ubos-admin-public-key-file'} ) && $options->{'ubos-admin-public-key-file'} ) {
        fatal( 'No value provided for ubos-admin-public-key-file' );
    }
    unless( -r $options->{'ubos-admin-public-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'ubos-admin-public-key-file'} );
    }
    unless( exists( $options->{'ubos-admin-private-key-file'} ) && $options->{'ubos-admin-private-key-file'} ) {
        fatal( 'No value provided for ubos-admin-private-key-file' );
    }
    unless( -r $options->{'ubos-admin-private-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'ubos-admin-private-key-file'} );
    }

    if( exists( $options->{ram} ) && $options->{ram} !~ m!^\d+$! ) {
        fatal( 'Option ram must be an integer' );
    }

    if( exists( $options->{vncsecret} ) && !$options->{vncsecret} ) {
        fatal( 'Vncsecret cannot be empty' );
    }

    $self->{vmdkTemplate}            = $options->{vmdktemplate};
    $self->{vmdkFile}                = $options->{vmdkfile};
    $self->{ubosAdminPublicKeyFile}  = $options->{'ubos-admin-public-key-file'};
    $self->{ubosAdminPrivateKeyFile} = $options->{'ubos-admin-private-key-file'};
    my $ram                          = $options->{ram} || 512;
    my $vncSecret                    = $options->{vncsecret};

    info( 'Creating Scaffold VBox' );

    my $out;
    my $err;
    
    debug( 'Copying VMDK file to', $self->{vmdkFile} );
    if( UBOS::Utils::myexec( 'cp ' . $self->{vmdkTemplate} . ' ' . $self->{vmdkFile} )) {
        fatal( 'Copying VMDK file failed' );
    }

    debug( 'Defining VM' );
    if( UBOS::Utils::myexec( "VBoxManage createvm -name '$vmName' -ostype Linux_64 -register", undef, \$out, \$err )) {
        fatal( 'VBoxManage createvm failed:', $err );
    }

    debug( 'Setting RAM' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --memory $ram" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Configuring hostonly if' );
    # VBoxManage hostonlyif remove vboxnet0 manages to hang the machine! So we try not to do that any more.
    
    UBOS::Utils::myexec( "ip link show vboxnet0 > /dev/null || VBoxManage hostonlyif create" );
    if( UBOS::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Adding NIC1 in nat mode' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic1 nat" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Adding NIC2 in hostonly mode' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic2 hostonly" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Attaching storage controller, drive and making it the boot drive' );
    # Storage controller with same name as the vm
    if( UBOS::Utils::myexec( "VBoxManage storagectl '$vmName' --name '$vmName' --add sata --bootable on" )) {
        fatal( 'VBoxManage storagectl failed' );
    }
    if( UBOS::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --port 1 --type hdd --medium " . $self->{vmdkFile} )) {
        fatal( 'VBoxManage storageattach failed' );
    }
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --boot1 disk --boot2 none --boot3 none --boot4 none" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Setting up host-only networking' );
    if( UBOS::Utils::myexec( "ip link show dev $hostonlyInterface", undef, \$out, \$err )) {
        # doesn't exist
        if( UBOS::Utils::myexec( "VBoxManage hostonlyif create" )) {
            error( 'VBoxManage hostonlyif create failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
            error( 'VBoxManage hostonlyif ipconfig failed' );
        }
    }
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --hostonlyadapter2 $hostonlyInterface" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    if( $vncSecret ) {
        if( UBOS::Utils::myexec( "VBoxManage setproperty vrdeextpack VNC" )) {
            error( 'VBoxManage setproperty vrdeextpack failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrde on" )) { 
            error( 'VBoxManage modifyvm (enabling vrde) failed. You may not be able to connect via VNC.' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeproperty 'VNCPassword=$vncSecret'" )) { 
            error( 'VBoxManage modifyvm (setting VNC password) failed. You may not be able to connect via VNC.' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeauthlibrary null" )) {
            error( 'VBoxManage modifyvm --vrdeauthlibrary failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeport 1501" )) {
            error( 'VBoxManage modifyvm --vrdeport failed' );
        } else {
            info( 'You can access the VM via VNC at port 1501' );
        }
    }

    debug( 'Creating cloud-init config disk' );
    $self->{configVmdkFile} = $options->{vmdkfile} . '-config.vmdk';
    $self->createConfigDisk( $self->{configVmdkFile} );

    if( UBOS::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --port 2 --type hdd --medium " . $self->{configVmdkFile} )) {
        fatal( 'VBoxManage storageattach failed' );
    }

    debug( 'Starting vm', $vmName );
    if( UBOS::Utils::myexec( "VBoxManage startvm '$vmName' --type headless", undef, \$out, \$err )) {
        # This starts the VM in the background (unlike VBoxHeadless)
        fatal( 'VBoxManage startvm failed' );
    }

    info( 'Waiting until target is ready' );
    if( $self->waitUntilTargetReady() ) {
        $self->{isOk} &= $self->handleImpersonateDepot( $options, '192.168.56.1' ); # FIXME

        $self->{isOk} &= $self->invokeOnTarget( "sudo ubos-admin update" );

    } else {
        error( 'Virtual machine failed to start up in time' );
    }

    return $self;
}

##
# Backup a site to a local file on the local machine.
# $site: $site JSON
# $filename: the local backup file name
# return: if successful, $filename
sub backupToLocal {
    my $self     = shift;
    my $site     = shift;
    my $filename = shift;

    my $remoteFile;
    my $exit = $self->invokeOnTarget( 'F=$(mktemp webapptest-XXXXX.ubos-backup); sudo ubos-admin backup --siteid ' . $site->{siteid} . ' --out $F; echo $F', undef, \$remoteFile );
    if( $exit ) {
        error( 'Remote backup failed' );
        return undef;
    }
    $remoteFile =~ s!^\s+!!;
    $remoteFile =~ s!\s+$!!;

    $exit = $self->copyFromTarget( $remoteFile, $filename );
    if( $exit ) {
        error( 'Copying backup from remote to local failed' );
        return undef;
    }
    $self->destroyBackup( $remoteFile );

    return $filename;
}    

##
# Restore a site from a local file on the local machine
# $site: $site JSON
# $filename: the local backup file name
# return: if successful, $filename
sub restoreFromLocal {
    my $self     = shift;
    my $site     = shift;
    my $filename = shift;

    my $siteIdInBackup;
    my $exit = UBOS::Utils::myexec( 'sudo ubos-admin listsites --brief --backupfile ' . $filename, undef, \$siteIdInBackup );
    if( $exit ) {
        error( 'Cannot listsites in backup file, exit', $exit );
        return 0;
    }
    $siteIdInBackup =~ s!^\s+!!g;
    $siteIdInBackup =~ s!\s+$!!g;
    
    my $remoteFile;
    $exit = $self->invokeOnTarget( 'mktemp webapptest-XXXXX.ubos-backup', undef, \$remoteFile );
    if( $exit ) {
        error( 'Failed to create remote temp file' );
        return 0;
    }
    $remoteFile =~ s!^\s+!!;
    $remoteFile =~ s!\s+$!!;

    $exit = $self->copyToTarget( $filename, $remoteFile );
    if( $exit ) {
        error( 'Failed to copy backup from local to remote ' );
        return 0;
    }

    $exit = $self->invokeOnTarget(
            'sudo ubos-admin restore'
            . ' --siteid '     . $siteIdInBackup
            . ' --hostname '   . $site->{hostname}
            . ' --newsiteid '  . $site->{siteid}
            . ' --in '         . $filename );

    if( !$exit ) {
        return 1;
    } else {
        error( 'Restore failed, exit', $exit );
        return 0;
    }
}

##
# Teardown this Scaffold.
sub teardown {
    my $self = shift;

    info( 'Tearing down Scaffold VBox' );

    my $vmName = $self->{vmName};
    
    debug( 'Shutting down vm, unregistering, and deleting image file' );
    if( UBOS::Utils::myexec( "VBoxManage controlvm '$vmName' acpipowerbutton" )) {
        error( 'VBoxManage controlvm failed' );
    }

    my $out;
    my $err;
    for( my $count = 0 ; $count < $shutdownMaxSeconds ; ++$count ) {
        if( UBOS::Utils::myexec( "VBoxManage showvminfo '$vmName' --machinereadable", undef, \$out )) {
            error( 'VBoxManage showvminfo failed' );
        }
        if( $out =~ m!VMState="poweroff"! ) {
            debug( 'VM state is poweroff' );
            last;
        }
        sleep 1;
    }

    if( UBOS::Utils::myexec( "VBoxManage unregistervm '$vmName' --delete", undef, \$out, \$err )) {
        error( 'VBoxManage unregistervm failed', $err );
    }
    if( -e $self->{vmdkFile} ) {
        UBOS::Utils::deleteFile( $self->{vmdkFile} );
    }
    if( -e $self->{configVmdkFile} ) {
        UBOS::Utils::deleteFile( $self->{configVmdkFile} );
    }

    return 1;
}

##
# Helper method to invoke a command on the target. This must be overridden by subclasses.
# $cmd: command
# $stdin: content to pipe into stdin
# $stdout: content captured from stdout
# $stderr: content captured from stderr
sub invokeOnTarget {
    my $self   = shift;
    my $cmd    = shift;
    my $stdin  = shift;
    my $stdout = shift;
    my $stderr = shift;

    my $ip = $self->getTargetIp();
    
    my $sshCmd = 'ssh';
    $sshCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error';
            # don't put into known_hosts file, and don't print resulting warnings
    $sshCmd .= ' ubos-admin@' . $ip;
    $sshCmd .= ' -i ' . $self->{ubosAdminPrivateKeyFile};
    $sshCmd .= " '$cmd'";
    debug( 'ssh command:', $sshCmd );

    return UBOS::Utils::myexec( $sshCmd, $stdin, $stdout, $stderr );
}

##
# Obtain the IP address of the target.  This must be overridden by subclasses.
# return: target IP
sub getTargetIp {
    my $self  = shift;

    return $self->{hostOnlyIp};
}

##
# Wait until target is ready.
sub waitUntilTargetReady {
    my $self = shift;

    # first we wait for an IP address, then we make sure pacman keys have been
    # initialized

    my $vmName = $self->{vmName};
    my $ret    = 0;
    for( my $count = 0 ; $count < $bootMaxSeconds ; $count += 5 ) {
        # This is on the hostonly interface
        my $out;
        if( UBOS::Utils::myexec( "VBoxManage guestproperty get '$vmName' /VirtualBox/GuestInfo/Net/1/V4/IP", undef, \$out )) {
            error( 'VBoxManage guestproperty failed' );
        }
        # $out is something like "Value: 192.168.56.103"
        if( $out =~ m!Value: (\d+\.\d+\.\d+\.\d+)! ) {
            $self->{hostOnlyIp} = $1;
            info( 'The virtual machine is accessible, from this host only, at', $self->{hostOnlyIp} );
            $ret = 1;
            last;
        }
        sleep 5;
    }
    unless( $ret ) {
        return $ret;
    }
    for( my $count = 0 ; $count < $keysMaxSeconds ; $count += 5  ) {
        my $out;
        $self->invokeOnTarget( 'ls -l /etc/pacman.d/gnupg/pubring.gpg', undef, \$out );
        # format: -rw-r--r-- 1 root root 450806 Aug 31 20:26 /etc/pacman.d/gnupg/pubring.gpg

        if( $out =~ m!^(?:\S{10})\s+(?:\S+)\s+(?:\S+)\s+(?:\S+)\s+(\d+)\s+! ) {
            my $size = $1;
            if( $size > 10000 ) {
                # rather arbitrary cutoff, but seems to do the job
                $ret = 1;
                return $ret;
            }
        }
        sleep 5;
    }
    debug( 'Pacman keys file not populated in time' );

    return $ret;
}

##
# Copy a remote file to the local machine
# $remoteFile: the name of the file on the remote machine
# $localFile: the name of the file on the local machine
sub copyFromTarget {
    my $self       = shift;
    my $remoteFile = shift;
    my $localFile  = shift;

    my $ip = $self->getTargetIp();
    
    my $scpCmd = 'scp -q';
    $scpCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error';
            # don't put into known_hosts file, and don't print resulting warnings
    $scpCmd .= ' -i ' . $self->{ubosAdminPrivateKeyFile};
    $scpCmd .= ' ubos-admin@' . $ip . ':' . $remoteFile;
    $scpCmd .= ' ' . $localFile;
    debug( 'scp command:', $scpCmd );

    my $ret = UBOS::Utils::myexec( $scpCmd );
    return $ret;
}

##
# Obtain information about a file on the target. This must be overridden by
# subclasses.
# $fileName: full path name of the file on the target
# $makeContentAvailable: if true, also make the content available locally
# return( $uname, $gname, $mode, $localContent ): localContent is the name
#        if a locally available file with the same content, except that
#        if the file turns out to be a symlink, it is the target of the symlink
sub getFileInfo {
    my $self                 = shift;
    my $fileName             = shift;
    my $makeContentAvailable = shift;

    # Perl inside Perl -- escaping is a bit tricky
    my $script = <<SCRIPT;
use strict;
use warnings;

if( -e '$fileName' ) {
    my \@found = lstat( '$fileName' );
    \$found[4] = getpwuid( \$found[4] );
    \$found[5] = getgrgid( \$found[5] );
    print( join( ',', \@found ) . "\\n" );
    if( -l '$fileName' ) {
        print readlink( '$fileName' ) . "\\n";
    }
} else {
    print( "---\n" );
}
exit 0;
1;
SCRIPT

    my $out;
    my $err;
    if( $self->invokeOnTarget( 'perl', $script, \$out, \$err )) {
        error( 'Failed to invoke remote perl command', $err );
        return 0;
    }

    my @lines = split /\n/, $out;

    if( $lines[0] eq '---' ) {
        return undef;
    }
    my( $dev, $ino, $mode, $nlink, $uname, $gname, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = split( /,/, $lines[0] );

    if( $makeContentAvailable ) {
        if( Fcntl::S_ISLNK( $mode )) {
            my $target = $lines[1];
            return( $uname, $gname, $mode, $target );

        } else {
            my $localFile = tmpnam();
            $self->copyFromTarget( $fileName, $localFile );
            chmod 0600, $localFile; # scp keeps permissions

            return( $uname, $gname, $mode, $localFile );
        }

    } else {
        return( $uname, $gname, $mode );
    }
}

##
# Create a cloud-init config disk in VMDK format
# $vmdkImage: name of the vmdk image file to be created
sub createConfigDisk {
    my $self       = shift;
    my $configFile = shift;

    my $image = "$configFile.img";
    my $mount = "$configFile.mount";

    my $out;
    my $err;
    if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=2M", undef, \$out, \$err )) {
        fatal( 'dd failed', $err );
    }
    if( UBOS::Utils::myexec( "mkfs.vfat -n cidata $image", undef, \$out, \$err )) {
        fatal( 'mkfs.vfat failed', $err );
    }
    UBOS::Utils::mkdir( $mount );
    if( UBOS::Utils::myexec( "sudo mount '$image' '$mount'", undef, \$out, \$err )) {
        fatal( 'mount failed', $err );
    }

    my $vmName    = $self->{vmName};
    my $sshPubKey = UBOS::Utils::slurpFile( $self->{ubosAdminPublicKeyFile} );
    $sshPubKey =~ s!^\s+!!;
    $sshPubKey =~ s!\s+$!!;

    UBOS::Utils::saveFile( "$mount/user-data", <<USERDATA, 0640, 'root', 'root' );
#cloud-config
users:
 - name: ubos-admin
   gecos: UBOS administrative user
   ssh-authorized-keys:
    - $sshPubKey
   sudo: "ALL=(ALL) NOPASSWD: /usr/bin/ubos-admin *, /usr/bin/bash *"
USERDATA

    UBOS::Utils::saveFile( "$mount/meta-data", <<METADATA, 0640, 'root', 'root' );
instance-id: $vmName
METADATA

    if( UBOS::Utils::myexec( "sudo umount '$mount'", undef, \$out, \$err )) {
        fatal( 'umount failed', $err );
    }
    if( UBOS::Utils::myexec( "VBoxManage convertfromraw '$image' '$configFile' --format VMDK", undef, \$out, \$err )) {
        fatal( 'VBoxManage convertfromraw failed', $err );
    }
    UBOS::Utils::deleteFile( $image );
    UBOS::Utils::deleteRecursively( $mount );
}

##
# Return help text.
# return: help text
sub help {
    return <<TXT;
A scaffold that runs tests on the local machine in a VirtualBox virtual machine.
Options:
    vmdktemplate                (required) -- template for the VMDK file
    vmdkfile                    (optional) -- local copy of the VMDK file on which tests is performed
    ubos-admin-public-key-file  (required) -- name of the file that contains the public key for ubos-admin ssh access
    ubos-admin-private-key-file (required) -- name of the file that contains the private key for  ubos-adminssh access
    ram                         (optional) -- RAM in MB
    vncsecret                   (optional) -- if given, the virtual machine will be accessible over VNC with this password
TXT
}
                    
1;
