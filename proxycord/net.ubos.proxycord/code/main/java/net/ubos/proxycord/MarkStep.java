//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

/**
 * Marks and possibly names a spot in the recording.
 */
public class MarkStep
    extends
        Step
{
    /**
     * Factory method for an unnamed mark
     *
     * @return the created instance
     */
    public static MarkStep create()
    {
        return new MarkStep( "unnamed" );
    }

    /**
     * Factory method for a named mark
     *
     * @param name the name of the mark
     * @return the created instance
     */
    public static MarkStep create(
            String name )
    {
        return new MarkStep( name );
    }

    /**
     * Private constructor, use factory method.
     * 
     * @param name the name of the mark
     */
    protected MarkStep(
            String name )
    {
        theName = name;
    }

    @Override
    public JsonElement asJson()
    {
        JsonObject jsonRet = new JsonObject();
        jsonRet.add( "type",  new JsonPrimitive( "Mark" ));
        jsonRet.add( "name",  new JsonPrimitive( theName ));
        return jsonRet;
    }

    /**
     * Convert to String, for output on the console.
     * 
     * @return as String
     */
    @Override
    public String toString()
    {
        return "Mark: " + theName;
    }

    /**
     * The name of the mark.
     */
    protected String theName;
}
