Proxycord
=========

What is it?
-----------

Proxycord is a utility that records a web browsing session for later
analysis or playback.

It was created for automated testing of web applications running on
[UBOS](https://ubos.net/) but it's likely useful for other applications
as well.

How does it work?
-----------------

Let's say the web application you want to test runs at `http://example.com/`.
You run Proxycord locally on your machine, like this:

```
proxycord --remote-host example.com --out session.json
```

Instead of pointing your browser to `http://example.com/`, you access
`http://localhost:8080`. Proxycord listens at that local port 8080, and
does two things:
 * it forwards all requests and responses, byte for byte, to
   `http://example.com/`, i.e. it acts as a proxy.
 * it records all requests and responses and writes those into
   file `session.json`.

While Proxycord is running, it can be given interactive commands from
the command-line. The most important of which is `quit` :-)

How do I run it?
----------------

First, clone this repository.

Then, if you are on [UBOS](https://ubos.net/), [Arch Linux](https://archlinux.org/)
or [Arch Linux ARM]](https://archlinuxarm.org), build and install Proxycord
by executing:
```
makepkg -i
```
and run it with
```
proxycord ...
```
If you are on a different operating system (Linux, MacOS and Windows should
all work), you need to have (Apache Maven)[https://maven.apache.org/] installed.
Build Proxycord by executing:

```
cd net.ubos.proxycord
mvn package
```
and run it with
```
java -jar target/net.ubos.proxycord-0.1.jar
```

License
-------

AGPLv3. Patches welcome.
