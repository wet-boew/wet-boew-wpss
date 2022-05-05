#***********************************************************************
#
# Name: TieRegistry.pm
#
# $Revision: 6317 $
# $Source$
# $Date: 2013-06-26 13:45:35 -0400 (Wed, 26 Jun 2013) $
#
# Description:
#
#   This is a dummy Win32::TieRegistry package to allow the wpss_tool to
# run on a non-windows system.
#
#***********************************************************************

package Win32::TieRegistry;

use strict;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw($Registry);
    $VERSION = "1.0";
}

my ($Registry);

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;

