//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.beust.jcommander.Parameter;
import java.util.ArrayList;
import java.util.List;

/**
 * Command-line arguments
 */
public class Args
{
    @Parameter
    List<String> parameters = new ArrayList<>();

    @Parameter( names = { "-lh", "--local-host" }, description = "Name of the local interface to bind to." )
    String localHost = "0.0.0.0";

    @Parameter( names = { "-lp", "--local-port" }, description = "Local port to open." )
    int localPort = 8080;

    @Parameter( names = { "-rh", "--remote-host" }, description = "Remote host to connect to." )
    String remoteHost;

    @Parameter( names = { "-rp", "--remote-port" }, description = "Remote port to bind to." )
    int remotePort = 80;
    
    @Parameter( names = { "-o", "--out" }, description = "JSON file to write with the recording" )
    String out;
    
    @Parameter( names = { "-h", "--help" }, description = "Help text", help = true )
    boolean help;
}
