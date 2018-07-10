#!/usr/bin/perl
#
# A scaffold for app packages that need to start a compiled background daemon on UBOS.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::CompiledDaemonApp;

use base qw( UBOS::Scaffold::AbstractScaffold );

use UBOS::Scaffold::ScaffoldUtils;

####
sub generate {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    $self->SUPER::generate( $pars, $dir );
    
    my $name = $pars->{name};

    my $systemdService = $self->systemdServiceContent( $pars, $dir );
    if( $systemdService ) {
        unless( -d "$dir/systemd" ) {
            UBOS::Utils::mkdir( "$dir/systemd" );
        }
        UBOS::Utils::saveFile( "$dir/tmpl/$name\@.service", $systemdService, 0644 );
    }
}

####
sub pkgbuildContentPackage {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $ret = $self->pkgbuildContentPackage( $pars, $dir );
    $ret .= <<END;
# Systemd
install -D -m0644 \${startdir}/systemd/*.service \${pkgdir}/usr/lib/systemd/system/
END
    return $ret;
}

####
sub manifestContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name = $pars->{name};

    return <<END;
{
    "type" : "app",

    "roles" : {
        "apache2" : {
            "defaultcontext" : "/$name",
            "apache2modules" : [
                "proxy",
                "proxy_http",
                "headers",
                "proxy_wstunnel",
                "rewrite"
            ],
            "appconfigitems" : [
                {
                    "type"            : "tcpport",
                    "name"            : "mainport"
                },
                {
                    "type"            : "directory",
                    "name"            : "\${appconfig.datadir}"
                },
                {
                    "type"            : "directory",
                    "name"            : "\${appconfig.datadir}/data",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "datadir",
                    "dirpermissions"  : "0750",
                    "filepermissions" : "0640",
                    "uname"           : "\${apache2.uname}",
                    "gname"           : "\${apache2.gname}"
                },
                {
                    "type"            : "file",
                    "name"            : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"        : "tmpl/htaccess.tmpl",
                    "templatelang"    : "varsubst"
                },
                {
                    "type"            : "file",
                    "name"            : "/etc/$name/\${appconfig.appconfigid}.json",
                    "template"        : "tmpl/config.json.tmpl",
                    "templatelang"    : "varsubst"
                },
                {
                    "type"            : "systemd-service",
                    "name"            : "$name\@\${appconfig.appconfigid}",
                },
            ]
        },
        "mysql" : {
            "appconfigitems" : [
                {
                    "type"            : "database",
                    "name"            : "maindb",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "maindb",
                    "privileges"      : "all privileges"
                }
            ]
        }
    }
}
END
}

####
sub htAccessTmplContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    return <<END;
ProxyPass /robots.txt !
ProxyPass /favicon.ico !
ProxyPass /sitemap.xml !
ProxyPass /.well-known !
ProxyPass /_common !
ProxyPass /_errors !

ProxyPass \${appconfig.contextorslash} http://127.0.0.1:\${appconfig.tcpport.mainport}\${appconfig.contextorslash}
ProxyPassReverse \${appconfig.contextorslash} http://127.0.0.1:\${appconfig.tcpport.mainport}\${appconfig.contextorslash}
ProxyPassReverseCookieDomain 127.0.0.1 \${site.hostname}

ProxyPreserveHost On

RequestHeader set X-Forwarded-Proto "\${site.protocol}"
RequestHeader set X-Frame-Options SAMEORIGIN

END
}

####
sub systemdServiceContent {
    my $self = shift;
    my $pars = shift;
    my $dir  = shift;

    my $name        = $pars->{name};
    my $description = $pars->{description};

    return <<END;
\[Unit]
Description=$description

[Service]
WorkingDirectory=/ubos/share/$name
ExecStart=/usr/share/$name/bin/${name}d --config=/etc/$name/%I.json
Restart=always

[Install]
WantedBy=multi-user.target
END
}

####
# Return help text.
# return: help text
sub help {
    return 'a compiled daemon is run that speaks HTTP at a non-standard port';
}

1;
