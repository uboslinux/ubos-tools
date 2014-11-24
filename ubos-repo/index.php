<?php
$dir     = NULL;
$context = getenv( 'CONTEXT' );
$uri     = $_SERVER['REQUEST_URI'];
?>
<html>
 <head>
  <title>Index of <?= $uri ?></title>
 </head>
 <body>
  <h1>Index of <?= $uri ?></h1>
<?php
if( strpos( $uri, $context ) == 0 ) {
    $dir = getenv( 'DATADIR' ) . substr( $uri, strlen( $context ));
}
if( $dir && is_dir( $dir )) {
    $files = array();

    if( is_dir( $dir ) && $handle = opendir( $dir )) {
        while( false !== ( $file = readdir( $handle ))) {
            if( $file == '.' || $file == '..' || $file == 'index.php' ) {
                continue;
            }
            $files[] = $file;
        }
        closedir( $handle );
        rsort( $files );
    }

    if( sizeof( $files ) > 0 ) {
        print "  <ul>\n";
        foreach( $files as $file ) {
            print "   <li>";
            $fullFile = "$dir/$file";

            if( is_link( $fullFile )) {
                $target = readlink( $fullFile );
                if( strchr( $target, '/' ) === FALSE ) {
                    print "$file&nbsp;&nbsp;&nbsp;&nbsp;&#10145;&nbsp;&nbsp;&nbsp;&nbsp;<a href='$target'>$target</a>";
                } else {
                    print $file; // not safe
                }
            }  else {
                print "<a href='$file'>$file</a>";
            }
            print "</li>\n";
        }
        print "  </ul>\n";

    } else {
        print "<p>No images currently available.</p>\n";
    }
}
?>
 </body>
</html>
