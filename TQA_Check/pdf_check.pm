#***********************************************************************
#
# Name:   pdf_check.pm
#
# $Revision: 6647 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/pdf_check.pm $
# $Date: 2014-05-06 11:43:30 -0400 (Tue, 06 May 2014) $
#
# Description:
#
#   This file contains routines that check PDF documents for accessibility.
#
# Public functions:
#     PDF_Check
#     PDF_Check_Debug
#     Set_PDF_Check_Language
#     Set_PDF_Check_Test_Profile
#     Set_PDF_Check_Testcase_Data
#     Set_PDF_Check_Feature_Profile
#     PDF_Check_Features
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

package pdf_check;

use strict;
use File::Basename;
use Image::ExifTool ':Public';
use File::Temp qw/ tempfile tempdir /;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(PDF_Check
                  PDF_Check_Debug
                  Set_PDF_Check_Language
                  Set_PDF_Check_Test_Profile
                  Set_PDF_Check_Testcase_Data
                  Set_PDF_Check_Feature_Profile
                  PDF_Check_Features
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($results_list_addr, $current_url, $pdf_checker_cmnd);
my (%pdf_check_profile_map, $current_testcase_profile, %testcase_data);
my (%pdf_features, %feature_profile_map);

#
# Status values
#
my ($pdf_check_pass)       = 0;
my ($pdf_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "No tags in document",                "No tags in document",
    "No Title property in document",      "No 'Title' property in document",
    "No Language property in document",   "No 'Language' property in document",
    "Missing text in",                    "Missing text in ",
    "Invalid title",                      "Invalid title",
    "Invalid title text value",           "Invalid title text value",
    "No bookmarks in document",           "No bookmarks in document",
    "Missing /Lang entry in document catalog", "Missing /Lang entry in document catalog",
    "No name for form field",             "No 'name' for form field",
    "Missing Alt text in image",          "Missing 'Alt' text in image",
    "No table headers found",             "No table headers found",
    "Page",                               "Page",
    );

my %string_table_fr = (
    "No tags in document",                "Pas de tags dans le document",
    "No Title property in document",      "Aucune propriété 'Title' dans le document",
    "No Language property in document",   "Aucune propriété 'Language' dans le document",
    "Missing text in",                    "Manquantes du texte dans ",
    "Invalid title",                      "Titre invalide",
    "Invalid title text value",           "Valeur de texte titre est invalide",
    "No bookmarks in document",           "fr_No bookmarks in document",
    "Missing /Lang entry in document catalog", "Manquant d'entrée /Lang dans le catalogue de document",
    "No name for form field",             "Pas de nom pour champ de formulaire",
    "Missing Alt text in image",          "Texte 'Alt' manquantes dans l'image",
    "No table headers found",             "Aucune d'en-tête de tableau retrouvée",
    "Page",                               "Page",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: PDF_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub PDF_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set debug flag in supporting modules
    #
    TQA_Result_Object_Debug($this_debug);
    
    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Set_PDF_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_PDF_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: Set_PDF_Check_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_PDF_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_PDF_Check_Test_Profile
#
# Parameters: profile - url check test profile
#             pdf_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_PDF_Check_Test_Profile {
    my ($profile, $pdf_checks ) = @_;

    my (%local_pdf_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_PDF_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_pdf_checks = %$pdf_checks;
    $pdf_check_profile_map{$profile} = \%local_pdf_checks;
}

#***************************************************
#
# Name: Set_PDF_Check_Feature_Profile
#
# Parameters: profile - feature profile
#             features - hash table of feature name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by feature name.
#
#***********************************************************************
sub Set_PDF_Check_Feature_Profile {
    my ($profile, $features) = @_;

    my (%local_features);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_features = %$features;
    $feature_profile_map{$profile} = \%local_features;
}


#**********************************************************************
#
# Name: String_Value
#
# Parameters: key - string table key
#
# Description:
#
#   This function returns the value in the string table for the
# specified key.  If there is no entry in the table an error string
# is returned.
#
#**********************************************************************
sub String_Value {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$string_table{$key}) ) {
        #
        # return value
        #
        return ($$string_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return ("*** No string for $key ***");
    }
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - testcase profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case); 

    #
    # Set current hash tables
    #
    $current_testcase_profile = $pdf_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

    #
    # Initialize global variables
    #
    %pdf_features = ();
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             page - page number
#             text - source line
#             error_string - error message
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $page, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_testcase_profile{$testcase}) )
 {
        #
        # Create result object and save details, set line & column numbers
        # to -1 as we don't have them for PDF files.
        #
        $result_object = tqa_result_object->new($testcase, $pdf_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                -1, -1, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));

        #
        # Set page number of the error
        #
        $result_object->page_no($page);
        push (@$results_list_addr, $result_object);
    }
}

#***********************************************************************
#
# Name: Check_Title_Value
#
# Parameters: this_url - a URL
#             title - title value
#
# Description:
#
# This function checks the value of the title to see if it is an invalid title.
# - See if the title is the same as the URL file name.
# - See if it is the default place holder title value generated
#   by a number of authoring tools.  Invalid titles may include
#   "untitled", "new document", ...
#
#***********************************************************************
sub Check_Title_Value {
    my ( $this_url, $title ) = @_;

    my ($tcid, $invalid_title, $title_text, %properties);
    my ($protocol, $domain, $file_path, $query, $url);
    my ($tc_failed) = 0;

    #
    # Check title value
    #
    print "Check_Title_Value $title\n" if $debug;
    $tcid = "WCAG_2.0-F25";

    #
    # Is the title an empty string ?
    #
    if ( $title eq "" ) {
        Record_Result($tcid, -1, "",
                      String_Value("Missing text in") . "Title");
        $tc_failed = 1;
    }

    #
    # Check for possible invalid values
    #
    if ( (! $tc_failed) && defined($testcase_data{$tcid}) ) {
        #
        # Check for invalid titles from authoring tools.
        #
        foreach $invalid_title (split(/\n/, $testcase_data{$tcid})) {
            #
            # Do we have a match on the invalid title text ?
            #
            if ( $title =~ /^$invalid_title$/i ) {
                Record_Result($tcid, -1, "",
                              String_Value("Invalid title text value") .
                              " '$title'");
                $tc_failed = 1;
                last;
            }
        }
    }

    #
    # Check the title against the URL file name component
    #
    if ( ! $tc_failed ) {
        ($protocol, $domain, $file_path, $query, $url) = URL_Check_Parse_URL($this_url);
        $file_path =~ s/^.*\///g;
        if ( lc($title) eq lc($file_path) ) {
            Record_Result($tcid, -1, "",
                      String_Value("Invalid title") . " '$title'");
        }
    }
}

#***********************************************************************
#
# Name: Check_PDF_Properties
#
# Parameters: this_url - a URL
#             content - PDF content
#
# Description:
#
#   This function extracts PDF properties and information and then
# performs checks on that information.
#
#***********************************************************************
sub Check_PDF_Properties {
    my ( $this_url, $content ) = @_;

    my ($info, $tcid, $invalid_title, $title_text, %properties);
    my ($protocol, $domain, $file_path, $query, $url, $property_status);
    my ($imageinfo_status);

    #
    # Get PDF file properties
    #
    print "Check_PDF_Properties\n" if $debug;
    ($property_status, %properties) = PDF_Files_Get_Properties_From_Content($content);

    #
    # Get PDF file properties and information using ImageInfo routines.
    # We have to get the properties 2 different ways because one technique
    # or the other may fail due to the version of the PDF file.
    #
    $info = ImageInfo(\$content);
    if ( defined($info->{"Error"}) ) {
        $imageinfo_status = 0;
        print "Error property = " . $info->{"Error"} . "\n" if $debug;
    }
    elsif ( defined($info->{"Warning"}) ) {
        $imageinfo_status = 0;
        print "Warning property = " . $info->{"Warning"} . "\n" if $debug;
    }
    else {
        $imageinfo_status = 1;
    }

    #
    # We we able to extract property information ?
    #
    if ( (! $property_status) && (! $imageinfo_status) ) {
        print "Unable to extract property information\n" if $debug;
        return;
    }

    #
    # Are there any tags in the document ? These are needed to determine
    # document semantics.
    #
    if ( defined($$current_testcase_profile{"WCAG_2.0-G115"}) ) {
        #
        # Did we find the "tagged" property using the 
        # PDF_Files_Get_Properties_From_Content routine ?
        # If the value is "no" the document is not tagged.
        #
        if ( $property_status && defined($properties{"Tagged"}) ) {
            print "Have Tagged property = " . $properties{"Tagged"} . "\n" if $debug;
            if ( $properties{"Tagged"} =~ /no/i ) {
                Record_Result("WCAG_2.0-G115", -1, "",
                            String_Value("No tags in document"));
            }
        }
        #
        # Did we find the TaggedPDF property using ImageInfo ?
        # If the value is "no" the document is not tagged.
        #
        elsif ( $imageinfo_status && defined($info->{"TaggedPDF"}) ) {
            print "Have TaggedPDF property = " . $info->{"TaggedPDF"} . "\n" if $debug;
            if ( $info->{"TaggedPDF"} =~ /no/i ) {
                Record_Result("WCAG_2.0-G115", -1, "",
                            String_Value("No tags in document"));
            }
        }
        elsif ( $imageinfo_status || $property_status ) {
            #
            # Have properties from the file but did not
            # find property to indicate tagging.
            #
            print "No tagging property found\n" if $debug;
            Record_Result("WCAG_2.0-G115", -1, "",
                        String_Value("No tags in document"));
        }
    }
}


#***********************************************************************
#
# Name: Run_pdfchecker
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - PDF content
#
# Description:
#
#   This function runs a number of QA checks on PDF content.
#
#***********************************************************************
sub Run_pdfchecker {
    my ($this_url, $language, $profile, $content) = @_;

    my ($is_protected, %image_alt_map, %image_actualtext_map, $title);
    my ($output, $line, $filler, $page_count, $page_number, $fh);
    my ($location, $sublocation, $value, $pdf_file, $title, $num_tables);
    my $is_protected = 0;

    #
    # Create a temporary file for the PDF content.
    #
    print "Run_pdfchecker $this_url\n" if $debug;
    ($fh, $pdf_file) = tempfile( SUFFIX => '.pdf');
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Run_pdfchecker\n";
        return;
    }
    binmode $fh;
    print $fh $content;
    close($fh);

    #
    # Run pdfchecker and capture the output
    #
    print "$pdf_checker_cmnd $pdf_file\n" if $debug;
    $output = `$pdf_checker_cmnd \"$pdf_file\" -r`;
    print "$output\n" if $debug;
    unlink($pdf_file);

    #
    # Parse the output looking for specific lines
    #
    foreach $line (split(/\n/, $output)) {
        if ( $line =~ /^#Pages:/i ) {
            #
            # Get page count
            #
            ($filler, $page_count) = split(/:/, $line);
            print "Page count = $page_count\n" if $debug;
        }

        #
        # Check for protected document
        #
        elsif ( $line =~ /^Document is encrypted/i ) {
            $is_protected = 1;
            print "Document is encrypted\n" if $debug;
        }

        #
        # Check for missing /Alt in images, textcase id
        # EIAO.A.10.1.1.4.PDF.1.1
        # This is part of the PDF1 check, must also check
        # for missing /ActualText, testcase id EIAO.A.10.1.1.4.PDF.2.1
        #
        elsif ( $line =~ /^AWAM-ID: EIAO.A.10.1.1.4.PDF.1.1/i ) {
            #
            # Get location and value
            #
            ($location, $sublocation, $value) = $line =~ /^.*location:\s+\((\d+),\s+(\d+)\)\s+value:\s+(\d+).*$/i;
            print "Missing /Alt on page $location\n" if $debug;

            #
            # Do we have a result for the /ActualText test ?
            #
            if ( defined($image_actualtext_map{"$location:$sublocation"}) ) {
                #
                # Does the image have neither /Alt or /ActualText ?
                #
                if ( ($value == 0) &&
                     ($image_actualtext_map{"$location:$sublocation"} == 0) ) {
                    print "WCAG_2.0-PDF1: Missing Alt text in image on page $location\n" if $debug;
                    Record_Result("WCAG_2.0-PDF1", $location, "",
                                  String_Value("Missing Alt text in image"));
                }
            }
            else {
                #
                # Save status of /Alt check
                #
                $image_alt_map{"$location:$sublocation"} = $value;
            }
        }

        #
        # Check for missing /AltText in images, textcase id
        # EIAO.A.10.1.1.4.PDF.2.1
        # This is part of the PDF1 check, must also check
        # for missing /Alt, testcase id EIAO.A.10.1.1.4.PDF.2.1
        #
        elsif ( $line =~ /^AWAM-ID: EIAO.A.10.1.1.4.PDF.2.1/i ) {
            #
            # Get location and value
            #
            ($location, $sublocation, $value) = $line =~ /^.*location:\s+\((\d+),\s+(\d+)\)\s+value:\s+(\d+).*$/i;
            print "Missing /AltText on page $location\n" if $debug;

            #
            # Do we have a result for the /Alt test ?
            #
            if ( defined($image_alt_map{"$location:$sublocation"}) ) {
                #
                # Does the image have neither /Alt or /ActualText ?
                #
                if ( ($value == 0) &&
                     ($image_alt_map{"$location:$sublocation"} == 0) ) {
                    print "WCAG_2.0-PDF1: Missing Alt text in image on page $location\n" if $debug;
                    Record_Result("WCAG_2.0-PDF1", $location, "",
                                  String_Value("Missing Alt text in image"));
                }
            }
            else {
                #
                # Save status of /Alt check
                #
                $image_actualtext_map{"$location:$sublocation"} = $value;
            }
        }

        #
        # Check for missing bookmarks, textcase id
        # EIAO.A.10.13.3.4.PDF.1.1
        #
        elsif ( $line =~ /^AWAM-ID: EIAO.A.10.13.3.4.PDF.1.1/i ) {
            #
            # Get location and value
            #
            ($location, $value) = $line =~ /^.*location:\s+\((\d+),\s+\d+\)\s+value:\s+(\d+).*$/i;
            print "Missing bookmarks\n" if $debug;

            #
            # Do we have the number of pages and is it over the
            # minimum page threshold ?
            #
            if ( ($value == 0 ) &&
                 (defined($page_count) && ($page_count > 4) )) {
                print "WCAG_2.0-PDF2: No bookmarks\n" if $debug;
                Record_Result("WCAG_2.0-PDF2", -1, "",
                              String_Value("No bookmarks in document"));
            }
        }

        #
        # Check for missing table headers
        #
        elsif ($line =~ /^Table has no headers/i) {
            #
            # Get page number
            #
            ($filler, $page_number) = split(/:/, $line);

            #
            # Is document not password protected ?
            #
            if ( ! $is_protected ) {
                print "WCAG_2.0-PDF6: Table has no headers, page $page_number\n" if $debug;
                Record_Result("WCAG_2.0-PDF6", $page_number, "",
                              String_Value("No table headers found"));
            }
        }

        #
        # Check for missing headings in document
        #
        elsif ( ($line =~ /^No headings found/i) ||
                ($line =~ /^Warning: document has no outlines/i) ) {
            #
            # Is document not password protected ?
            #
            if ( ! $is_protected ) {
                print "WCAG_2.0-PDF9: No headings in document\n" if $debug;
                Record_Result("WCAG_2.0-PDF9", -1, "",
                              String_Value("No headings in document"));
            }
        }

        #
        # Check for missing form field names, testcase id
        # EGOVMON.A.WCAG.PDF.12
        #
        elsif ( $line =~ /^AWAM-ID: EGOVMON.A.WCAG.PDF.12/i ) {
            #
            # Get location and value
            #
            ($location, $value) = $line =~ /^.*location:\s+\((\d+),\s+\d+\)\s+value:\s+(\d+).*$/i;

            if ( $value == 0 ) {
                print "WCAG_2.0-PDF12: No name for form field\n" if $debug;
                Record_Result("WCAG_2.0-PDF12", -1, "",
                              String_Value("No name for form field"));
            }
        }

        #
        # Check for missing document language, testcase id
        # EIAO.A.10.4.1.4.PDF.1.1
        #
        elsif ( $line =~ /^AWAM-ID: EIAO.A.10.4.1.4.PDF.1.1/i ) {
            #
            # Get location and value
            #
            ($location, $value) = $line =~ /^.*location:\s+\((\d+),\s+\d+\)\s+value:\s+(\d+).*$/i;

            if ( $value == 0 ) {
                print "WCAG_2.0-PDF16: Missing /Lang entry in document catalog\n" if $debug;
                Record_Result("WCAG_2.0-PDF16", -1, "",
                              String_Value("Missing /Lang entry in document catalog"));
            }
        }

        #
        # Check for document title
        #
        elsif ( $line =~ /^Title=>/i ) {
            #
            # Save title value
            #
            ($filler, $title) = split(/>/, $line, 2);
            $title =~ s/\r/ /g;
            $title =~ s/\n/ /g;
            $title =~ s/^\s*//g;
            print "Title = $title\n" if $debug;
        }

        #
        # Check for document title, textcase id EIAO.A.15.1.1.4.PDF.1.1
        #
        elsif ( $line =~ /^AWAM-ID: EIAO.A.15.1.1.4.PDF.1.1/i ) {
            #
            # Get location and value
            #
            ($location, $value) = $line =~ /^.*location:\s+\((\d+),\s+\d+\)\s+value:\s+(\d+).*$/i;

            #
            # Did test fail ?
            #
            if ( $value == 0 ) {
                print "WCAG_2.0-PDF18: Missing document title\n" if $debug;
                Record_Result("WCAG_2.0-PDF18", -1, "",
                              String_Value("No Title property in document"));
            }
            #
            # Check for possible invalid titles
            #
            else {
                Check_Title_Value($this_url, $title);
            }
        }

        #
        # Check for missing /S in /Tabs for each page
        #
        #elsif ($line =~ /^\/S not found in \/Tabs on each page/i) {
        #    print "WCAG_2.0-PDF3: /S not found in /Tabs on each page\n";
        #}

        #################################################################
        #
        # Check for PDF document features.
        #
        #################################################################

        #
        # Check for PDF forms
        #
        elsif ( $line =~ /^Has forms: True/i ) {
            $pdf_features{"pdf_form"} = 1;
        }

        #
        # Check for PDF tables
        #
        elsif ( $line =~ /^No of tables =>/i ) {
            #
            # Get number of tables
            #
            ($filler, $num_tables) = split(/>/, $line, 2);

            #
            # Do we have tables ?
            #
            if ( $num_tables > 0 ) {
                $pdf_features{"pdf_table"} = $num_tables;
            }
        }
    }
}

#***********************************************************************
#
# Name: PDF_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - PDF content
#
# Description:
#
#   This function runs a number of QA checks on PDF content.
#
#***********************************************************************
sub PDF_Check {
    my ( $this_url, $language, $profile, $content ) = @_;

    my (@tqa_results_list, $result_object, $testcase);

    #
    # Do we have a valid profile ?
    #
    print "PDF_Check: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($pdf_check_profile_map{$profile}) ) {
        print "PDF_Check: Unknown PDF Check testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Check PDF file properties and information
    #
    Check_PDF_Properties($this_url, $content);

    #
    # Run the pdf checker program
    #
    Run_pdfchecker($this_url, $language, $profile, $content);

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "PDF_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: PDF_Check_Features
#
# Parameters: this_url - a URL
#             profile - feature profile
#             this_feature_line_no - reference to list containing
#               source line numbers
#             this_feature_column_no - reference to list containing
#               source column numbers
#             this_feature_count - reference to hash to contain 
#                feature counts
#             content - PDF content
#
# Description:
#
#   This function parses PDF content looking for a number of 
# features (e.g. forms, tables).
#
#***********************************************************************
sub PDF_Check_Features {
    my ( $this_url, $profile,
         $this_feature_line_no, $this_feature_column_no,
         $this_feature_count, $content ) = @_;

    my ($feature, $current_feature_profile);

    #
    # Do we have a valid profile ?
    #
    print "PDF_Check_Features: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($feature_profile_map{$profile}) ) {
        print "Unknown PDF Feature profile passed $profile\n";
        return;
    }
    $current_feature_profile = $feature_profile_map{$profile};

    #
    # Does this URL match the last one seen ? If so we already
    # have the results.
    #
    if ( $this_url ne $current_url ) {
        #
        # Must analyse content to get features.
        #
    }

    #
    # Copy feature information into the supplied hash tables
    #
    foreach $feature (keys %pdf_features) {
        if ( defined($$current_feature_profile{$feature}) ) {
            #
            # Since we don't know of the location, set it to line 0, column 0.
            #
            $$this_feature_line_no{$feature} = 0;
            $$this_feature_column_no{$feature} = 0;
            $$this_feature_count{$feature} = $pdf_features{$feature};
        }
    }

    #
    # Print out feature counts
    #
    if ( $debug ) {
        print "PDF Features for $this_url\n";
        foreach $feature (keys(%$this_feature_count)) {
            print "  Feature = $feature, count = " .
                  $$this_feature_count{$feature} . "\n";
        }
    }
}

#***********************************************************************
#
# Name: Import_Packages
#
# Parameters: none
#
# Description:
#
#   This function imports any required packages that cannot
# be handled via use statements.
#
#***********************************************************************
sub Import_Packages {

    my ($package);
    my (@package_list) = ("tqa_testcases", "language_map",
                          "tqa_result_object", "pdf_files",
                          "url_check");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        if ( ! defined($INC{$package}) ) {
            require "$package.pm";
        }
        $package->import();
    }
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

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
# Generate path to the pdfchecker command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $pdf_checker_cmnd = "pdfchecker\\pdfchecker.py";
} else {
    #
    # Not Windows.
    #
    $pdf_checker_cmnd = "python $program_dir/pdfchecker/pdfchecker.py 2>\&1";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

