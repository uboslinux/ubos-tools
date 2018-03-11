/*
 *  Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
 */

package net.ubos.proxycord;

/**
 * A command that can be executed from the terminal.
 */
public interface Command
{
    /**
     * Run the command.
     * 
     * @param app the Proxycord app on which the command is performed
     * @param args command-line arguments, with args[0] being the name of the command
     * @return true if the command was successful
     */
    public boolean run(
            Proxycord  app,
            String ... args );
}
