//
// Copyright (C) 1998 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.webapptest.record;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.net.Socket;
import java.net.SocketException;

/**
 *
 */
public class HttpResponseHandler
    implements
        Runnable
{
    /**
     * Constructor.
     * 
     * @param clientSideSocket the socket from which responses are read
     * @param serverSideSocket the socket to which responses are written
     */
    public HttpResponseHandler(
            Socket clientSideSocket,
            Socket serverSideSocket )
    {
        theClientSideSocket = clientSideSocket;
        theServerSideSocket = serverSideSocket;
    }
    
    @Override
    public void run()
    {
        BufferedInputStream  clientInStream  = null;
        BufferedOutputStream serverOutStream = null;
        
        byte [] buf = new byte[4096];
        try {
            clientInStream  = new BufferedInputStream( theClientSideSocket.getInputStream() );
            serverOutStream = new BufferedOutputStream( theServerSideSocket.getOutputStream() );

            int read;
            while( ( read = clientInStream.read( buf )) > 0 ) {
                serverOutStream.write( buf, 0, read );
                serverOutStream.flush();
            }
        
        } catch( SocketException ex ) {
            // cleanup time
            
        } catch( Throwable ex ) {
            ex.printStackTrace();

        } finally {

            try {
                if( serverOutStream != null ) {
                    serverOutStream.flush();
                }
            } catch( Exception ex ) {
                ex.printStackTrace();
            }
        }
    }

    /**
     * The Socket from which responses are read.
     */
    protected Socket theClientSideSocket;
    
    /**
     * The Socket to which responses are written.
     */
    protected Socket theServerSideSocket;
}
