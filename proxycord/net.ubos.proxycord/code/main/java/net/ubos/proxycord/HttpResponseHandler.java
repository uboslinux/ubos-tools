//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.net.SocketException;

/**
 * Handles the response side of a connection.
 */
public class HttpResponseHandler
    implements
        Runnable
{
    /**
     * Constructor.
     * 
     * @param requestHandler the HttpRequestHandler to which this HttpResponseHandler belongs
     */
    public HttpResponseHandler(
            HttpRequestHandler requestHandler )
    {
        theRequestHandler = requestHandler;
    }
    
    @Override
    public void run()
    {
        BufferedInputStream  clientInStream  = null;
        BufferedOutputStream serverOutStream = null;
        
        byte [] buf = new byte[4096];
        try {
            clientInStream  = new BufferedInputStream(  theRequestHandler.getClientSideSocket().getInputStream() );
            serverOutStream = new BufferedOutputStream( theRequestHandler.getServerSideSocket().getOutputStream() );

            int read;
            while( ( read = clientInStream.read( buf )) > 0 ) {
                serverOutStream.write( buf, 0, read );
                serverOutStream.flush();

                theRequestHandler.logResponseData( buf, read );
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
     * The HttpRequestHandler to which this HttpResponseHandler belongs.
     */
    protected HttpRequestHandler theRequestHandler;
}
