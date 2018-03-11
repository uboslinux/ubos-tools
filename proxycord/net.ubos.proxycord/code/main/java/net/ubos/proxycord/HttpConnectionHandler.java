//
// Copyright (C) 1998 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.net.SocketTimeoutException;

/**
 *
 */
public class HttpConnectionHandler
    implements
        Runnable
{
    /**
     * Constructor.
     * 
     * @param localHost local IP address to bind to
     * @param localPort local port to open
     * @param remoteHost remote host to connect to
     * @param remotePort remote port to connect to
     * @throws IOException
     */
    protected HttpConnectionHandler(
            String localHost,
            int    localPort,
            String remoteHost,
            int    remotePort )
        throws
            IOException
    {
        theLocalHost  = localHost;
        theLocalPort  = localPort;
        theRemoteHost = remoteHost;
        theRemotePort = remotePort;

        theServerSocket = new ServerSocket();
        theServerSocket.setReuseAddress( true );

        if( theLocalHost != null ) {
            theServerSocket.bind( new InetSocketAddress( InetAddress.getByName( theLocalHost ), theLocalPort ));
        } else {
            theServerSocket.bind( new InetSocketAddress( theLocalPort ));
        }
    }
    
    @Override
    public void run()
    {
        while( theIsActive ) {
            Socket serverSideSocket = null;
            try {
                serverSideSocket = theServerSocket.accept();

                if( theIsActive ) {
                    HttpRequestHandler requestHandler = new HttpRequestHandler( serverSideSocket, theRemoteHost, theRemotePort );
                    Main.theWorkerThreads.submit( requestHandler );
                }

            } catch( SocketTimeoutException ex ) {
                // that's fine, do nothing, go right back
                break;
            } catch( SocketException ex ) {
                // probably too much load, wait a tiny bit
                break;
            } catch( IOException ex ) {
                ex.printStackTrace();
                break;
            }
            
        }

        try {
            theServerSocket.close();
        } catch( IOException ex ) {
            ex.printStackTrace();
        }
        theServerSocket = null;
    }

    /**
     * Finish processing.
     */
    public void setInactive()
    {
        theIsActive = false;
        if( theServerSocket != null ) {
            try {
                theServerSocket.close();
            } catch( IOException ex ) {
                ex.printStackTrace();
            }
        }
    }

    /**
     * Continue processing while this flag is true.
     */
    protected boolean theIsActive = true;

    /**
     * The locally opened ServerSocket
     */
    protected ServerSocket theServerSocket;

    /**
     * Local IP address to bind to.
     */
    protected String theLocalHost;

    /**
     * Local port to open.
     */
    protected int theLocalPort;

    /**
     * Remote host to connect to
     */
    protected String theRemoteHost;

    /**
     * Remote port to connect to
     */
    protected int theRemotePort;
}
