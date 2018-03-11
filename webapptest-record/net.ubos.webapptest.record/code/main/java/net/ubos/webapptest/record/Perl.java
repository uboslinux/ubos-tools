package net.ubos.webapptest.record;

//#!/usr/bin/perl
//#
//# Run a proxy in front of a website. Record traffic and save it suitably
//# for webapptest to run as test cases.
//#
//# Copyright (C) 2018 and later, Indie Computing Corp. All rights reserved. License: see package.
//#
//
//use strict;
//use warnings;
//
//use File::Temp qw(:POSIX);
//use Getopt::Long;
//use IO::Select;
//use IO::Socket::INET;
//use POSIX qw(strftime);
//use Time::HiRes qw(time);
//use UBOS::Logging;
//use UBOS::Utils;
//
//my $verbose           = 0;
//my $logConfigFile     = undef;
//my $debug             = undef;
//my $localHost         = '0.0.0.0';
//my $localPort         = 80;
//my $remotePort        = undef;
//my $remoteHost        = undef;
//my $out               = undef;
//my $help              = 0;
//
//my $parseOk = GetOptions(
//    'verbose+'        => \$verbose,
//    'logConfig=s'     => \$logConfigFile,
//    'debug'           => \$debug,
//    'local-host=s'    => \$localHost,
//    'local-port=s'    => \$localPort,
//    'remote-host=s'   => \$remoteHost,
//    'remote-port=s'   => \$remotePort,
//    'out=s'           => \$out,
//    'help'            => \$help );
//
//if( $help ) {
//    synopsisHelpQuit( 1 );
//}
//if(    !$parseOk
//    || !$remoteHost )
//{
//    synopsisHelpQuit();
//}
//
//unless( $remotePort ) {
//    $remotePort = $localPort;
//}
//
//UBOS::Logging::initialize( 'webapptest-record', undef, $verbose, $logConfigFile, $debug );
//
//info( 'Listening on', "$localHost:$localPort => $remoteHost:$remotePort" );
//info( 'Type "QUIT" to quit.' );
//info( 'Type "TRANSITION name" to record actions that change the state of the app.' );
//info( 'Type "STATE name" to record actions that check the state of the app.' );
//info( 'Now record actions for "STATE virgin", and then alternate between TRANSITION and STATE until QUIT.' );
//
//my $localSocket = IO::Socket::INET->new(
//        LocalAddr => $localHost,
//        LocalPort => $localPort,
//        ReuseAddr => 1,
//        Listen    => 10 );
//
//unless( $localSocket ) {
//    fatal( "Unable to listen on $localHost:$localPort: $!" );
//}
//
//my $ioset = IO::Select->new;
//$ioset->add( \*STDIN );
//$ioset->add( $localSocket );
//
//# Only support a single connection
//my $clientSocket;
//my $serverSocket;
//
//my $currentRequestData;
//my $currentResponseData;
//
//my @requests  = ();
//my @responses = ();
//my @labels    = (
//    {
//        'when' => now(),
//        'type' => 'state',
//        'name' => 'virgin'
//    }
//);
//
//my $done = 0;
//while( !$done ) {
//    for my $socket( $ioset->can_read ) {
//        my $buffer;
//        my $read;
//
//        if( $socket == \*STDIN ) {
//            $read = $socket->sysread( $buffer, 4096 );
//            $buffer =~ s!^\s+!!;
//            $buffer =~ s!\s+$!!;
//
//            if( $buffer =~ m!^QUIT$!i ) {
//                $done = 1;
//                last;
//
//            } elsif( $buffer =~ m!^STATE\s+(.*)$!i ) {
//                my $label = {
//                    'when' => now(),
//                    'type' => 'state',
//                    'name' => $1
//                };
//                push @labels, $label;
//
//            } elsif( $buffer =~ m!^TRANSITION\s+(.*)$!i ) {
//                my $label = {
//                    'when' => now(),
//                    'type' => 'transition',
//                    'name' => $1
//                };
//                push @labels, $label;
//
//            } else {
//                warning( 'Cannot parse, ignoring:', $buffer );
//            }
//
//        } elsif( $socket == $localSocket ) {
//            unless( $serverSocket ) {
//                # accept the connection, but one connection only at a time
//                # accept the connection
//                $serverSocket = $localSocket->accept;
//                $clientSocket = IO::Socket::INET->new(
//                        PeerAddr => $remoteHost,
//                        PeerPort => $remotePort );
//                unless( $clientSocket ) {
//                    fatal( "Unable to connect to $remoteHost:$remotePort: $!" );
//                }
//                $ioset->add( $clientSocket );
//                $ioset->add( $serverSocket );
//            }
//
//        } else {
//            if( $socket == $serverSocket ) {
//                $read = $serverSocket->sysread( $buffer, 4096 );
//                if( $read ) {
//                    logRequestData( $buffer );
//                    $clientSocket->syswrite( $buffer );
//                }
//            } else {
//                $read = $clientSocket->sysread( $buffer, 4096 );
//                if( $read ) {
//                    logResponseData( $buffer );
//                    $serverSocket->syswrite( $buffer );
//                }
//            }
//            unless( $read ) {
//                $ioset->remove( $clientSocket );
//                $ioset->remove( $serverSocket );
//                $clientSocket->close;
//                $serverSocket->close;
//                $clientSocket = undef;
//                $serverSocket = undef;
//            }
//        }
//    }
//}
//
//my $max = @requests;
//if( @requests < @responses ) {
//    warning( 'Fewer requests logged than responses:', scalar( @requests ), 'vs', scalar( @responses ));
//} elsif( @requests < @responses ) {
//    warning( 'more requests logged than responses:', scalar( @requests ), 'vs', scalar( @responses ));
//    $max = @responses;
//}
//
//my $json = {};
//$json->{steps} = [];
//my $labelIndex = 0;
//for( my $i=0 ; $i<$max ; ++$i ) {
//    # interleave labels with requests into a chronological sequence
//    while( $labelIndex < @labels ) {
//        my $labelWhen = $labels[$labelIndex]->{when};
//        if( $labelWhen lt $requests[$i]->{when} ) {
//            push @{$json->{steps}}, $labels[$labelIndex];
//            ++$labelIndex;
//        } else {
//            last;
//        }
//    }
//    push @{$json->{steps}}, {
//        'type'     => 'request-response',
//        'request'  => $requests[$i],
//        'response' => $responses[$i],
//    };
//}
//while( $labelIndex < @labels ) {
//    push @{$json->{steps}}, $labels[$labelIndex];
//    ++$labelIndex;
//}
//
//if( $out ) {
//    UBOS::Utils::writeJsonToFile( $out, $json );
//} else {
//    UBOS::Utils::writeJsonToStdout( $json );
//}
//
//END {
//    if( $clientSocket ) {
//        $ioset->remove( $clientSocket );
//        $clientSocket->close;
//    }
//    if( $clientSocket ) {
//        $ioset->remove( $serverSocket );
//        $serverSocket->close;
//    }
//}
//
//#####
//# Some request data has been received
//# $data: the data
//sub logRequestData {
//    my $data = shift;
//
//    $currentRequestData .= $data;
//    parseRequestData();
//}
//
//#####
//# Some response data has been received
//# $data: the data
//sub logResponseData {
//    my $data = shift;
//
//    $currentResponseData .= $data;
//    parseResponseData();
//}
//
//
//#####
//# Data has been added to the request data buffer. Let's try to find
//# a full request.
//sub parseRequestData {
//    while( 1 ) {
//        if( $currentRequestData !~ m!(.*?)\r\n\r\n! ) {
//            # don't have a full set of headers yet
//            return;
//        }
//        unless( $currentRequestData =~ m!^([A-Z]+) ([^\s]+) HTTP/([\d\.]+)\r\n(.*?)\r\n\r\n(.*)$!s ) {
//            fatal( 'Not a valid HTTP request:', $currentRequestData );
//        }
//        my $request = {};
//        $request->{verb}    = $1;
//        $request->{path}    = $2;
//        $request->{version} = $3;
//        map { my( $key, $value ) = split( /: /, $_, 2 ); $request->{headers}->{$key} = $value } split( /\r\n/, $4 );
//        my $remainder       = $5;
//
//        $request->{when} = now();
//
//        if( exists( $request->{headers}->{'Content-Length'} )) {
//            my $contentLength = $request->{headers}->{'Content-Length'};
//            if( length( $remainder ) >= $contentLength ) {
//                $request->{content} = substr( $remainder, 0, $contentLength );
//                push @requests, $request;
//                $currentRequestData = substr( $remainder, $contentLength );
//            }
//
//        } elsif(     exists( $request->{headers}->{'Transfer-Encoding'} )
//                 && 'chunked' eq $request->{headers}->{'Transfer-Encoding'} ) {
//            $remainder =~ m!([0-9a-zA-Z]+)\r\n(.*)$!s;
//            my $contentLength = hex( $1 );
//            $remainder        = $2;
//                
//            if( length( $remainder ) >= $contentLength + 2 ) { # \r\n at the end
//                $request->{content} = substr( $remainder, 0, $contentLength );
//                push @requests, $request;
//                $currentRequestData = substr( $remainder, $contentLength+2 );
//            }
//                     
//        } else {
//            push @requests, $request;
//            $currentRequestData = $remainder;
//        }
//    }
//}
//
//#####
//# Data has been added to the response data buffer. Let's try to find
//# a full response.
//sub parseResponseData {
//print "parseResponseData\n";
//    while( 1 ) {
//        if( $currentResponseData !~ m!(.*?)\r\n\r\n! ) {
//            # don't have a full set of headers yet
//            return;
//        }
//        unless( $currentResponseData =~ m!^HTTP/([\d\.]+) (\d+) (.*?)\r\n(.*?)\r\n\r\n(.*)$!s ) {
//            fatal( 'Not a valid HTTP response:', $currentResponseData );
//        }
//        my $response = {};
//        $response->{version}    = $1;
//        $response->{status}     = $2;
//        $response->{statusText} = $3;
//        map { my( $key, $value ) = split( /: /, $_, 2 ); $response->{headers}->{$key} = $value } split( /\r\n/, $4 );
//        my $remainder           = $5;
//
//        $response->{when} = now();
//
//        if( exists( $response->{headers}->{'Content-Length'} )) {            
//            my $contentLength = $response->{headers}->{'Content-Length'};
//            if( length( $remainder ) >= $contentLength ) {
//                $response->{content} = substr( $remainder, 0, $contentLength );
//                push @responses, $response;
//                $currentResponseData = substr( $remainder, $contentLength );
//            }
//
//        } elsif(     exists( $response->{headers}->{'Transfer-Encoding'} )
//                 && 'chunked' eq $response->{headers}->{'Transfer-Encoding'} ) {
//
//            my $content;
//            while( 1 ) {
//print "Remainder $remainder\n";
//                unless( $remainder =~ m!([0-9a-zA-Z]+)\r\n(.*)$!s ) {
//                    # don't have enough data -- discard
//                    $content = undef;
//print "Break 1\n";
//                    return;
//                }
//
//                my $contentLength = hex( $1 );
//                $remainder        = $2;
//
//print "Looking at contentLength=$contentLength vs " . length( $remainder ) . "\n";
//                if( $contentLength == 0 ) {
//                    last;
//                }
//                if( length( $remainder ) >= $contentLength + 2 ) { # \r\n at the end
//
//                    $content   = substr( $remainder, 0, $contentLength );
//                    $remainder = substr( $remainder, $contentLength+2 );
//
//                } else {
//                    # don't have enough data -- discard
//                    $content = undef;
//print "Break 2\n";
//                    return;
//                }
//            }
//            if( $content ) {
//                $response->{content} = $content;
//                push @responses, $response;
//                $currentResponseData = $remainder;
//            }
//                
//        } else {
//            push @responses, $response;
//            $currentResponseData = $remainder;
//        }
//    }
//}
//
//#####
//# Construct a time stamp
//sub now {
//    my $now = time;
//    return strftime( "%Y/%m/%d-%H:%M:%S", gmtime( $now )) . sprintf( ".%03d", ( $now * 1000 ) % 1000 );
//}
//
//#####
//sub synopsisHelpQuit {
//    my $long = shift || 0;
//
//    if( $long ) {
//        print <<END;
//Synopsis:
//    webapptest-record --remote-host <host>
//        Proxy port 80 locally to remote host <host>, and print recording to stdout upon quit.
//
//    webapptest-record --help
//        This help text.
//
//Optional flags:
//    --local-host <ip>
//        Bind to local IP address <ip>
//    --local-port <port>
//        Proxy local port <port> instead of port 80
//    --remote-port <port>
//        Proxy to remote port <port> instead of to port 80
//    --out <file>
//        Save recording to file <file> instead of stdout
//    --verbose
//        More output
//    --logConfig <file>
//        Use the specified logging config file
//    --debug
//        Enter debug mode
//END
//    } else {
//        print <<END;
//webapptest-record --remote-host <host> [--out <file>][--remote-port <port>][--local-host <ip>][--local-port <port>][--verbose]
//END
//    }
//    exit 0;
//}
