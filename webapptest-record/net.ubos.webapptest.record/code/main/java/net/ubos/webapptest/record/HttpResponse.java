//
// Copyright (C) 1998 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.webapptest.record;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 *
 */
public class HttpResponse
    extends
        HttpMessage
{
    /**
     * Factory method.
     *
     * @param data the data to parse
     * @return the created instance
     */
    public static HttpResponse findHttpResponse(
            byte [] data )
    {
        HttpResponse ret = new HttpResponse();
        if( ret.parse( data )) {
            return ret;
        } else {
            return null;
        }
    }

    /**
     * Private constructor, use factory method.
     */
    protected HttpResponse()
    {}
    
    @Override
    protected boolean parseFirstLine(
            String firstLine )
    {
        Matcher firstLineMatcher = FIRST_LINE_PATTERN.matcher( firstLine );
        if( !firstLineMatcher.matches() ) {
            return false;
        }
        theVersion = firstLineMatcher.group( 1 );
        theStatus  = Integer.parseInt( firstLineMatcher.group( 2 ));
        
        return true;
    }

    /**
     * Obtain the HTTP status.
     * 
     * @return the HTTP status
     */
    public int getStatus()
    {
        return theStatus;
    }

    /**
     * The HTTP status.
     */
    protected int theStatus;

    /**
     * Regex for the first line in the HTTP response.
     */
    protected static final Pattern FIRST_LINE_PATTERN = Pattern.compile(
            "^HTTP/([\\d\\.]+) (\\d+) ([a-zA-Z0-9 ]+)$" );
}
