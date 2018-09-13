#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   wpss_tool_fr.pl
#
# $Revision: 5473 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_GUI/Tools/wpss_tool_fr.pl $
# $Date: 2011-09-08 10:42:21 -0400 (Thu, 08 Sep 2011) $
#
# Synopsis: wpss_test_fr.pl
#
# Description:
#
#   Run the wpss_tool.pl program in French mode.
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2011 Government of Canada
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
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
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $rc = system(".\\wpss_tool.pl -fra @ARGV");
} else {
    #
    # Not Windows.
    #
    $rc = system("./wpss_tool.pl -fra @ARGV");
}
exit($rc);
