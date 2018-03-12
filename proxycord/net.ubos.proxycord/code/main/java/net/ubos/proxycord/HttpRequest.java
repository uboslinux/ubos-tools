//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The HTTP request.
 */
public class HttpRequest
    extends
        HttpMessage
{
    private final static Logger LOG = Logger.getLogger( HttpRequest.class.getName() );

    /**
     * Factory method.
     *
     * @param data the data to parse
     * @param requestHandlerName name of the request handler, for logging
     * @return the created HttpRequest, or null if not enough data
     */
    public static HttpRequest findHttpRequest(
            byte [] data,
            String  requestHandlerName )
    {
        HttpRequest ret = new HttpRequest();
        if( ret.parse( data )) {
            LOG.log( Level.INFO, "Succeeded parsing HttpRequest ({0}) {1}", new Object[] { requestHandlerName, ret.thePath } );
            return ret;

        } else {
            LOG.log( Level.INFO, "Failed parsing HttpRequest ({0}) {1}", new Object[] { requestHandlerName, ret.thePath } );
            return null;
        }
    }

    /**
     * Private constructor, use factory method.
     */
    protected HttpRequest()
    {}

    @Override
    protected boolean parseFirstLine(
            String firstLine )
    {
        Matcher firstLineMatcher = FIRST_LINE_PATTERN.matcher( firstLine );
        if( !firstLineMatcher.matches() ) {
            return false;
        }
        theVerb    = firstLineMatcher.group( 1 );
        thePath    = firstLineMatcher.group( 2 );
        theVersion = firstLineMatcher.group( 3 );
        
        return true;
    }

    /**
     * Obtain the HTTP verb.
     * 
     * @return the verb
     */
    public String getVerb()
    {
        return theVerb;
    }
    
    /**
     * Obtain the HTTP path.
     * 
     * @return the path
     */
    public String getPath()
    {
        return thePath;
    }

    /**
     * The HTTP verb of the request.
     */
    protected String theVerb;
    
    /**
     * The path of the request (not hostname or protocol)
     */
    protected String thePath;

    /**
     * Regex for the first line in the HTTP request.
     */
    protected static final Pattern FIRST_LINE_PATTERN = Pattern.compile(
            "^([A-Z]+) ([^\\s]+) HTTP/([\\d\\.]+)$" );
}
