#!/opt/common/perl/bin/perl
#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   wpss_tool_cli.pl
#
# $Revision: 5477 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_CLI/Tools/wpss_tool_cli.pl $
# $Date: 2011-09-08 12:43:38 -0400 (Thu, 08 Sep 2011) $
#
# Synopsis: wpss_tool_cli.pl
#
# Description:
#
#   Run the wpss_tool.pl program in Command Line Interface mode.
#
#***********************************************************************

use File::Basename;
use strict;

my (@paths, $this_path, $program_dir, $program_name, $paths, $rc);

#
# Get our program directory, where we find supporting files
#
$program_dir  = dirname($0);
$program_name = basename($0);

#
# If directory is '.', search the PATH to see where we were found
#
if ( $program_dir eq "." ) {
    $paths = $ENV{"PATH"};
    @paths = split( /:/, $paths );

    #
    # Loop through path until we find ourselves
    #
    foreach $this_path (@paths) {
        if ( -x "$this_path/$program_name" ) {
            $program_dir = $this_path;
            last;
        }
    }
}

#
# Run the wpss_tool.pl program
#
chdir($program_dir);
$rc = system(".\\wpss_tool.pl -cli @ARGV");
exit($rc);
