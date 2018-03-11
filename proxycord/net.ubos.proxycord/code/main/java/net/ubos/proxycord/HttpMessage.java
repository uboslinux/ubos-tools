//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.ByteArrayOutputStream;
import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.Map;

/**
 * Common superclass for HttpRequest and HttpResponse because parsing either
 * is rather similar.
 */
public abstract class HttpMessage
{
    /**
     * Parse some data to set values on the instance (of a subclass) of HttpMessage.
     * This returns true if the entire HttpMessage was successfully parsed, and
     * false if not enough data was present to be able to parse the HttpMessage.
     * If successful, property LeftoverData contains data after the end of the
     * HttpMessage.
     * 
     * @param data the data to parse
     * @return true if successfully parsed
     */
    protected boolean parse(
            byte [] data )
    {
        // look for \r\n: ends a line. Empty line ends header

        int pos = 0;
        
        // look for first line
        for( int i=pos ; i < data.length-1; ++i ) {
            if( data[i] == '\r' && data[i+1] == '\n' ) {
                String firstLine = new String( data, 0, i, US_ASCII );
                if( !parseFirstLine( firstLine )) {
                    return false;
                }

                pos = i+2;
                break;
            }
        }
        
        // look for header
        boolean haveFullHeader = false;
        theHeaders = new HashMap<>();
        while( pos < data.length-1 ) {
            if( data[pos] == '\r' && data[pos+1] == '\n' ) {
                // end of header
                haveFullHeader = true;
                pos += 2;
                break;
            }
            for( int i=pos ; i < data.length; ++i ) {
                if( data[i] == '\r' && data[i+1] == '\n' ) {
                    // end of line
                    String    headerLine = new String( data, pos, i-pos, US_ASCII );
                    String [] pair       = headerLine.split( ":\\s*", 2 );
                    
                    String [] already = theHeaders.get( pair[0] );
                    if( already == null ) {
                        theHeaders.put( pair[0], new String[] { pair[1] } );
                    } else {
                        String [] already2 = new String[ already.length + 1 ];
                        System.arraycopy( already, 0, already2, 0, already.length );
                        already2[ already2.length-1 ] = pair[1];
                        theHeaders.put( pair[0], already2 );
                    }
                    pos = i+2;
                    break;
                }
            }
        }
        if( !haveFullHeader ) {
            return false;
        }
        
        // unfortunately there are different transfer encodings, and we need to
        // handle them separately

        if( theHeaders.containsKey( HTTP_CONTENT_LENGTH_HEADER )) {
            int contentLength = Integer.valueOf( theHeaders.get( HTTP_CONTENT_LENGTH_HEADER )[0]);
            if( data.length - pos >= contentLength ) {
                theContent = new byte[ contentLength ];
                System.arraycopy( data, pos, theContent, 0, contentLength );
            }

        } else if(    theHeaders.containsKey( HTTP_TRANSFER_ENCODING_HEADER )
                   && HTTP_TRANSFER_ENCODING_CHUNKED.equals( theHeaders.get( HTTP_TRANSFER_ENCODING_HEADER )[0] ))
        {
            // now try to aggregate
            ByteArrayOutputStream buf = new ByteArrayOutputStream();

            for( int i=pos ; i < data.length-1; /* let's not increment here */ ) {
                if( data[i] == '\r' && data[i+1] == '\n' ) {
                    // have chunk length
                    String chunkLengthString = new String( data, pos, i-pos, US_ASCII );
                    int    chunkLength       = Integer.parseInt( chunkLengthString, 16 );
                    
                    if( chunkLength == 0 ) { // we are done
                        pos = i+4; // two sets of \r\n
                        theContent = buf.toByteArray();
                        if( pos < data.length ) {
                            theLeftoverData = new byte[ data.length - pos ];
                            System.arraycopy( data, pos, theLeftoverData, 0, data.length - pos );
                        } else {
                            theLeftoverData = null; // let's be explicit
                        }
                        break;
                        
                    } else if( data.length - i >= chunkLength+2 ) {
                        pos = i+2;
                        buf.write( data, pos, chunkLength );
                        pos += chunkLength + 2; // assuming \r\n follows as they are supposed to
                        i    = pos;

                    } else { // sorry, not enough
                        return false;
                    }
                } else {
                    ++i;
                }
            }
            if( theContent == null ) {
                return false;
            }
        }
        
        return true;        
    }
    
    /**
     * The first line is different between HttpRequest and HttpResponse, so how to
     * parse it is defined in subclasses.
     * 
     * @param firstLine the first line
     * @return true if successfully parsed
     */
    protected abstract boolean parseFirstLine(
            String firstLine );

    /**
     * Obtain any leftover data in the passed-in data array that was not used
     * for this HttpMessage.
     * 
     * @return leftover data, or null
     */
    public byte [] getLeftoverData()
    {
        return theLeftoverData;
    }
    
    /**
     * Obtain the HTTP version.
     * 
     * @return the version
     */
    public String getVersion()
    {
        return theVersion;
    }
    
    /**
     * Obtain the HTTP headers.
     * 
     * @return the headers
     */
    public Map<String,String[]> getHeaders()
    {
        return theHeaders;
    }

    /**
     * Obtain the message content. May be null.
     * 
     * @return the content
     */
    public byte [] getContent()
    {
        return theContent;
    }
    
    /**
     * The HTTP protocol version.
     */
    protected String theVersion;
    
    /**
     * The HTTP headers.
     */
    protected Map<String,String[]> theHeaders;
    
    /**
     * The content of the request.
     */
    protected byte [] theContent;

    /**
     * Data that was not used to parse this request.
     */
    protected byte [] theLeftoverData;
    
    /**
     * Decodes bytes into US-ASCII.
     */
    protected static final Charset US_ASCII = Charset.forName( "US-ASCII" );

    /**
     * HTTP content length header
     */
    public static final String HTTP_CONTENT_LENGTH_HEADER = "Content-Length";

    /**
     * HTTP transfer encoding header
     */
    public static final String HTTP_TRANSFER_ENCODING_HEADER = "Transfer-Encoding";
    
    /**
     * HTTP chunked transfer encoding value
     */
    public static final String HTTP_TRANSFER_ENCODING_CHUNKED = "chunked";
    
    /**
     * HTTP content type header
     */
    public static final String HTTP_CONTENT_TYPE_HEADER = "Content-Type";
}
