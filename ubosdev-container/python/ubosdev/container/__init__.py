#!/usr/bin/python
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import argparse
import atexit
import os
import os.path
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import traceback
import ubos.logging
import ubos.utils
import ubosdev.container.utils
import sys


def run() :
    """
    main program
    """
    cmds = ubosdev.container.utils.findCommands()

    parser = argparse.ArgumentParser( description='Run commands on UBOS development containers.')
    parser.add_argument('-v', '--verbose', action='count',       default=0,  help='Display extra output. May be repeated for even more output.')
    parser.add_argument('--logConfig',                                       help='Use an alternate log configuration file for this command.')
    parser.add_argument('--debug',         action='store_const', const=True, help='Suspend execution at certain points for debugging' )
    cmdParsers = parser.add_subparsers( dest='command', required=True )

    for cmdName, cmd in cmds.items():
        cmd.addSubParser( cmdParsers, cmdName )

    args,remaining = parser.parse_known_args(sys.argv[1:])
    cmdName = args.command

    ubos.logging.initialize('ubosdev-container', cmdName, args.verbose, args.logConfig, args.debug)

    if len(remaining)>0 :
        parser.print_help()
        exit(0)

    if cmdName in cmds:
        try :
            ret = cmds[cmdName].run(args)
            exit( ret )

        except Exception as e:
            if args.verbose > 1:
                traceback.print_exc( e )
            ubos.logging.fatal( str(type(e)), '--', e )

    else:
        ubos.logging.fatal('Sub-command not found:', cmdName, '. Add --help for help.' )


def determineChannel( arg ) :
    if arg is None :
        arg = 'yellow'
    else :
        if not arg in [ 'dev', 'red', 'yellow', 'green' ] :
            ubos.logging.fatal( 'Invalid channel:', arg )
    return arg


def determineArch( arg ) :
    if arg is None:
        arg = arch = myexecStdout( 'uname -m' ).strip().decode( 'UTF-8' )
    return arg


def determineContainerDir( arg, containerName ) :
    if arg is None:
        arg = f"{os.environ['HOME']}/ubos-containers/ubosdev/{containerName}"
    return arg


def determineImagesDir( arg ) :
    if arg is None:
        arg = f"{os.environ['HOME']}/ubos-containers/images"
    return arg


def determineContainerName( arg, channel, isMesh ) :
    if arg is None:
        if isMesh :
            arg = f"ubos-mesh-{channel}"
        else :
            arg = f"ubos-linux-{channel}"
    return arg


def listContainers( args ) :
    """
    List the available containers
    """

    parentDir = args.dir
    if parentDir is None :
        parentDir = f"{os.environ['HOME']}/ubos-containers/ubosdev"

    osRelease = '/etc/os-release'
    for found in Path( parentDir ).glob( '*' + osRelease ) :
        dir = str( found )
        dir = dir[ len(parentDir)+1 : -len( osRelease ) ]
        print( dir )


def setupContainer( args ) :
    """
    Setup a container
    """

    isMesh          = args.flavor == 'mesh'
    channel         = determineChannel( args.channel )
    arch            = determineArch( args.arch )
    containerName   = determineContainerName( args.name, channel, isMesh )
    containerDir    = determineContainerDir( args.containerdirectory, containerName )
    imagesDir       = determineImagesDir( args.imagesdirectory )
    siteTemplateUrl = args.sitetemplate

    if siteTemplateUrl is None :
        if isMesh:
            siteTemplateUrl = '/usr/share/ubos-tools-arch/site-templates/ubos-mesh-default-site-development-debug.json'

    def cleanup() :
        print( '*** Shutting down container' )
        myexec( f"sudo machinectl poweroff {containerName} > /dev/null 2>&1" )

    atexit.register( cleanup )

    print( '*** Upgrading system' )
    myexec( 'sudo pacman -Syu' )

    print( '*** Ensuring all needed packages' )
    ensurePackage( 'gnu-free-fonts' )
    ensurePackage( 'ttf-liberation' )
    ensurePackage( 'firefox' )
    ensurePackage( 'snapper' )
    ensurePackage( 'geany' )
    ensurePackage( 'geany-plugins' )
    if isMesh :
        ensurePackage( 'jdk11-openjdk' ) # for now
        ensurePackage( 'netbeans' )

    print( '*** Running iptables' )
    for f in [ '/etc/iptables/iptables.rules', '/etc/iptables/ip6tables.rules' ] :
        if not os.path.exists( f ) :
            myexec( f"sudo cp /etc/iptables/empty.rules {f}" )
    myexec( 'sudo systemctl enable --now iptables ip6tables' )

    if os.path.exists( containerDir ) :
        print( f"*** Container director exists already, skipping right to software update: {containerDir}" )
        isFirst = False

    else :
        print( f"*** Setting up for release channel {channel} on arch {arch}" )

        imageName = f"ubos-develop_{channel}_{arch}-container_LATEST.tar.xz"

        print( '*** Ensuring we have a UBOS Linux container image' )
        ensureDirectory( imagesDir )

        if os.path.exists( f"{imagesDir}/{imageName}" ) :
            print( '*** Have image already, not downloading nor checking for updates' )
        else :
            myexec( f"curl -o {imagesDir}/{imageName} http://depot.ubos.net/{channel}/{arch}/images/{imageName}" )

        if ensureSubvol( containerDir ) :
            print( f"*** Unpacking image into {containerDir}" )
            myexec( f"sudo tar -C {containerDir} -x -J -f {imagesDir}/{imageName}" )

        if isMesh :
            print( 'Ensuring container has ubos-mesh packages' )
            temp = tempfile.NamedTemporaryFile( delete=False )
            temp.write( b"[mesh]\nServer = http://depot.ubos.net/$channel/$arch/mesh\n" )
            temp.close()
            myexec( f"sudo mv {temp.name} {containerDir}/etc/pacman.d/repositories.d/mesh" )

            print( 'Opening up default debug ports 7777 and 7778' )
            temp = tempfile.NamedTemporaryFile( delete=False )
            temp.write( b"7777/tcp\n7778/tcp\n" )
            temp.close()
            myexec( f"sudo mv {temp.name} {containerDir}/etc/ubos/open-ports.d/java-debugging" )

        isFirst = True

    print( '*** Starting container' )
    cmd = f"systemd-nspawn -n -b -D {containerDir} -M {containerName}"
    if siteTemplateUrl is not None and not siteTemplateUrl.startswith( 'http:' ) and not siteTemplateUrl.startswith( 'https:' ) :
        cmd += f" --bind {siteTemplateUrl}"
    myexec( f"sudo {cmd} > /dev/null 2>&1 &" ) # in the background

    # wait until the container is running
    while True :
        time.sleep( 5 )
        if 0 == myexec( f"sudo systemctl -M {containerName} is-system-running > /dev/null" ) :
            break

    print( '*** Updating container' )
    containerCmd = 'ubos-admin update -v --nokeyrefresh'
    if isFirst :
        containerCmd += ' && pacman -S --noconfirm ubos-mesh-devtools'
        containerCmd += ' && snapper create-config .'
        containerCmd += ' && snapper create -d after-first-update'
    myexec( f"sudo machinectl shell {containerName} /bin/bash -c '{containerCmd}'" )

    if isFirst and len( siteTemplateUrl ) > 0 :
        print( '*** Deploying site to container' )
        containerCmd = f"ubos-admin createsite --from-template {siteTemplateUrl} && snapper create -d after-first-site-deploy"
        myexec( f"sudo machinectl shell {containerName} /bin/bash -c '{containerCmd}'" )


def runContainer( args ) :
    """
    Run the container
    """
    arch            = determineArch( None )
    containerName   = args.name
    containerDir    = determineContainerDir( args.containerdirectory, containerName )
    siteTemplateUrl = args.sitetemplate

    if not os.path.exists( containerDir ) :
        fatal( 'Container not found:', containerDir )

    print( '*** Starting container' )
    cmd = f"systemd-nspawn -n -b -D {containerDir} -M {containerName}"
    cmd += f" --bind $HOME --bind /dev/fuse"
    if siteTemplateUrl is not None and not siteTemplateUrl.startswith( 'http:' ) and not siteTemplateUrl.startswith( 'https:' ) :
        cmd += f" --bind {siteTemplateUrl}"
    myexec( f"sudo {cmd}" )


def myexec( cmd ) :
    """
    Simple wrapper for sub-commands
    """

    ret = subprocess.run( cmd, shell=True )
    return ret.returncode


def myexecStdout( cmd ) :
    """
    Simple wrapper for sub-commands whose stdout we want to obtain
    """

    ret = subprocess.run( "LANG=en_US.UTF-8 " + cmd, shell=True, stdout=subprocess.PIPE )
    return ret.stdout


def ensurePackage( name ) :
    """
    Ensure that a package is installed
    """

    cmd = f"pacman -Q '{name}' 2> /dev/null || sudo pacman -S --noconfirm '{name}'"
    ret = myexec( cmd )
    return ret


def ensureDirectory( name ) :
    """
    Ensure this directory and its parents exist
    """
    os.makedirs( name, exist_ok=True )


def ensureSubvol( name ) :
    """
    Ensure this subvolume and its parents exist

    return: true if it was newly made
    """
    os.makedirs( Path( name ).parent, exist_ok=True )
    if not os.path.exists( name ) :
        myexec( f"sudo btrfs subvol create '{name}'" )
        return True
    else :
        return False
