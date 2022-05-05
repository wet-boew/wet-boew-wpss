#!/usr/bin/perl

#####################################################################
#
# Offline HTMLHelp.com Validator
# by Liam Quinn <liam@htmlhelp.com>
#
# This is a simplified version of the online WDG HTML Validator
# found at <http://www.htmlhelp.com/tools/validator/>.
#
# Copyright (c) 1998-2003 by Liam Quinn
# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# Contributors:
# * Ville Skytta
#
# PWGSC modifications by Kevin Irwin.
#   Change path for supporting files
#   Use nsgmls.exe rather than lq-nsgmls
#   Use temporary file for nsgmls output
#
# $Revision: 6727 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/HTML_Validate/Tools/win_validate.pl $
# $Date: 2014-07-23 11:26:10 -0400 (Wed, 23 Jul 2014) $
#
#####################################################################

#####################################################################
# Required libraries #
######################

# These are all standard Perl modules; we'll check for URI and LWP
# later on demand.

use strict;
use Getopt::Long qw(GetOptions);
use Text::Wrap qw(wrap);
use POSIX qw(:fcntl_h);

# If File::Spec::Functions isn't available, let's fall back quietly
# to a replacement function.
eval {
    require File::Spec::Functions;
    File::Spec::Functions->import('catfile');
};
*catfile = sub { join('/', @_) } if $@;

#####################################################################

#####################################################################
# Variables to define #
#######################

# Version and identifier of this program
my $VERSION = '1.2';
my $progname = "Offline HTMLHelp.com Validator, Version $VERSION
by Liam Quinn <liam\@htmlhelp.com>";
my $usage = "Usage: validate [OPTION] [FILE...]";

my $validate_home = "."; # PWGSC modification

# SGML directory (catalog, DTDs, SGML declarations)
#my $sgmlDir = '/usr/local/share/wdg/sgml-lib';
my $sgmlDir = "$validate_home/wdg/sgml-lib"; # PWGSC modification

my $nsgmlsLocation;
# Location of lq-nsgmls executable

#my $nsgmlsLocation = '/usr/local/bin/lq-nsgmls';
$nsgmlsLocation = "$validate_home/nsgmls/bin/nsgmls.exe"; # PWGSC modification

# lq-nsgmls command line
# The SGML declaration and HTML document's filename will be appended
# to this string
my $nsgmls = "$nsgmlsLocation -E0 -s";

# Warnings to pass on command-line to lq-nsgmls, if desired
my $nsgmlsWarnings = '-wnon-sgml-char-ref -wmin-tag';
my $nsgmlsXMLWarnings = '-wxml';

# lq-nsgmls "errors" that are not reported unless warnings are requested.
# These are true errors in XML validation, but they should only be
# reported as warnings otherwise.
my %errorAsWarning = (
  ' net-enabling start-tag not supported in {{XML}}' => 1,
  ' unclosed start-tag' => 1,
  ' unclosed end-tag' => 1
);

# Catalog files for HTML/SGML and XHTML/XML
my $htmlCatalog  = catfile($sgmlDir, 'catalog');
my $xhtmlCatalog = catfile($sgmlDir, 'xhtml.soc');

# Where to direct errors (typically *STDOUT or *STDERR)
my $errout = *STDOUT;

# Versions of HTML associated with a given FPI
my %HTMLversion = (
  'PUBLIC "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN"' => 'XHTML 1.1 plus MathML 2.0',
  'PUBLIC "-//W3C//DTD MathML 2.0//EN"' => 'MathML 2.0',
  'PUBLIC "-//W3C//DTD XHTML 1.1//EN"' => 'XHTML 1.1',
  'PUBLIC "-//WAPFORUM//DTD WML 1.3//EN"' => 'WML 1.3',
  'PUBLIC "-//WAPFORUM//DTD WML 1.2//EN"' => 'WML 1.2',
  'PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"' => 'WML 1.1',
  'PUBLIC "-//WAPFORUM//DTD WML 1.0//EN"' => 'WML 1.0',
  'PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN"' => 'XHTML Basic',
  'PUBLIC "ISO/IEC 15445:2000//DTD HyperText Markup Language//EN"' => 'ISO/IEC 15445:2000',
  'PUBLIC "ISO/IEC 15445:2000//DTD HTML//EN"' => 'ISO/IEC 15445:2000',
  'PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"' => 'XHTML 1.0 Strict',
  'PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"' => 'XHTML 1.0 Transitional',
  'PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"' => 'XHTML 1.0 Frameset',
  'PUBLIC "-//W3C//DTD HTML 4.01//EN"' => 'HTML 4.01 Strict',
  'PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"' => 'HTML 4.01 Transitional',
  'PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"' => 'HTML 4.01 Frameset',
  'PUBLIC "-//W3C//DTD HTML 4.0//EN"' => 'HTML 4.0 Strict',
  'PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"' => 'HTML 4.0 Transitional',
  'PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN"' => 'HTML 4.0 Frameset',
  'PUBLIC "-//W3C//DTD HTML 3.2 Final//EN"' => 'HTML 3.2',
  'PUBLIC "-//W3C//DTD HTML 3.2 Draft//EN"' => 'HTML 3.2',
  'PUBLIC "-//W3C//DTD HTML 3.2//EN"' => 'HTML 3.2',
  'PUBLIC "-//W3C//DTD HTML Experimental 970421//EN"' => 'HTML 3.2 + Style',
  'PUBLIC "-//W3O//DTD W3 HTML 3.0//EN"' => 'HTML 3.0 Draft',
  'PUBLIC "-//IETF//DTD HTML 3.0//EN//"' => 'HTML 3.0 Draft',
  'PUBLIC "-//IETF//DTD HTML 3.0//EN"' => 'HTML 3.0 Draft',
  'PUBLIC "-//IETF//DTD HTML i18n//EN"' => 'HTML 2.0 + i18n',
  'PUBLIC "-//IETF//DTD HTML//EN"' => 'HTML 2.0',
  'PUBLIC "-//IETF//DTD HTML 2.0//EN"' => 'HTML 2.0',
  'PUBLIC "-//IETF//DTD HTML Level 2//EN"' => 'HTML 2.0',
  'PUBLIC "-//IETF//DTD HTML 2.0 Level 2//EN"' => 'HTML 2.0',
  'PUBLIC "-//IETF//DTD HTML Level 1//EN"' => 'HTML 2.0 Level 1',
  'PUBLIC "-//IETF//DTD HTML 2.0 Level 1//EN"' => 'HTML 2.0 Level 1',
  'PUBLIC "-//IETF//DTD HTML Strict//EN"' => 'HTML 2.0 Strict',
  'PUBLIC "-//IETF//DTD HTML 2.0 Strict//EN"' => 'HTML 2.0 Strict',
  'PUBLIC "-//IETF//DTD HTML Strict Level 2//EN"' => 'HTML 2.0 Strict',
  'PUBLIC "-//IETF//DTD HTML 2.0 Strict Level 2//EN"' => 'HTML 2.0 Strict',
  'PUBLIC "-//IETF//DTD HTML Strict Level 1//EN"' => 'HTML 2.0 Strict Level 1',
  'PUBLIC "-//IETF//DTD HTML 2.0 Strict Level 1//EN"' => 'HTML 2.0 Strict Level 1'
);

# SGML declarations for a given level of HTML
my %sgmlDecl = (
  'XHTML 1.1 plus MathML 2.0' => catfile($sgmlDir, 'xhtml11', 'xml1n.dcl'),
  'MathML 2.0'                => catfile($sgmlDir, 'xhtml11', 'xml1n.dcl'),
  'XHTML 1.1'                 => catfile($sgmlDir, 'xhtml11', 'xml1n.dcl'),
  'WML 1.3'                   => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'WML 1.2'                   => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'WML 1.1'                   => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'WML 1.0'                   => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'XHTML Basic'               => catfile($sgmlDir, 'xhtml-basic10','xml1.dcl'),
  'ISO/IEC 15445:2000'        => catfile($sgmlDir, '15445.dcl'),
  'XHTML 1.0 Strict'          => catfile($sgmlDir ,'xhtml1', 'xhtml1.dcl'),
  'XHTML 1.0 Transitional'    => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'XHTML 1.0 Frameset'        => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
  'HTML 4.01 Strict'          => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 4.01 Transitional'    => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 4.01 Frameset'        => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 4.0 Strict'           => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 4.0 Transitional'     => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 4.0 Frameset'         => catfile($sgmlDir, 'HTML4.dcl'),
  'HTML 3.2'                  => catfile($sgmlDir, 'HTML32.dcl'),
  'HTML 3.2 + Style'          => catfile($sgmlDir, 'html-970421.decl'),
  'HTML 3.0 Draft'            => catfile($sgmlDir, 'HTML3.dcl'),
  'HTML 2.0 + i18n'           => catfile($sgmlDir, 'i18n.dcl'),
  'HTML 2.0'                  => catfile($sgmlDir, 'html.dcl'),
  'HTML 2.0 Strict'           => catfile($sgmlDir, 'html.dcl'),
  'HTML 2.0 Level 1'          => catfile($sgmlDir, 'html.dcl'),
  'HTML 2.0 Strict Level 1'   => catfile($sgmlDir, 'html.dcl'),
  'Unknown'                   => catfile($sgmlDir, 'custom.dcl'),

  # For generic XML validation (using the --xml option)
  'XML'                       => catfile($sgmlDir, 'xhtml1', 'xhtml1.dcl'),
);

# XHTML DTDs
my %xhtml = (
  'XHTML 1.1 plus MathML 2.0' => 1,
  'MathML 2.0'                => 1,
  'XHTML 1.1'                 => 1,
  'WML 1.3'                   => 1,
  'WML 1.2'                   => 1,
  'WML 1.1'                   => 1,
  'WML 1.0'                   => 1,
  'XHTML Basic'               => 1,
  'XHTML 1.0 Strict'          => 1,
  'XHTML 1.0 Transitional'    => 1,
  'XHTML 1.0 Frameset'        => 1,
  'XML'                       => 1,
);

# Default DOCTYPE if the document is missing a DOCTYPE
my $defaultDoctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
   "http://www.w3.org/TR/html4/loose.dtd">';

# Default DOCTYPE if the document contains frames
my $defaultFramesetDoctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
   "http://www.w3.org/TR/html4/frameset.dtd">';

# Error for missing DOCTYPE
my $noDoctype = "missing document type declaration; assuming HTML 4.01 Transitional";

# Error for missing DOCTYPE in a Frameset document
my $noFramesetDoctype = "missing document type declaration; assuming HTML 4.01 Frameset";

#####################################################################

#####################################################################
#
# The rest of the script...
#
#####################################################################

# Get rid of unsafe environment variables, see perlsec
delete(@ENV{qw(PATH IFS CDPATH ENV BASH_ENV)});

# Flush output buffer
$| = 1;

### Get user input ###

# Character encoding to use (optional)
my $charsetOverride;

# Verbose output (optional)
my $verbose;

# Emacs-friendly output
my $emacs = ($ENV{EMACS} && $ENV{EMACS} eq 't');

# XML mode
my $xml;

# Whether warnings are desired
my $warnings;

# Help and version info
my $help;
my $versionInfo;

GetOptions("xml" => \$xml, "charset=s" => \$charsetOverride,
    "verbose" => \$verbose, "help|h" => \$help,
    "version|v" => \$versionInfo, "emacs!" => \$emacs,
    "warn|w|W" => \$warnings);

# Files to validate
my @files = @ARGV;

######################

my $errors = 0;

if ($versionInfo || $help) {
    if ($versionInfo) {
        print "$progname\n";
    }
    if ($help) {
        &helpText;
    }
    exit $errors;
}

if ($#files == -1) {
    push(@files, '-');
}

# Check that nsgmls is available before we get too far
unless (-e $nsgmlsLocation) {
    &error("$nsgmlsLocation is not installed");
    exit $errors;
}
unless (-x _) {
    &error("$nsgmlsLocation is not executable");
    exit $errors;
}

# Check if we can use URIs.
eval {
    require URI;
    require LWP::UserAgent;
};
my $uri_ok = !$@;

my $ua;
my $file;
foreach $file (@files) {

    my $tempname = undef;
    my $tempfh = undef;
    my $charset = $charsetOverride;
    my $req = undef;
    my $canonical_uri;

    # Read in document
    my $document = "";
    my @html_lines;
    my $fileIsURL = 0;
    if ($file ne '-') {
        if ($uri_ok && $file =~ m|^\w+://.+|i) {
            $fileIsURL = 1;
            $ua ||= LWP::UserAgent->new(env_proxy => 1, keep_alive => 1);

            #
            # Set user agent string
            #
            $ua->agent( "html_validate/1.0" );

            my $uri = URI->new($file);
            unless ($ua->is_protocol_supported($uri)) {
                &error('Unsupported protocol: ' . $uri->scheme());
                next;
            }
            $canonical_uri = $uri->canonical;
            $req = new HTTP::Request( GET => $canonical_uri );
            #my $res = $ua->get($uri->canonical());
            my $res = $ua->request($req);
            if ($res->is_success()) {
                $document = $res->content();
                unless ($charset) {
                    my $contentType = $res->header('Content-Type');
                    if ($contentType && $contentType =~ /[\s;]charset\s*=\s*"?([^,"\s]+)/io) {
                        $charset = $1;
                    }
                }
            } else {
                &error($res->status_line());
                next;
            }

        } else {
            unless (-e $file) {
                &error("File $file does not exist.");
                next;
            }
            unless (-r _) {
                &error("File $file is not readable.");
                next;
            }

            open(IN, $file) || die "Unexpected error reading $file: $!\n";
            while (<IN>) {
                $document .= $_;
            }
            close(IN);
        }
    } else {
        while (<>) {
            $document .= $_;
        }
    }

    #
    # Save the HTML source lines in a list so we can print
    # out lines containing errors.
    #
    @html_lines = split(/\n|\r/, $document); # PWGSC modification

    unless ($charset) {
        # Check for a META element specifying the character encoding
        if ($document =~ m#<META(\s[^>]*http\-equiv\s*=\s*["']?Content\-Type["']?[^>]*)>#iso) {
            my $metaAttributes = $1;
            if ($metaAttributes =~ m#\scontent\s*=\s*["']?.*[\s;]charset\s*=\s*['"]?([^"']+)#iso) {
                $charset = $1;
            }
        }
    }

    my @errors; # queue of errors
    my @externalErrors; # queue of errors in an external DTD
    my $lineAdjust = 0; # account for line number changes if we add a DOCTYPE

    # Determine the level of HTML
    my $htmlLevel;
    my $fileToValidate = $file;
    if ($xml) {
        $htmlLevel = 'XML';
    } else {
        $htmlLevel = 'Unknown';
    }
    if ($document =~ /<!DOCTYPE([^>]*)>/iso) {

        my $doctypeMeat = $1;
        if ($doctypeMeat =~ /PUBLIC\s+("[^"]*")/iso) {
            $htmlLevel = $HTMLversion{"PUBLIC $1"} || $htmlLevel;
        }

        if ($fileIsURL || $file eq '-') {
            ($tempname, $tempfh) = getTempFile();
            print $tempfh "$document";
            close($tempfh);

            $fileToValidate = $tempname;
        }

    } else { # Missing DOCTYPE

        # Add a default DOCTYPE
        my ($insertedDoctype, $doctypeError);
        if ($document =~ /<FRAMESET/io) {
            $insertedDoctype = $defaultFramesetDoctype;
            $doctypeError = $noFramesetDoctype;
        } else {
            $insertedDoctype = $defaultDoctype;
            $doctypeError = $noDoctype;
        }

        ($tempname, $tempfh) = getTempFile();
        print $tempfh "$insertedDoctype\n$document";
        close($tempfh);

        $fileToValidate = $tempname;
        $lineAdjust = 2;
        push(@errors, "::" . (1 + $lineAdjust) . ":0:E: $doctypeError");

    }

    # Determine whether we're dealing with HTML or XHTML and set the SP
    # environment accordingly.
    if ($xhtml{$htmlLevel}) {
        $ENV{'SGML_CATALOG_FILES'} = $xhtmlCatalog;
        $ENV{'SP_ENCODING'} = 'xml';
        $xml = 1;
    } else {
        $ENV{'SGML_CATALOG_FILES'} = $htmlCatalog;
        if (defined $charset) {
            $ENV{'SP_ENCODING'} = $charset;
        } else {
            $ENV{'SP_ENCODING'} = "ISO-8859-1";
        }
    }
    $ENV{'SP_CHARSET_FIXED'} = 1;

    if ($verbose) {
        if ($file eq '-') {
            print wrap("", "\t",
                "Checking with $htmlLevel document type...\n");
        } else {
            print wrap("", "\t",
                "Checking $file with $htmlLevel document type...\n");
        }
    }

    my $warningsCmd = '';
    if ($warnings) {
        if ($xml) {
            $warningsCmd = "$nsgmlsXMLWarnings";
        } else {
            $warningsCmd = "$nsgmlsWarnings";
        }
    }

    # Run the validator
#    open(NSGMLS, "$nsgmls $warningsCmd $sgmlDecl{$htmlLevel} "
#        . &quoteFilename($fileToValidate) . " 2>&1 |")
#        || die("Unable to execute $nsgmls: $!\n");
    my $nsgmls_output_name = "nsgmls_out$$.txt"; # PWGSC modification
    unlink($nsgmls_output_name); # PWGSC modification
    my $rc = system("$nsgmls -f $nsgmls_output_name $warningsCmd " .
                    $sgmlDecl{$htmlLevel} . " " . 
                    &quoteFilename($fileToValidate)); # PWGSC modification
    open(NSGMLS, "$nsgmls_output_name")
        || die("Unable to open $nsgmls_output_name: $!\n"); # PWGSC modification

    #
    # Get number of colons in the file path.  If the file path contains colons
    # (e.g. fully qualified path with a drive letter), the output of the
    # nsgmls tool contains extra fields.
    #
    my @colons = split(/:/, $fileToValidate);
    my $n_colons = @colons - 1;
    # Create a queue of errors
    while (<NSGMLS>) {
        chomp;

        my @error = split(/:/, $_, 6 + $n_colons);

        if ($#error < 4) {

            next;

        } elsif ($error[4 + $n_colons] eq 'E' || $error[4 + $n_colons] eq 'X') {

            # With warnings enabled in non-XML validation, some "errors"
            # reported by lq-nsgmls are probably better reported as "warnings"
            # since they are only reported with warnings enabled.
            if ($warnings && !$xml) {
                if ($errorAsWarning{$error[5 + $n_colons]}) {
                    $error[4 + $n_colons] = 'W';

                    # lq-nsgmls uses an XML-specific message for one of
                    # these warnings.  Let's try something more helpful
                    # for HTML.
                    if ($error[5 + $n_colons] eq ' net-enabling start-tag not supported in {{XML}}') {
                        $error[5 + $n_colons] = ' net-enabling start-tag; possibly missing required quotes around an attribute value or using XHTML syntax in HTML';
                    }

                    $_ = join(':', @error);
                }
            }

            push(@errors, $_);

            # If the DOCTYPE is bad, bail out
            last if ($error[5 + $n_colons] eq ' unrecognized {{DOCTYPE}}; unable to check document');

        } elsif ($error[4 + $n_colons] eq 'W') {

            unless ($error[5 + $n_colons] eq ' characters in the document character set with numbers exceeding 65535 not supported')
            {
                push(@errors, $_);
            }

        } elsif ($error[1 + $n_colons] =~ /^<URL>/o) { # error from external DTD

            push(@externalErrors, $_);

        } elsif (length($error[4 + $n_colons]) > 1 # Allow secondary messages about preceding error
            && $error[3 + $n_colons] ne 'W') # Prevent error about SGML declaration not implied with -wxml
        {
            push(@errors, $_);
        }

    }
    close(NSGMLS);
    unlink($nsgmls_output_name); # PWGSC modification

    # If we created a tempfile, unlink it
    if (defined $tempname) {
        unlink($tempname);
    }

    # Report errors
    if ($#errors > -1 || $#externalErrors > -1) {

        #&startErrors($file);

        foreach (@externalErrors) {
            my @error = split(/:/, $_, 7);

            # Determine URL containing the error
            my $errorURL;
            if ($error[1 + $n_colons] =~ /<URL>(.+)/o) {
                $errorURL = "$1:$error[2 + $n_colons]";
            }

            my $lineNumber = $error[3 + $n_colons];
            my $character = $error[4 + $n_colons] + 1;

            my $errorMsg;
            if ($emacs) {
                $errorMsg = "$errorURL:$lineNumber:$character:";
            } else {
                $errorMsg = "$errorURL, line $lineNumber, character $character: ";
            }

            if ($error[6 + $n_colons]) {
                $errorMsg .= superChomp($error[6 + $n_colons]);
            } else {
                $errorMsg .= superChomp($error[5 + $n_colons]);
            }

            &htmlError(stripLqNsgmlsGunk($errorMsg));
        }

        foreach (@errors) {
            my @error = split(/:/, $_, 6 + $n_colons);

            # I don't think this should happen, but I'm not sure
            next if $#error < 4;

            # Determine line number and character of error
            my $lineNumber = $error[2 + $n_colons] - $lineAdjust;
            next unless $lineNumber > 0;
            my $character = $error[3 + $n_colons] + 1;

            my $msgType;
            if ($error[4 + $n_colons] eq 'E' || $error[4 + $n_colons] eq 'X') { # Error message
                $msgType = $emacs ? 'E' : 'Error at';
            } elsif ($error[4 + $n_colons] eq 'W') {
                $msgType = $emacs ? 'W' : 'Warning at';
            }


            # Prepare error message
            my $errorMsg;
            if ($emacs) {
                $errorMsg = "$file:$lineNumber:$character:";
                if (defined $msgType) {
                    $errorMsg .= "$msgType:";
                }
            } else {
                my $line;
                if (defined $msgType) {
                    $line = ' line';
                } else {
                    $line = 'Line';
                    $msgType = "\t";
                }
                $errorMsg = "$msgType$line $lineNumber, character $character: ";
            }

            if ($error[5 + $n_colons]) {
                $errorMsg .= superChomp($error[5 + $n_colons]);
            } else {
                $errorMsg .= superChomp($error[4 + $n_colons]);
            }

            &htmlError(stripLqNsgmlsGunk($errorMsg));

            #
            # Print out the line containing the error
            #
            print $html_lines[$lineNumber - 1] . "\n";
        }

    } else {

        if ($verbose) {
            print "No errors!\n";
        }
    }
}

exit $errors;

# Return an error message
# The error message must be given as the first argument
sub error {
    my $error_message = shift;
    print $errout wrap("", "\t", "ERROR: \t$error_message\n");
    ++$errors;
}

# Heading to start HTML errors
# The file being validated should be given as the first argument
sub startErrors {
    my $file = shift;
    if (length $file) {
        my $andWarnings = $warnings ? ' and warnings' : '';

        if ($file eq '-') {
            print $errout "*** Errors$andWarnings: ***\n";
        } else {
            if ($emacs) {
                print $errout "*** Errors" . $andWarnings . " validating $file: ***\n";
            } else {
                print $errout wrap("", "\t",
                    "*** Errors" . $andWarnings . " validating $file: ***\n");
            }
        }
    }
}

sub quoteFilename {
    my $filename = shift;

    $filename =~ s/\\/\\\\/go;
    $filename =~ s/"/\\"/go;
 
    # Untaint
    if ($filename =~ /^(.*)$/) {
        $filename = $1;
    }

    return "\"$filename\"";
}

# Clean the "{{foo}}" used in lq-nsgmls error messages
# The error message must be given as the first argument
sub stripLqNsgmlsGunk {
    my $errorMsg = shift;
    while ($errorMsg =~ m#\{\{"?(.+?)"?\}\}#gos) {
        my $linkText = $1;
        $errorMsg =~ s#\{\{(")?$linkText(")?\}\}#$1$linkText$2#;
    }
    return $errorMsg;
}

# Report an HTML error
# The error message must be given as the first argument
sub htmlError {
    my $error_message = shift;

    if ($emacs) {
        print $errout "$error_message\n";
    } else {
        print $errout wrap("", "\t", "$error_message\n");
    }

    ++$errors;
}


# Remove any newline characters (\r or \n) at the end of a string
# First argument is the string
# Returns the new string
sub superChomp {

    my $str = shift || return;
    $str =~ s/[\r\n]+$//o;
    return $str;

}


# Create temporary file securely
# Returns the name and file handle of the created file
sub getTempFile {
    my $filename;
    do {
        $filename = POSIX::tmpnam();
    } until sysopen(FH, $filename, O_RDWR|O_CREAT|O_EXCL, 0666);

    return ($filename, \*FH);
}


sub helpText {

    print<<"EndOfHelp";
"validate", the Offline HTMLHelp.com Validator, checks the syntax of HTML
documents using an SGML parser and reports any errors.  XHTML documents
may also be validated using an XML parser.

$usage
        
The program's options are as follows:
  -w, --warn            include warnings
  --xml                 indicate that the documents to be validated are XML
                        documents.  Known document types, such as HTML 4.01 and
                        XHTML 1.0, are automatically handled by "validate".
                        For unknown document types, "validate" will assume
                        XHTML/XML if this option is specified and HTML/SGML
                        otherwise.
  --charset=ENCODING    force ENCODING to be used as the character encoding
                        when validating HTML/SGML documents.  This option is
                        ignored when validating XHTML/XML documents, which
                        are assumed to use XML rules for specifying the
                        character encoding.  The following encodings
                        (case-insensitive) are supported: "utf-8",
                        "iso-10646-ucs-2", "euc-jp", "euc-kr", "gb2312",
                        "shift_jis", "big5", and "iso-8859-n" where n is
                        between 1 and 9 inclusive.
  --verbose             turn on verbose output messages
  --[no]emacs           (don't) use an output format intended for parsing
                        by (X)Emacs, autodetected
  -h, --help            display this help and exit
  -v, --version         output version information and exit

Any number of files may be specified after the options.  With no FILE,
standard input is read.

Files can also be URIs if you have the URI and libwww-perl packages
installed.  Support for different URI schemes is also determined by these
packages.  Proxy settings are loaded from environment variables for
each scheme--e.g., http_proxy=http://localhost:3128.

"validate" is written by Liam Quinn <liam\@htmlhelp.com> and is based on the
WDG HTML Validator, an online validation service available at
<http://www.htmlhelp.com/tools/validator/>.
EndOfHelp

}
