//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Handles the request side of a connection.
 */
public class HttpRequestHandler
    implements
        Runnable
{
    private final static Logger LOG = Logger.getLogger( HttpRequestHandler.class.getName() );

    /**
     * Constructor.
     * 
     * @param name name of this object, for logging
     * @param app the application
     * @param serverSideSocket the server-side socket
     * @param remoteHost host to connect to
     * @param remotePort port to connect to
     */
    public HttpRequestHandler(
            String    name,
            Proxycord app,
            Socket    serverSideSocket,
            String    remoteHost,
            int       remotePort )
    {
        theName             = name;
        theApp              = app;
        theServerSideSocket = serverSideSocket;
        theRemoteHost       = remoteHost;
        theRemotePort       = remotePort;

        LOG.log( Level.INFO, "Created {0} ({1})", new Object [] { this, theName } );
    }
    
    /**
     * Obtain name, for logging.
     * 
     * @return the name
     */
    public String getName()
    {
        return theName;
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

        theApp.submitTask( new HttpResponseHandler( this ));

        BufferedInputStream  serverInStream  = null;
        BufferedOutputStream clientOutStream = null;
        
        byte [] buf = new byte[4096];
        try {
            serverInStream  = new BufferedInputStream( theServerSideSocket.getInputStream() );
            clientOutStream = new BufferedOutputStream( theClientSideSocket.getOutputStream() );

            int read;
            while( ( read = serverInStream.read( buf )) > 0 ) {
                if( LOG.isLoggable( Level.INFO )) {
                    LOG.info( String.format( "Received (%s) %d bytes", theName, read ));
                }

                logRequestData( buf, read );

                clientOutStream.write( buf, 0, read );
                clientOutStream.flush();
                
                if( LOG.isLoggable( Level.INFO )) {
                    LOG.info( String.format( "Sent (%s) %d bytes", theName, read ));
                }
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
     * Obtain the incoming, server-side socket.
     * 
     * @return the Socket
     */
    public Socket getServerSideSocket()
    {
        return theServerSideSocket;
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
     * Enable ourselves to log traffic we have received.
     * 
     * @param data the data buffer
     * @param count the number of bytes in the data buffer
     */
    public void logRequestData(
            byte [] data,
            int     count )
    {
        if( theRequestStreamBuffer == null ) {
            theRequestStreamBuffer = new ByteArrayOutputStream();
        }
        theRequestStreamBuffer.write( data, 0, count );
        
        // try to find a full HTTP request
        byte [] soFar = theRequestStreamBuffer.toByteArray();
        HttpRequest request = HttpRequest.findHttpRequest( soFar, theName );
        if( request != null ) {
            LOG.log( Level.INFO, String.format( "Queuing request (%s) %s", theName, request.getPath() ));

            theQueuedRequests.add( request );

            theRequestStreamBuffer = new ByteArrayOutputStream();
            byte [] leftover       = request.getLeftoverData();
            if( leftover != null ) {
                try {
                    theRequestStreamBuffer.write( leftover );

                } catch( IOException ex ) {
                    ex.printStackTrace(); // memory only, not likely to happen
                }
            }
        }
    }

    /**
     * Enable our HttpResponseHandler to log traffic it has received.
     * 
     * @param data the data buffer
     * @param count the number of bytes in the data buffer
     */
    public void logResponseData(
            byte [] data,
            int     count )
    {
        if( theResponseStreamBuffer == null ) {
            theResponseStreamBuffer = new ByteArrayOutputStream();
        }
        theResponseStreamBuffer.write( data, 0, count );
        
        // try to find a full HTTP response
        byte [] soFar = theResponseStreamBuffer.toByteArray();

        HttpResponse response = HttpResponse.findHttpResponse( soFar, theName );

        if( response != null ) {
            LOG.log( Level.INFO, String.format( "Unqueuing request (%s)", theName ));

            HttpRequest inResponseTo = theQueuedRequests.remove( 0 );
            theApp.logStep( new HttpRequestResponseStep( inResponseTo, response ));

            theResponseStreamBuffer = new ByteArrayOutputStream();
            byte [] leftover        = response.getLeftoverData();
            if( leftover != null ) {
                try {
                    theResponseStreamBuffer.write( leftover );

                } catch( IOException ex ) {
                    ex.printStackTrace(); // memory only, not likely to happen
                }
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
        LOG.log( Level.INFO, "Finalizing {0} ({1})", new Object [] { this, theName } );

        super.finalize();
    }

    /**
     * Name of this object, for logging.
     */
    protected String theName;

    /**
     * The application
     */
    protected Proxycord theApp;

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
    
    /**
     * Buffers the request stream.
     */
    protected ByteArrayOutputStream theRequestStreamBuffer;
    
    /**
     * Buffers the response stream.
     */
    protected ByteArrayOutputStream theResponseStreamBuffer;
    
    /**
     * Queue of parsed requests. When corresponding Responses arrive,
     * we pass them on together.
     */
    protected List<HttpRequest> theQueuedRequests = new ArrayList<>();
}
