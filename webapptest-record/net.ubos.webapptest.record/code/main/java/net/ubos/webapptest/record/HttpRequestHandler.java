//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.webapptest.record;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.net.Socket;

/**
 * Handles one or more HTTP Exchanges on a given socket connection.
 */
public class HttpRequestHandler
    implements
        Runnable
{
    /**
     * Constructor.
     * 
     * @param serverSideSocket the server-side socket
     * @param remoteHost host to connect to
     * @param remotePort port to connect to
     */
    public HttpRequestHandler(
            Socket serverSideSocket,
            String remoteHost,
            int    remotePort )
    {
        theServerSideSocket = serverSideSocket;
        theRemoteHost       = remoteHost;
        theRemotePort       = remotePort;
    }
    
    @Override
    public void run()
    {
        try {
            theClientSideSocket = new Socket( theRemoteHost, theRemotePort );
        } catch( Throwable t ) {
            t.printStackTrace();
            return;
        }

        Main.theWorkerThreads.submit( new HttpResponseHandler( theClientSideSocket, theServerSideSocket ));

        BufferedInputStream  serverInStream  = null;
        BufferedOutputStream clientOutStream = null;
        
        byte [] buf = new byte[4096];
        try {
            serverInStream  = new BufferedInputStream( theServerSideSocket.getInputStream() );
            clientOutStream = new BufferedOutputStream( theClientSideSocket.getOutputStream() );

            int read;
            while( ( read = serverInStream.read( buf )) > 0 ) {
                clientOutStream.write( buf, 0, read );
                clientOutStream.flush();
            }
            
            
        } catch( Throwable ex ) {
            ex.printStackTrace();

        } finally {

            try {
                if( clientOutStream != null ) {
                    clientOutStream.flush();
                }
            } catch( Exception ex ) {
                ex.printStackTrace();
            }

            try {
                if( theClientSideSocket != null && ! theClientSideSocket.isClosed() ) {
                    theClientSideSocket.close();
                }
            } catch( Exception ex ) {
                ex.printStackTrace();
            }
            try {
                if( theServerSideSocket != null && ! theServerSideSocket.isClosed() ) {
                    theServerSideSocket.close();
                }
            } catch( Exception ex ) {
                ex.printStackTrace();
            }
        }
    }

    /**
     * Obtain the outgoing, client-side socket.
     * 
     * @return the Socket
     */
    public Socket getClientSideSocket()
    {
        return theClientSideSocket;
    }
    /**
     * The server-side socket that was spawned due to an incoming request.
     */
    protected Socket theServerSideSocket;
    
    /**
     * The client-side socket that connects to the remote website we are proxying
     */
    protected Socket theClientSideSocket;

    /**
     * The remote host to connect to
     */
    protected String theRemoteHost;
    
    /**
     * The remote port to connect to
     */
    protected int theRemotePort;
}
