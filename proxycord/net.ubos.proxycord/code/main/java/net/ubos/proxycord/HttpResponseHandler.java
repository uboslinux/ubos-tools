//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.net.SocketException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Handles the response side of a connection.
 */
public class HttpResponseHandler
    implements
        Runnable
{
    private final static Logger LOG = Logger.getLogger( HttpResponseHandler.class.getName() );

    /**
     * Constructor.
     * 
     * @param requestHandler the HttpRequestHandler to which this HttpResponseHandler belongs
     */
    public HttpResponseHandler(
            HttpRequestHandler requestHandler )
    {
        theRequestHandler = requestHandler;

        LOG.log( Level.INFO, "Created {0} for {1}", new Object[] { this, requestHandler.getName() } );
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
                if( LOG.isLoggable( Level.INFO )) {
                    LOG.info( String.format( "Received (%s) %d bytes", theRequestHandler.getName(), read ));
                }

                theRequestHandler.logResponseData( buf, read );

                serverOutStream.write( buf, 0, read );
                serverOutStream.flush();
                
                if( LOG.isLoggable( Level.INFO )) {
                    LOG.info( String.format( "Sent (%s) %d bytes", theRequestHandler.getName(), read ));
                }
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
     * {@inheritDoc}
     */
    @Override
    public void finalize()
        throws
            Throwable
    {
        LOG.log( Level.INFO, "Finalizing {0} ({1})", new Object[]{ this, theRequestHandler.getName() } );

        super.finalize();
    }

    /**
     * The HttpRequestHandler to which this HttpResponseHandler belongs.
     */
    protected HttpRequestHandler theRequestHandler;
}
