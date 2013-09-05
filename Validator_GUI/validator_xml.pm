#***********************************************************************
#
# Name: validator_xml.pm
#
# $Revision: 6321 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_GUI/Tools/validator_xml.pm $
# $Date: 2013-06-26 15:53:16 -0400 (Wed, 26 Jun 2013) $
#
# Description:
#
#   This file contains routines that encode validator GUI messages in
# XML.
#
# Public functions:
#     Validator_XML_TQA_Result
#     Validator_XML_URL_Compliance_Score
#     Validator_XML_Scan_Compliance_Score
#     Validator_XML_URL_Fault_Count
#     Validator_XML_Scan_Fault_Count
#     Validator_XML_HTML_Feature
#     Validator_XML_Start_URL
#     Validator_XML_End_URL
#     Validator_XML_Start_Analysis
#     Validator_XML_End_Analysis
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

package validator_xml;

use strict;
use warnings;

use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Validator_XML_TQA_Result
                  Validator_XML_URL_Compliance_Score
                  Validator_XML_Scan_Compliance_Score
                  Validator_XML_URL_Fault_Count
                  Validator_XML_Scan_Fault_Count
                  Validator_XML_HTML_Feature
                  Validator_XML_Start_URL
                  Validator_XML_End_URL
                  Validator_XML_Start_Analysis
                  Validator_XML_End_Analysis
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($debug) = 0;

my (@package_list) = ("tqa_result_object");

#***********************************************************************
#
# Name: XML_Safe_Encode
#
# Parameters: string - string to encode
#
# Description:
#
#   This function makes a string XML safe by encoding any special
# characters (<, &, >) found within it.
#
# Returns:
#    encoded string
#
#***********************************************************************
sub XML_Safe_Encode {
    my ($string) = @_;
    
    #
    # Replace any & characters with &amp;
    #
    $string =~ s/&/&amp;/g;
    
    #
    # Replace any < characters with &lt;
    #
    $string =~ s/</&lt;/g;

    #
    # Replace any > characters with &gt;
    #
    $string =~ s/>/&gt;/g;

    #
    # Return encoded string
    #
    return($string);
}

#***********************************************************************
#
# Name: Validator_XML_TQA_Result
#
# Parameters: result_type - type of result
#             result_object - tqa_result_object item
#
# Description:
#
#   This function formats the attributes of the tqa_results_object item
# in an XML string.
#
#***********************************************************************
sub Validator_XML_TQA_Result {
    my ($result_type, $result_object) = @_;

    my ($xml_string);

    #
    # Construct XML string for the result object attributes
    #
    print "Validator_XML_TQA_Result\n" if $debug;
    if ( $result_object->line_no != -1 ) {
        $xml_string = "  <qa_result_item type=\"" . $result_type . "\" " .
"testcase=\"" . $result_object->testcase . "\" " .
"line=\"" . $result_object->line_no . "\" " .
"column=\"" . $result_object->column_no . "\" >
    <description>" . XML_Safe_Encode($result_object->description) . "</description>
    <testcase_group>" . XML_Safe_Encode($result_object->testcase_groups) . "</testcase_group>
    <source_line>" . XML_Safe_Encode($result_object->source_line) . "</source_line>
    <message>" . XML_Safe_Encode($result_object->message) . "</message>
  </qa_result_item>
";
        }
        #
        # Print page number, if there is one
        #
        elsif ( $result_object->page_no > 0 ) {
            $xml_string = "  <qa_result_item type=\"" . $result_type . "\" " .
"testcase=\"" . $result_object->testcase . "\" " .
"page=\"" . $result_object->page_no . "\" >
    <description>" . XML_Safe_Encode($result_object->description) . "</description>
    <testcase_group>" . XML_Safe_Encode($result_object->testcase_groups) . "</testcase_group>
    <source_line>" . XML_Safe_Encode($result_object->source_line) . "</source_line>
    <message>" . XML_Safe_Encode($result_object->message) . "</message>
  </qa_result_item>
";
        }

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_URL_Compliance_Score
#
# Parameters: score - compliance score value
#             faults - number of faults
#             url - URL
#
# Description:
#
#   This function formats compliance score values in an XML string.
#
#***********************************************************************
sub Validator_XML_URL_Compliance_Score {
    my ($score, $faults, $url) = @_;

    my ($xml_string);

    #
    # Construct XML string for the compliance score
    #
    print "Validator_XML_URL_Compliance_Score\n" if $debug;
    $xml_string = "<qa_url_compliance_score score=\"$score\" faults=\"$faults\">
</qa_url_compliance_score>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_Scan_Compliance_Score
#
# Parameters: score - compliance score value
#             faults - number of faults
#
# Description:
#
#   This function formats compliance score values in an XML string.
#
#***********************************************************************
sub Validator_XML_Scan_Compliance_Score {
    my ($score, $faults) = @_;

    my ($xml_string);

    #
    # Construct XML string for the compliance score
    #
    print "Validator_XML_Scan_Compliance_Score\n" if $debug;
    $xml_string = "<qa_scan_compliance_score score=\"$score\" faults_per_page=\"$faults\">
</qa_scan_compliance_score>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_URL_Fault_Count
#
# Parameters: faults - number of faults
#             url - URL
#
# Description:
#
#   This function formats fault count values in an XML string.
#
#***********************************************************************
sub Validator_XML_URL_Fault_Count {
    my ($faults, $url) = @_;

    my ($xml_string);

    #
    # Construct XML string for the fault count
    #
    print "Validator_XML_URL_Fault_Count\n" if $debug;
    $xml_string = "<qa_url_fault_count faults=\"$faults\">
</qa_url_fault_count>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_Scan_Fault_Count
#
# Parameters: faults - total fault count value
#             faults_per_page - number of faults per page
#
# Description:
#
#   This function formats fault count values in an XML string.
#
#***********************************************************************
sub Validator_XML_Scan_Fault_Count {
    my ($faults, $faults_per_page) = @_;

    my ($xml_string);

    #
    # Construct XML string for the fault count
    #
    print "Validator_XML_Scan_Fault_Count\n" if $debug;
    $xml_string = "<qa_scan_fault_count faults=\"$faults\" faults_per_page=\"$faults_per_page\">
</qa_scan_fault_count>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_HTML_Feature
#
# Parameters: feature - feature label
#             count - feature instance count
#             url - URL
#
# Description:
#
#   This function formats HTML feature item in an XML string.
#
#***********************************************************************
sub Validator_XML_HTML_Feature {
    my ($feature, $count, $url) = @_;

    my ($xml_string);

    #
    # Construct XML string for the HTML feature
    #
    print "Validator_XML_HTML_Feature\n" if $debug;
    $xml_string = "<qa_html_feature_item feature=\"$feature\" count=\"$count\">
</qa_html_feature_item>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_Start_URL
#
# Parameters: url - URL
#             referrer - referrer URL
#             supporting_file - flag to indicate if URL is supporting
#             count - count of URL
#
# Description:
#
#   This function starts the format of a URL in an XML string.
#
#***********************************************************************
sub Validator_XML_Start_URL {
    my ($url, $referrer, $supporting_file, $count) = @_;

    my ($xml_string);

    #
    # Construct XML string for the URL
    #
    print "Validator_XML_Start_URL\n" if $debug;
    $xml_string = "<qa_url>
  <url>" . XML_Safe_Encode($url) . "</url>
  <url_number>$count</url_number>
  <supporting_file>$supporting_file</supporting_file>";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_End_URL
#
# Parameters: url - URL
#             referrer - referrer URL
#             supporting_file - flag to indicate if URL is supporting
#             count - count of URL
#
# Description:
#
#   This function ends the format of a URL in an XML string.
#
#***********************************************************************
sub Validator_XML_End_URL {
    my ($url, $referrer, $supporting_file, $count) = @_;

    my ($xml_string);

    #
    # Construct XML string for the URL
    #
    print "Validator_XML_End_URL\n" if $debug;
    $xml_string = "</qa_url>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_Start_Analysis
#
# Parameters: date - time/date
#             message - message
#
# Description:
#
#   This function formats the analysis start message in an
# XML string.
#
#***********************************************************************
sub Validator_XML_Start_Analysis {
    my ($date, $message) = @_;

    my ($xml_string);

    #
    # Construct XML string for the analysis start
    #
    print "Validator_XML_Start_Analysis\n" if $debug;
    $xml_string = "<qa_analysis>
<analysis_start_date>$date</analysis_start_date>
";

    #
    # Return the XML string
    #
    return($xml_string);
}

#***********************************************************************
#
# Name: Validator_XML_End_Analysis
#
# Parameters: date - time/date
#             message - message
#
# Description:
#
#   This function formats the analysis end message in an
# XML string.
#
#***********************************************************************
sub Validator_XML_End_Analysis {
    my ($date, $message) = @_;

    my ($xml_string);

    #
    # Construct XML string for the analysis end
    #
    print "Validator_XML_End_Analysis\n" if $debug;
    $xml_string = "
  <analysis_end_date>$date</analysis_end_date>
</qa_analysis>
";

    #
    # Return the XML string
    #
    return($xml_string);
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
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

