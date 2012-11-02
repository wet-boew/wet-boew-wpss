#!/usr/bin/perl
#!/opt/common/perl/bin/perl
#***********************************************************************
#
# Name:   wpss_tool.pl
#
# $Revision: 6060 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_GUI/Tools/wpss_tool.pl $
# $Date: 2012-10-22 14:57:46 -0400 (Mon, 22 Oct 2012) $
#
# Synopsis: wpss_tool.pl [ -debug ] [ -cgi ] [ -cli ] [ -fra ] [ -content ]
#                        [ -eng ] [ -no_val ] [ -no_link ] [ -no_meta ]
#                        [ -no_acc ] [ -no_clf ] [ -no_cont ] [ -no_feat ]
#                        [ -no_url ] [ -xml ]
#
# Where: -debug enables program debugging.
#        -fra use French interface
#        -eng use English interface
#        -cgi enter CGI mode
#        -cli enter Command Line mode
#        -content enter Content check mode
#        -no_val don't display validation results
#        -no_link don't display link check results
#        -no_meta don't display metadata check results
#        -no_acc don't display accessibility (TQA) check results
#        -no_clf don't display CLF check results
#        -no_cont don't display content check results
#        -no_feat don't display document features results
#        -no_url don't display document list
#        -xml generate XML output
#
# Description:
#
#   This program is a Windows GUI for the WPSS QA tools.  It allows a
# user to analyse an entire site, a list of URLs or paste in HTML code.
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

my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}
use Sys::Hostname;
use LWP::RobotUA;
use File::Basename;
use File::Copy;
use HTTP::Cookies;
use URI::URL;
use Encode;
use POSIX qw(locale_h);
use CGI;
#use Win32::TieRegistry( Delimiter=>"#", ArrayValues=>0 );
use Win32::TieRegistry;
use HTML::Entities;

use strict;

#***********************************************************************
#
# Program global variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f);
my ($url, $report_fails_only, %crawler_config_vars, $save_content);
my ($user_agent, $date_stamp, $this_tab, $lang, %is_valid_markup);
my (%login_form_values, $performed_login, %link_config_vars);
my (@crawler_link_ignore_patterns, %document_count, %error_count);
my (%fault_count, $user_agent_hostname, %url_list, $version);
my (@links, @ui_args, %image_alt_text_table, @web_feed_list);
my (%all_link_sets, %domain_prod_dev_map);
my ($ui_pm_dir) = "GUI";

#
# Shared variables for use between treads
#
my ($shared_image_alt_text_report);
my ($shared_site_dir_e, $shared_site_dir_f);
my ($shared_headings_report);
if ( $have_threads ) {
    share(\$shared_image_alt_text_report);
    share(\$shared_site_dir_e);
    share(\$shared_site_dir_f);
    share(\$shared_headings_report);
}

#
# Content saving variables
#
my ($content_file) = 0;

#
# Results to be displayed
#
my ($display_validation) = 1;
my ($display_link_check) = 1;
my ($display_metadata_check) = 1;
my ($display_tqa_check) = 1;
my ($display_clf_check) = 1;
my ($display_interop_check) = 1;
my ($display_content_check) = 1;
my ($display_doc_features) = 1;
my ($display_document_list) = 1;

#
# URL patterns to be ignored by specific tools
#
my (@tqa_url_skip_patterns) = ();
my (@validation_url_skip_patterns) = ();

#
# Modes for tool
#
my ($cgi_mode) = 0;
my ($cli_mode) = 0;
my ($content_mode) = 0;

my ($debug) = 0;
my ($command_line_debug) = 0;
my ($max_urls_between_sleeps) = 2;
my ($user_agent_name) = "wpss_test.pl";
my ($max_redirects) = 10;

my (%report_options, %results_file_suffixes, %report_options_labels);
my ($crawled_urls_tab, $validation_tab, $metadata_tab, $doc_list_tab,
    $acc_tab, $link_tab, $content_tab, $doc_features_tab,
    $clf_tab, $interop_tab, $crawllimit);

#
# URL language values
#
my ($Unknown_Language) = "";

#
# Tool success/error status
#
my ($tool_success)       = 0;
my ($tool_error)         = 1;
my ($tool_warning)       = 2;

#
# Link check variables
#
my (@link_check_profiles, $link_check_profile, $link_check_profile_label);
my ($link_testcase_url_help_file_name, %link_check_profile_map);

#
# PDF Check Variables
#
my (@pdf_property_profiles, $pdf_property_profile_label);
my (%pdf_property_profile_tag_required_map,
    %pdf_property_profile_content_required_map,
    $pdf_property_profile);

#
# Metadata Check Variables
#
my (@metadata_profiles, $metadata_profile_label);
my (%metadata_profile_tag_required_map,
    %metadata_profile_content_required_map,
    %metadata_profile_content_type_map, 
    %metadata_profile_scheme_values_map,
    %metadata_profile_invalid_content_map,
    $metadata_profile);
my (%metadata_error_url_count, %metadata_error_instance_count);
my (%metadata_help_url, %metadata_results);

#
# Content Check variables
#
my (%content_check_profile_map, $content_check_profile);
my (@content_check_profiles, $content_check_profile_label);
my (%html_titles, %pdf_titles, %title_html_url);
my (%content_error_url_count, %content_error_instance_count);
my ($content_testcase_url_help_file_name);
my (%headings_table, %content_section_markers);

#
# TQA Check variables
#
my (%tqa_check_profile_map, %tqa_testcase_data, %tqa_other_tool_results);
my (@tqa_check_profiles, $tqa_profile_label, $tqa_check_profile);
my (%tqa_error_url_count, %tqa_error_instance_count);
my ($tqa_testcase_url_help_file_name, %site_navigation_links);
my (%decorative_images,%non_decorative_images);
my (@decorative_image_urls, @non_decorative_image_urls);
my (%tqa_testcase_profile_types);
my ($tqa_check_exempted);

#
# CLF Check variables
#
my (%clf_check_profile_map);
my (@clf_check_profiles, $clf_profile_label, $clf_check_profile);
my (%clf_error_url_count, %clf_error_instance_count);
my ($clf_testcase_url_help_file_name, %clf_other_tool_results);
my ($is_archived, %clf_site_links);

#
# Interoperability Check variables
#
my (%interop_check_profile_map);
my (@interop_check_profiles, $interop_profile_label, $interop_check_profile);
my (%interop_error_url_count, %interop_error_instance_count);
my ($interop_testcase_url_help_file_name);

#
# Link Check variables
#
my (%networkscope_map, %domain_alias_map, %link_check_config);
my (@redirect_ignore_patterns, @link_ignore_patterns);
my (%link_error_url_count, %link_error_instance_count);

#
# Document Features variables
#
my (%doc_features_profile_map, %docl_feature_list);
my (@doc_features_profiles, $doc_profile_label, $current_doc_features_profile);
my (%doc_features_metadata_profile_map);

#
# Other configuration items.
#
my (@robots_options, $robots_label);
my (@status_401_options, $status_401_label);
 

#**********************************************************************
#
# Name: Set_Language
#
# Parameters: none
#
# Description:
#
#   This function determines the language to use for messages and
# sets the string table appropriately.  If we are running on a Windows
# workstation, check the registry.  If we are running as a CGI, check
# the language of the referrer URL.
#
#**********************************************************************
sub Set_Language {
    my ($pound, $data, $key, $referrer);

    #
    # Set default language to English in case we cannot determine the
    # workstation language.
    #
    $lang = "eng";
    Set_String_Table_Language($lang);

    #
    # Are we not in cgi mode ?
    #
    if ( ! $cgi_mode ) {
        #
        # If this is a Windows workstation, get the 
        # registry key for language setting of the current user
        #
        if ($^O =~ m/MSWin32/){
            $pound= $Registry->Delimiter("/");
            if ( $key= $Registry->{"HKEY_CURRENT_USER/Control Panel/International/"} ) {

                #
                # Look for the Language item
                #
                if ( $data= $key->{"/sLanguage"} ) {
                    #
                    # Is the value one of the French possibilities ?
                    #
                    if ( $data =~ /^FR/i ) {
                        $lang = "fra";
                        Set_String_Table_Language($lang);
                    }
                }
            }
        }
    }
    else {
        #
        # In CGI mode, get the language from the referrer URL
        #
        $referrer = $ENV{"HTTP_REFERER"};
        if ( defined($referrer) ) {
            if ( URL_Check_GET_URL_Language($referrer) eq "fra" ) {
                $lang = "fra";
                Set_String_Table_Language($lang);
            }
        }
    }
}

#***********************************************************************
#
# Name: Create_User_Agent
#
# Parameters: none
#
# Description:
#
#   This function creates a user agent object to be used in http
# requests.
#
#***********************************************************************
sub Create_User_Agent {

    #
    # Local variables
    #
    my ( $ua, $cookie_jar, $host );

    #
    # Get hostname if one has not been given in configuration
    #
    if ( ! defined($user_agent_hostname) ) {
        $host = hostname;
    }
    else {
        $host = $user_agent_hostname;
    }

    #
    # Setup user agent to handle HTTP requests
    #
    $ua = LWP::RobotUA->new("$user_agent_name", "$user_agent_name\@$host");
    $ua->timeout("60");
    $ua->delay(1/60);

    #
    # Create a temporary cookie jar for the user agent.
    #
    $cookie_jar = HTTP::Cookies->new;
    $ua->cookie_jar( $cookie_jar );

    #
    # Return the user agent
    #
    return $ua;
}

#***********************************************************************
#
# Name: New_HTML_Features_Profile_Hash_Table
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function creates hash tables for html features
# and saves the address of these tables in the global metadata profile
# table.
#
#***********************************************************************
sub New_HTML_Features_Profile_Hash_Table {
    my ($profile_name) = @_;

    my (%profile_table, %metadata_table);

    #
    # Save address of hash tables
    #
    push(@doc_features_profiles, $profile_name);
    $doc_features_profile_map{$profile_name} = \%profile_table;
    $doc_features_metadata_profile_map{$profile_name} = \%metadata_table;

    #
    # Return addresses
    #
    return(\%profile_table, \%metadata_table);
}


#***********************************************************************
#
# Name: Read_HTML_Features_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads the html features configuration file.
#
#***********************************************************************
sub Read_HTML_Features_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $feature_id, $value, $metadata_feature_list);
    my ($feature_list, $html_features_profile_name, $other_profile_name);

    #
    # Check to see that the configuration file exists
    #
    if ( !-f "$config_file" ) {
        print "Error: Missing configuration file\n";
        print " --> $config_file\n";
        exit(1);
    }

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Check for a new profile start tag
        #
        if ( $config_type eq "HTML_Features_Profile_eng" ) {
            #
            # Start of a new document features profile. Get hash tables to
            # store tag ids
            #
            @fields = split(/\s+/, $_, 2);
            $html_features_profile_name = $fields[1];
            ($feature_list, $metadata_feature_list) =
                New_HTML_Features_Profile_Hash_Table($html_features_profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "HTML_Features_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $doc_features_profile_map{$other_profile_name} = $feature_list;
            $doc_features_metadata_profile_map{$other_profile_name} = $metadata_feature_list;
        }
        elsif ( $config_type =~ /html_feature/i ) {
           #
           # document feature id
           #
           @fields = split(/\s+/, $_, 2);
           $feature_id = $fields[1];
           $$feature_list{$feature_id} = $feature_id;
        }
        elsif ( $config_type =~ /metadata/i ) {
           #
           # Metadata content setting, expect <tag> and <expression>
           #
           @fields = split(/\s+/, $_, 3);
           $feature_id = $fields[1];
           $$metadata_feature_list{$feature_id} = $fields[2];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Metadata_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function creates hash tables for metadata attributes
# and saves the address of these tables in the global metadata profile
# table.
#
#***********************************************************************
sub New_Metadata_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%tag_required, %content_required, %content_type, %scheme_values);
    my (%invalid_content);

    #
    # Save address of hash tables
    #
    push(@metadata_profiles, $profile_name);
    $metadata_profile_tag_required_map{$profile_name} = \%tag_required;
    $metadata_profile_content_required_map{$profile_name} = \%content_required;
    $metadata_profile_content_type_map{$profile_name} = \%content_type;
    $metadata_profile_scheme_values_map{$profile_name} = \%scheme_values;
    $metadata_profile_invalid_content_map{$profile_name} = \%invalid_content;

    #
    # Return addresses
    #
    return(\%tag_required, \%content_required, \%content_type, \%scheme_values,
           \%invalid_content);
}

#***********************************************************************
#
# Name: Read_Metadata_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads the metadata configuration file.
#
#***********************************************************************
sub Read_Metadata_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $tag, $value, $tag_required, $content_required);
    my ($content_type, $metadata_profile_name, $scheme_values);
    my ($invalid_content, $thesaurus_language, $scheme, $filename);
    my ($other_profile_name, $url);

    #
    # Check to see that the configuration file exists
    #
    if ( !-f "$config_file" ) {
        print "Error: Missing configuration file\n";
        print " --> $config_file\n";
        exit(1);
    }

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Check for a new profile start tag
        #
        if ( $config_type eq "Metadata_Profile_eng" ) {
            #
            # Start of a new Metadata profile. Get hash tables to
            # store metadata item attributes
            #
            @fields = split(/\s+/, $_, 2);
            $metadata_profile_name = $fields[1];
            ($tag_required, $content_required, $content_type, $scheme_values,
             $invalid_content) =
                New_Metadata_Profile_Hash_Tables($metadata_profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Metadata_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $metadata_profile_tag_required_map{$other_profile_name} = $tag_required;
            $metadata_profile_content_required_map{$other_profile_name} = $content_required;
            $metadata_profile_content_type_map{$other_profile_name} = $content_type;
            $metadata_profile_scheme_values_map{$other_profile_name} = $scheme_values;
            $metadata_profile_invalid_content_map{$other_profile_name} = $invalid_content;
        }
        elsif ( $config_type =~ /help_url_$lang/i ) {
            #
            # Help URL
            #
            $url = $fields[1];
            $metadata_help_url{$metadata_profile_name} = $url;
            $metadata_help_url{$other_profile_name} = $url;
        }
        elsif ( $config_type =~ /required_tag/i ) {
            #
            # Required metadata tag, get tag name and store
            # in hash table.
            #
            $tag = $fields[1];
            $$tag_required{$tag} = 1;
        }
        elsif ( $config_type =~ /content_required/i ) {
            #
            # Required metadata content, get tag name and store
            # in hash table.
            #
            $tag = $fields[1];
            $$content_required{$tag} = 1;
        }
        elsif ( $config_type =~ /content_type/i ) {
            #
            # Metadata content type, get tag & type name and store
            # in hash table.
            #
            $tag = $fields[1];
            $value = $fields[2];
            $$content_type{$tag} = $value;
        }
        elsif ( $config_type =~ /invalid_content/i ) {
            #
            # Invalid metadata content value, get tag & value and store
            # in hash table.
            #
            @fields = split(/\s+/, $_, 3);
            $tag = $fields[1];
            $value = $fields[2];
            if ( defined($$invalid_content{$tag}) ) {
                $$invalid_content{$tag} .= "\n$value";
            }
            else {
                $$invalid_content{$tag} = "$value";
            }
        }
        elsif ( $config_type =~ /scheme/i ) {
            #
            # Metadata scheme values, get tag & values and store
            # in hash table.
            #
            @fields = split(/\s+/,$_,3);
            $tag = $fields[1];
            $value = $fields[2];
            if ( defined($$scheme_values{$tag}) ) {
                $$scheme_values{$tag} .= "$value ";
            }
            else {
                $$scheme_values{$tag} = " $value ";
            }
        }
        elsif ( $config_type =~ /compressed_thesaurus_file/i ) {
            #
            # Metadata content value thesaurus file (compressed)
            #
            @fields = split(/\s+/,$_,4);
            $thesaurus_language = $fields[1];
            $scheme = $fields[2];
            $filename = $fields[3];

            #
            # Read the thesaurus file
            #
            Read_Compressed_Metadata_Thesaurus_File($scheme, $filename, $thesaurus_language);
        }
        elsif ( $config_type =~ /thesaurus_file/i ) {
            #
            # Metadata content value thesaurus file
            #
            @fields = split(/\s+/,$_,4);
            $thesaurus_language = $fields[1];
            $scheme = $fields[2];
            $filename = $fields[3];

            #
            # Read the thesaurus file
            #
            Read_Metadata_Thesaurus_File($scheme, $filename, $thesaurus_language);
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_PDF_Properties_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function creates hash tables for PDF properties attributes
# and saves the address of these tables in the global pdf property profile
# table.
#
#***********************************************************************
sub New_PDF_Properties_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%tag_required, %content_required);

    #
    # Save address of hash tables
    #
    push(@pdf_property_profiles, $profile_name);
    $pdf_property_profile_tag_required_map{$profile_name} = \%tag_required;
    $pdf_property_profile_content_required_map{$profile_name} = \%content_required;

    #
    # Return addresses
    #
    return(\%tag_required, \%content_required);
}

#***********************************************************************
#
# Name: Read_PDF_Property_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads the pdf properties configuration file.
#
#***********************************************************************
sub Read_PDF_Property_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $tag, $value, $tag_required, $content_required);
    my ($profile_name, $other_profile_name);

    #
    # Check to see that the configuration file exists
    #
    if ( !-f "$config_file" ) {
        print "Error: Missing configuration file\n";
        print " --> $config_file\n";
        exit(1);
    }

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Check for a new profile start tag
        #
        if ( $config_type eq "Property_Profile_eng" ) {
            #
            # Start of a new PDF properties profile. Get hash tables to
            # store property item attributes
            #
            @fields = split(/\s+/, $_, 2);
            $profile_name = $fields[1];
            ($tag_required, $content_required) =
                New_PDF_Properties_Profile_Hash_Tables($profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Property_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $pdf_property_profile_tag_required_map{$other_profile_name} = $tag_required;
            $pdf_property_profile_content_required_map{$other_profile_name} = $content_required;
        }
        elsif ( $config_type =~ /required_property/i ) {
           #
           # Required property name, get name and store
           # in hash table.
           #
           $tag = $fields[1];
           $$tag_required{$tag} = 1;
        }
        elsif ( $config_type =~ /content_required/i ) {
           #
           # Required property content, get tag name and store
           # in hash table.
           #
           $tag = $fields[1];
           $$content_required{$tag} = 1;
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_TQA_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for TQA Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_TQA_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@tqa_check_profiles, $profile_name);
    $tqa_check_profile_map{$profile_name} = \%testcases;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_TQA_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a TQA Check configuration file.
#
#***********************************************************************
sub Read_TQA_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($tqa_check_profile_name, $profile_type, $other_profile_name);
    my (@profile_names, $exemption_type, $exemption_value);

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Start of a new TQA testcase profile. Get hash tables to
        # store TQA Check attributes
        #
        if ( $config_type eq "TQA_Check_Profile_eng" ) {
            #
            # Start of a new TQA testcase profile. Get hash tables to
            # store TQA Check attributes
            #
            @fields = split(/\s+/, $_, 2);
            $tqa_check_profile_name = $fields[1];
            ($testcases) =
                New_TQA_Check_Profile_Hash_Tables($tqa_check_profile_name);
            @profile_names = ($tqa_check_profile_name);
        }
        elsif ( $config_type =~ /TQA_Check_Profile_Type/i ) {
            #
            # Profile type value.
            #
            if ( defined($tqa_check_profile_name) ) {
                $profile_type = $fields[1];
                foreach $other_profile_name (@profile_names) {
                    $tqa_testcase_profile_types{$other_profile_name} = $profile_type;
                }
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "TQA_Check_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( ! defined($tqa_check_profile_map{$other_profile_name}) ) {
                $tqa_check_profile_map{$other_profile_name} = $testcases;
                push(@profile_names, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required TQA testcase, get testcase id and store
            # in hash table.
            #
            $testcase_id = $fields[1];
            if ( defined($testcase_id) ) {
                $$testcases{$testcase_id} = 1;
            }
        }
        elsif ( $config_type =~ /testcase_data/i ) {
            #
            # Split line again to get everything after the testcase
            # id as a single field
            #
            ($config_type, $testcase_id, $value) = split(/\s+/, $_, 3);

            #
            # Testcase specific data, get testcase id and data to
            # store in hash table.
            #
            if ( defined($tqa_testcase_data{$testcase_id}) ) {
                $tqa_testcase_data{$testcase_id} .= "\n" . $value;
            }
            else {
                $tqa_testcase_data{$testcase_id} = $value;
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $tqa_testcase_url_help_file_name = $fields[1];
        }
        elsif ( $config_type =~ /TQA_EXEMPTION/i ) {
            #
            # A TQA check exemption condition
            #
            ($config_type, $exemption_type, $exemption_value) = split(/\s+/, $_, 3);
            TQA_Check_Set_Exemption_Markers($exemption_type, $exemption_value);
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_CLF_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for CLF Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_CLF_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@clf_check_profiles, $profile_name);
    $clf_check_profile_map{$profile_name} = \%testcases;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_CLF_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a CLF Check configuration file.
#
#***********************************************************************
sub Read_CLF_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($clf_check_profile_name, $other_profile_name, $archived_type);
    my ($archived_value);

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Start of a new CLF testcase profile. Get hash tables to
        # store CLF Check attributes
        #
        if ( $config_type eq "CLF_Check_Profile_eng" ) {
            #
            # Start of a new CLF testcase profile. Get hash tables to
            # store CLF Check attributes
            #
            @fields = split(/\s+/, $_, 2);
            $clf_check_profile_name = $fields[1];
            ($testcases) =
                New_CLF_Check_Profile_Hash_Tables($clf_check_profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "CLF_Check_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $clf_check_profile_map{$other_profile_name} = $testcases;

        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required CLF testcase, get testcase id and store
            # in hash table.
            #
            $testcase_id = $fields[1];
            if ( defined($testcase_id) ) {
                $$testcases{$testcase_id} = 1;
            }
        }
        elsif ( $config_type =~ /testcase_data/i ) {
            #
            # Split line again to get everything after the testcase
            # id as a single field
            #
            ($config_type, $testcase_id, $value) = split(/\s+/, $_, 3);

            #
            # Testcase specific data
            #
            if ( defined($clf_check_profile_name) && defined($value) ) {
                Set_CLF_Check_Testcase_Data($testcase_id, $value);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $clf_testcase_url_help_file_name = $fields[1];
        }
        elsif ( $config_type =~ /ARCHIVED/i ) {
            #
            # An archived on the web marker. Get type and value.
            #
            ($config_type, $archived_type, $archived_value) = split(/\s+/, $_, 3);
            if ( defined($clf_check_profile_name) &&
                 defined($archived_value) ) {
                CLF_Check_Set_Archive_Markers($clf_check_profile_name,
                                              $archived_type, $archived_value);
            }
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Link_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Link Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_Link_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@link_check_profiles, $profile_name);
    $link_check_profile_map{$profile_name} = \%testcases;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_Link_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Link Check configuration file.
#
#***********************************************************************
sub Read_Link_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($link_check_profile_name, $other_profile_name, $archived_type);
    my ($archived_value);

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Start of a new Link testcase profile. Get hash tables to
        # store Link Check attributes
        #
        if ( $config_type eq "Link_Check_Profile_eng" ) {
            #
            # Start of a new Link testcase profile. Get hash tables to
            # store Link Check attributes
            #
            @fields = split(/\s+/, $_, 2);
            $link_check_profile_name = $fields[1];
            ($testcases) =
                New_Link_Check_Profile_Hash_Tables($link_check_profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Link_Check_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $link_check_profile_map{$other_profile_name} = $testcases;

        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required Link testcase, get testcase id and store
            # in hash table.
            #
            $testcase_id = $fields[1];
            if ( defined($testcase_id) ) {
                $$testcases{$testcase_id} = 1;
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $link_testcase_url_help_file_name = $fields[1];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Interop_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Interoperability Check test cases
# and saves the address in the global test case profile table.
#
#***********************************************************************
sub New_Interop_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@interop_check_profiles, $profile_name);
    $interop_check_profile_map{$profile_name} = \%testcases;

    #
    # Return addresses
    #
    return(\%testcases);
}


#***********************************************************************
#
# Name: Read_Interop_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Interoperability Check configuration file.
#
#***********************************************************************
sub Read_Interop_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($interop_check_profile_name, $other_profile_name);

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Start of a new Interoperability testcase profile. Get hash tables to
        # store Interoperability Check attributes
        #
        if ( $config_type eq "Interop_Check_Profile_eng" ) {
            #
            # Start of a new Interoperability testcase profile. Get hash tables to
            # store Interoperability Check attributes
            #
            @fields = split(/\s+/, $_, 2);
            $interop_check_profile_name = $fields[1];
            ($testcases) =
                New_Interop_Check_Profile_Hash_Tables($interop_check_profile_name);
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Interop_Check_Profile_" ) {
            #
            # Match this profile name to the current English profile.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            $interop_check_profile_map{$other_profile_name} = $testcases;

        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required Interoperability testcase, get testcase id and store
            # in hash table.
            #
            $testcase_id = $fields[1];
            if ( defined($testcase_id) ) {
                $$testcases{$testcase_id} = 1;
            }
        }
        elsif ( $config_type =~ /testcase_data/i ) {
            #
            # Split line again to get everything after the testcase
            # id as a single field
            #
            ($config_type, $testcase_id, $value) = split(/\s+/, $_, 3);

            #
            # Testcase specific data
            #
            if ( defined($interop_check_profile_name) && defined($value) ) {
                Set_Interop_Check_Testcase_Data($testcase_id, $value);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $interop_testcase_url_help_file_name = $fields[1];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Content_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Content Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_Content_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@content_check_profiles, $profile_name);
    $content_check_profile_map{$profile_name} = \%testcases;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_Content_Section_Value
#
# Parameters: line - configuration file input line
#             list_addr - list address
#
# Description:
#
#   This function reads a Content section value marker from the
# specified line and adds it to a list.
#
#***********************************************************************
sub Read_Content_Section_Value {
    my ($line, $list_addr) = @_;
    
    my ($config_type, $value);
    
    #
    # Split line on white space, we want everything after the first
    # whitespace.
    #
    ($config_type, $value) = split(/\s+/, $line, 2);

    #
    # Remove leading & trailing white space from value
    #
    if ( defined($value) ) {
        $value =~ s/^\s*//g;
        $value =~ s/\s*$//g;

        #
        # Add value to list
        #
        if ( $value ne "" ) {
            push (@$list_addr, $value);
        }
    }
}

#***********************************************************************
#
# Name: Read_Content_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Content Check configuration file.
#
#***********************************************************************
sub Read_Content_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $testcases);
    my ($content_check_profile_name, $comment, $class_name);
    my ($in_content_marker_section) = 0;
    
    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Start of a new Content testcase profile. Get hash tables to
        # store Content Check attributes
        #
        if ( $config_type eq "Content_Check_Profile_" . $lang ) {
            #
            # Start of a new Content testcase profile. Get hash tables to
            # store Content Check attributes
            #
            @fields = split(/\s+/, $_, 2);
            $content_check_profile_name = $fields[1];
            ($testcases) =
                New_Content_Check_Profile_Hash_Tables($content_check_profile_name);
        }
        elsif ( $config_type =~ /tcid/i ) {
           #
           # Required Content testcase, get testcase id and store
           # in hash table.
           #
           $testcase_id = $fields[1];
           if ( defined($testcase_id) ) {
               $$testcases{$testcase_id} = 1;
           }
        }
        elsif ( $config_type =~ /CONTENT_SECTION_START/i ) {
            #
            # Start of content marker section
            #
            $in_content_marker_section = 1;
        }
        elsif ( $config_type =~ /CONTENT_SECTION_END/i ) {
            #
            # End of content marker section
            #
            $in_content_marker_section = 0;
        }
        elsif ( $in_content_marker_section ) {
            #
            # A content section marker
            #
            @fields = split(/\s+/, $_, 3);
            if ( @fields == 3 ) {
                Content_Section_Markers($fields[0], $fields[1], $fields[2]);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $content_testcase_url_help_file_name = $fields[1];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: Read_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a configuration file.
#
#***********************************************************************
sub Read_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type);

    #
    # Check to see that the configuration file exists
    #
    if ( !-f "$config_file" ) {
        print "Error: Missing configuration file\n";
        print " --> $config_file\n";
        exit(1);
    }
    
    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Check for crawler link ignore patterns
        #
        if ( $config_type eq "Crawler_Link_Ignore_Pattern" ) {
            #
            # Save pattern
            #
            if ( @fields > 1 ) {
                push(@crawler_link_ignore_patterns, $fields[1]);
            }
        }
        #
        # Check configuration variable type
        #
        elsif ( $config_type eq "Domain_Alias" ) {
            #
            # Save domain and its alias
            #
            if ( @fields > 2 ) {
                $domain_alias_map{$fields[2]} = $fields[1];
            }
        }
        elsif ( $config_type eq "Domain_Prod_Dev" ) {
            #
            # Save production and development domains
            #
            if ( @fields > 2 ) {
                $domain_prod_dev_map{$fields[1]} = $fields[2];
            }
        }
        elsif ( $config_type eq "Domain_Networkscope" ) {
            #
            # Save domain and its networkscope
            #
            if ( @fields > 2 ) {
                $networkscope_map{$fields[1]} = $fields[2];
            }
        }
        #
        # Check for firewall pattern
        #
        elsif ( $config_type eq "Firewall_Block_Pattern" ) {
            #
            # Save pattern
            #
            if ( @fields > 1 ) {
                $link_config_vars{$config_type} = $fields[1];
            }
        }

        elsif ( $config_type eq "Link_Ignore_Pattern" ) {
            #
            # Save pattern
            #
            if ( @fields > 1 ) {
                push(@link_ignore_patterns, $fields[1]);
            }
        }
        elsif ( $config_type eq "Redirect_Ignore_Pattern" ) {
            #
            # Save value
            #
            if ( @fields > 1 ) {
                push(@redirect_ignore_patterns, $fields[1]);
            }
        }
        elsif ( $config_type eq "User_Agent_Hostname" ) {
            #
            # Save value
            #
            if ( @fields > 1 ) {
                $user_agent_hostname = $fields[1];
                $crawler_config_vars{"user_agent_hostname"} = $user_agent_hostname;
            }
        }
        elsif ( $config_type eq "User_Agent_Max_Size" ) {
            #
            # Save value
            #
            $crawler_config_vars{"user_agent_max_size"} = $fields[1];
        }
        elsif ( $config_type eq "User_Agent_Name" ) {
            #
            # Save value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $user_agent_name = $fields[1];
                $crawler_config_vars{"user_agent_name"} = $user_agent_name;
            }
        }
        elsif ( $config_type =~ /Validation_Ignore_Pattern/i ) {
            #
            # Pattern of URLs to skip for validation
            #
            @fields = split(/\s+/, $_, 2);
            push(@validation_url_skip_patterns, $fields[1]);
        }
        elsif ( $config_type =~ /TQA_CHECK_Ignore_Pattern/i ) {
            #
            # Pattern of URLs to skip for TQA Check testing
            #
            @fields = split(/\s+/, $_, 2);
            push(@tqa_url_skip_patterns, $fields[1]);
        }
        elsif ( $config_type =~ /Non_Decorative_Image_URL/i ) {
            #
            # List of non-decorative image URLs
            #
            @fields = split(/\s+/, $_, 2);
            push(@non_decorative_image_urls, $fields[1]);
        }
        elsif ( $config_type =~ /Decorative_Image_URL/i ) {
            #
            # List of decorative image URLs
            #
            @fields = split(/\s+/, $_, 2);
            push(@decorative_image_urls, $fields[1]);
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: Set_Package_Debug_Flags
#
# Parameters: none
#
# Description:
#
#   This function sets the debug flag of supporting packages.
#
#***********************************************************************
sub Set_Package_Debug_Flags {

    #
    # Set package debug flags.
    #
    Validator_GUI_Debug($debug);
    Set_Content_Check_Debug($debug);
    Set_Crawler_Debug($debug);
    Set_Metadata_Debug($debug);
    Set_TQA_Check_Debug($debug);
    Link_Checker_Debug($debug);
    Extract_Links_Debug($debug);
    HTML_Features_Debug($debug);
    TextCat_Debug($debug);
    Alt_Text_Check_Debug($debug);
    Content_Section_Debug($debug);
    Set_CLF_Check_Debug($debug);
    Validate_Markup_Debug($debug);
    PDF_Files_Debug($debug);
    Set_Interop_Check_Debug($debug);
}

#***********************************************************************
#
# Name: Check_Debug_File
#
# Parameters: none
#
# Description:
#
#   This function checks for a debug file to enable or disable
# debugging file the program is running.
#
#***********************************************************************
sub Check_Debug_File {

    #
    # Only check if we did not have a command line debug option
    #
    if ( ! $command_line_debug ) {
        #
        # Do we have the debug file ? If so turn on debugging
        # and redirect stdout & stderr to files.
        #
        if ( -f "$program_dir/debug.txt" ) {
            $debug = 1;
            unlink("$program_dir/stderr.txt");
            open( STDERR, ">$program_dir/stderr.txt");
            unlink("$program_dir/stdout.txt");
            open( STDOUT, ">$program_dir/stdout.txt");
        }
        else {
            $debug = 0;
        }
        
        #
        # Set debug flag in supporting packages
        #
        Set_Package_Debug_Flags();
    }
}

#***********************************************************************
#
# Name: Initialize
#
# Parameters: none
#
# Description:
#
#   This function does program initialization. It
#  - verifies that needed files & directories exist.
#
#***********************************************************************
sub Initialize {

    my ($package, $host);
    my (@package_list) = ("extract_links", "crawler", 
                          "textcat", "metadata", "tqa_check", "pdf_files",
                          "link_checker", "html_features", "html_validate",
                          "css_validate", "robots_check", "content_check",
                          "javascript_validate", "wpss_strings", "css_check",
                          "alt_text_check", "tqa_result_object", "url_check",
                          "tqa_testcases", "content_sections", "clf_check",
                          "metadata_result_object", "validate_markup",
                          "interop_check", "pdf_check");
    my ($mday, $mon, $year, $key, $value, $metadata_profile);
    my ($tag_required, $content_required, $content_type, $scheme_values);
    my ($invalid_content, $pdf_profile);

    #
    # Remove any possible debug flag file
    #
    chdir($program_dir);
    unlink("$program_dir/debug.txt");
    
    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    push @INC, "$program_dir/lib";
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        print "require $package.pm\n" if ($debug && (! $cgi_mode));
        require "$package.pm";
        $package->import();
    }

    #
    # Import appropriate UI layer (GUI, CLI, HTML, ...)
    #
    push @INC, "$program_dir/lib/$ui_pm_dir";
    require "validator_gui.pm";
    validator_gui->import();

    #
    # Get the language for the display
    #
    if ( ! defined($lang) ) {
        Set_Language();
    }
    else {
        Set_String_Table_Language($lang);
    }

    #
    # Set package debug flags.
    #
    Set_Package_Debug_Flags();

    #
    # Read program configuration files
    #
    Read_Config_File("$program_dir/conf/wpss_tool.config");
    Read_Link_Check_Config_File("$program_dir/conf/so_link_check.config");
    Read_Metadata_Config_File("$program_dir/conf/so_metadata_check.config");
    Read_PDF_Property_Config_File("$program_dir/conf/so_pdf_check.config");
    Read_TQA_Check_Config_File("$program_dir/conf/so_tqa_check.config");
    Read_HTML_Features_Config_File("$program_dir/conf/so_html_features.config");
    Read_Content_Check_Config_File("$program_dir/conf/so_content_check.config");
    Read_CLF_Check_Config_File("$program_dir/conf/so_clf_check.config");
    Read_Interop_Check_Config_File("$program_dir/conf/so_interop_check.config");

    #
    # Set testcase/url help information
    #
    if ( defined($tqa_testcase_url_help_file_name) ) {
        TQA_Testcase_Read_URL_Help_File($tqa_testcase_url_help_file_name);
    }
    if ( defined($content_testcase_url_help_file_name) ) {
        Content_Check_Read_URL_Help_File($content_testcase_url_help_file_name);
    }
    if ( defined($clf_testcase_url_help_file_name) ) {
        CLF_Check_Read_URL_Help_File($clf_testcase_url_help_file_name);
    }
    if ( defined($interop_testcase_url_help_file_name) ) {
        Interop_Check_Read_URL_Help_File($interop_testcase_url_help_file_name);
    }

    #
    # Set Content Check testcase profiles and other configuration
    #
    while ( ($key,$value) =  each %content_check_profile_map) {
        Set_Content_Check_Test_Profile($key, $value);
    }

    #
    # Set message language.
    #
    Set_Content_Check_Language($lang);
    Set_TQA_Check_Language($lang);
    Alt_Text_Check_Language($lang);
    Set_Link_Checker_Language($lang);
    Set_CLF_Check_Language($lang);
    Metadata_Check_Language($lang);
    PDF_Files_Language($lang);
    Validate_Markup_Language($lang);
    Set_Interop_Check_Language($lang);

    #
    # Set Link Checker configuration variables
    #
    Link_Checker_Config(%link_config_vars);

    #
    # Set TQA Check testcase profiles
    #
    while ( ($key,$value) = each %tqa_check_profile_map) {
        Set_TQA_Check_Test_Profile($key, $value);
    }

    #
    # Set Link Check testcase profiles
    #
    while ( ($key,$value) = each %link_check_profile_map) {
        Set_Link_Check_Test_Profile($key, $value);
    }

    #
    # Set TQA Profile types
    #
    TQA_Check_Profile_Types(%tqa_testcase_profile_types);

    #
    # Set testcase data
    #
    while ( ($key,$value) = each %tqa_testcase_data) {
        Set_TQA_Check_Testcase_Data($key, $value);
    }

    #
    # Set CLF Check testcase profiles
    #
    while ( ($key,$value) = each %clf_check_profile_map) {
        Set_CLF_Check_Test_Profile($key, $value);
    }

    #
    # Set Interoperability Check testcase profiles
    #
    while ( ($key,$value) = each %interop_check_profile_map) {
        Set_Interop_Check_Test_Profile($key, $value);
    }
    
    #
    # Set required metadata tags, metadata content and content type for
    # each metadata profile.
    #
    foreach $metadata_profile (@metadata_profiles) {
        $tag_required = $metadata_profile_tag_required_map{$metadata_profile};
        $content_required = $metadata_profile_content_required_map{$metadata_profile};
        $content_type = $metadata_profile_content_type_map{$metadata_profile};
        $scheme_values = $metadata_profile_scheme_values_map{$metadata_profile};
        $invalid_content = $metadata_profile_invalid_content_map{$metadata_profile};

        Set_Required_Metadata_Tags($metadata_profile, %$tag_required);
        Set_Required_Metadata_Content($metadata_profile, %$content_required);
        Set_Metadata_Content_Type($metadata_profile, %$content_type);
        Set_Metadata_Scheme_Value($metadata_profile, %$scheme_values);
        Set_Invalid_Metadata_Content($metadata_profile, %$invalid_content);
    }

    #
    # Set required PDF properties and properties content for
    # each PDF profile.
    #
    foreach $pdf_profile (@pdf_property_profiles) {
        $tag_required = $pdf_property_profile_tag_required_map{$pdf_profile};
        $content_required = $pdf_property_profile_content_required_map{$pdf_profile};

        Set_Required_PDF_File_Properties($pdf_profile, %$tag_required);
        Set_Required_PDF_Property_Content($pdf_profile, %$content_required);
    }

    #
    # Set feature profiles
    #
    while ( ($key,$value) =  each %doc_features_profile_map) {
        Set_HTML_Feature_Profile($key, $value);
        Set_HTML_Feature_Metadata_Profile($key, $doc_features_metadata_profile_map{$key});
        Set_PDF_Check_Feature_Profile($key, $value);
    }

    #
    # Set Javascript Validator profile & configuration file.
    #
    JavaScript_Validate_JSL_Config("error", "conf/jsl_error_config.txt");

    #
    # Configure the crawler package
    #
    Crawler_Config(%crawler_config_vars);
    Set_Crawler_Domain_Alias_Map(%domain_alias_map);
    Set_Crawler_Domain_Prod_Dev_Map(%domain_prod_dev_map);
    Set_Crawler_HTTP_Response_Callback(\&HTTP_Response_Callback);
    Set_Crawler_HTTP_401_Callback(\&HTTP_401_Callback);
    Set_Crawler_URL_Ignore_Patterns(@crawler_link_ignore_patterns);

    #
    # Configure the Link Checker package
    #
    Set_Link_Checker_Domain_Networkscope_Map(%networkscope_map);
    Set_Link_Checker_Domain_Alias_Map(%domain_alias_map);
    Set_Link_Checker_Redirect_Ignore_Patterns(@redirect_ignore_patterns);
    
    #
    # Create user agent
    #
    $user_agent = Create_User_Agent;

    #
    # Get current time
    #
    ( $mday, $mon, $year ) = ( localtime(time) )[ 3, 4, 5 ];

    #
    # Get full year number (not just offset from 1900).
    #
    $year = 1900 + $year;

    #
    # Adjust the month from 0 based (ie. Jan = 0) to 1 based (ie. Jan = 1).
    #
    $mon++;

    #
    # Get string values for date YYYY-MM-DD format
    #
    $date_stamp = sprintf( "%d-%02d-%02d", $year, $mon, $mday );

    #
    # Make sure we have a profiles and results directory
    #
    if ( ! -d "$program_dir/profiles" ) {
        mkdir("$program_dir/profiles", 0755);
    }
    if ( ! -d "$program_dir/results" ) {
        mkdir("$program_dir/results", 0755);
    }

    #
    # Read version file to get program version
    #
    if ( "$program_dir/version.txt" ) {
        open(VERSION, "$program_dir/version.txt");
        $version = <VERSION>;
        chomp($version);
        close(VERSION);
    }
}

#***********************************************************************
#
# Name: HTTP_401_Callback
#
# Parameters: url - document URL
#             realm - the text displayed in the login prompt
#
# Description:
#
#   This function is a callback function used by the crawling package.
# It is called whenever a 401 (Not Authorized) code is received.  This
# function calls on the validator GUI to open a login window to get
# the username & password for URL.
#
#***********************************************************************
sub HTTP_401_Callback {
    my ($url, $realm) = @_;

    my ($user, $password);

    #
    # Open 401 login form
    #
    ($user, $password) = Validator_GUI_401_Login($url, $realm);

    #
    # Return username & password
    #
    print "HTTP_401_Callback return user $user\n" if $debug;
    return($user, $password);
}

#***********************************************************************
#
# Name: Login_Callback
#
# Parameters: url is the document URL
#             form is a HTML::Form object
#
# Description:
#
#   This function is a callback function from the crawler to handle
# site login.  It calls on the validator GUI to open a login dialog
# to get the login credentials.  This then copies the results into the
# login form which the crawler uses to perform the site login.
#
#***********************************************************************
sub Login_Callback {
    my($url, $form) = @_;

    my (@inputs, $this_input, %login_fields, $this_value);

    #
    # Have we already done the login before
    #
    print "Login callback\n" if $debug;
    if ( ! $performed_login ) {
        #
        # Get all the form fields that are either text or password
        #
        @inputs = $form->inputs;
        foreach $this_input (@inputs) {
            #
            # Check input type
            #
            if ( $debug ) {
                print "Login form input ";
                if ( defined($this_input->name) ) {
                    print $this_input->name;
                }
                else {
                    print "UNKNOWN";
                }
                if ( defined($this_input->type) ) {
                    print " type " . $this_input->type;
                }
                print "\n";
            }
            if ( ( ! ($this_input->readonly) ) && 
                 (
                   ($this_input->type eq "text") ||
                   ($this_input->type eq "password")
                 ) ) {
                $login_fields{$this_input->name} = $this_input->type;
            }
        }    

        #
        # Call on the validator GUI to present the login form
        #
        %login_form_values = Validator_GUI_Login(%login_fields);
        $performed_login = 1;
    }

    #
    # Set login form values
    #
    while ( ($this_input, $this_value) = each %login_form_values ) {
        print "Set form value for $this_input to \"$this_value\"\n" if $debug;
        $form->value($this_input, $this_value);
    }
}

#***********************************************************************
#
# Name: HTTP_Response_Callback
#
# Parameters: url - document URL
#             referrer - referrer url
#             mime_type - document mime type
#             resp - document HTTP::Response object
#
# Description:
#
#   This function is a callback function used by the crawling package.
# It is called for each unique URL found within the site.
# The document mime type is checked to see that it is text/html, if
# so then a HTML validation and link check is performed with the content.
#
#***********************************************************************
sub HTTP_Response_Callback {
    my ($url, $referrer, $mime_type, $resp) = @_;

    my ($charset, $content, $url_line, $language, $key, $list_ref);
    my ($supporting_file) = 0;

    #
    # Check for debug flag file
    #
    Check_Debug_File();

    #
    # Initialize markup validity flags and other tool results
    #
    print "HTTP_Response_Callback url = $url, mime-type = $mime_type\n" if $debug;
    %is_valid_markup = ();
    %tqa_other_tool_results = ();
    %clf_other_tool_results = ();
    $is_archived = 0;
    
    #
    # Add URL to list of URLs
    #
    $url_list{$url} = $mime_type;

    #
    # Check for UTF-8 content
    #
    $content = Crawler_Decode_Content($resp);

    #
    # Do we have any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Set referrer and increment document count
        #
        if ( ! defined($referrer) ) {
            $referrer = "";
        }
        $document_count{$crawled_urls_tab}++;

        #
        # Print URL with referrer
        #
        Validator_GUI_Start_URL($crawled_urls_tab, $url, $referrer,
                                $supporting_file,
                                $document_count{$crawled_urls_tab});

#
# CGI Mode
#
#$url_line = $document_count{$crawled_urls_tab} . ":  <a href=\"$url\">$url</a>";
#Validator_GUI_Update_Results($crawled_urls_tab, $url_line);

        #
        # Save content in a local file
        #
        Save_Content_To_File($url, $mime_type, $content);

        #
        # Do we have text mime type ? Perform content type specific
        # checks.
        #
        if ( $mime_type =~ /text\// ) {
            #
            # Get the character set encoding, if any, that is specified in the
            # response header.
            #
            $charset = $resp->header('Content-Type');
            if ( $charset =~ /charset=/i ) {
                $charset =~ s/^.*charset=//g;
                $charset =~ s/,.*//g;
                $charset =~ s/ .*//g;
                $charset =~ s/\s+//g;
                $charset =~ s/\n//g;

                #
                # Create validator command line option to specify character set
                #
                $charset = "--charset=$charset";
            }
            else {
                $charset = "";
            }

            #
            # Is the content is HTML?
            #
            if ( $mime_type =~ /text\/html/ ) {

                #
                # Is this URL flagged as "Archived on the Web" ?
                #
                $is_archived = CLF_Check_Is_Archived($clf_check_profile, $url, $content);
            }
        }

        #
        # Determine TQA Check exemption status
        #
        $tqa_check_exempted = TQA_Check_Exempt($url, $mime_type, $is_archived, 
                                               $content, \%url_list);

        #
        # Are we tracking TQA Exempt as an document feature ?
        #
        if ( ($tqa_check_exempted) && ( ! ($mime_type =~ /text\/html/) ) ) {
            #
            # Save "Alternate Format" feature (if the document is exempt from
            # TQA it must be an alternate format)
            #
            $key = "alternate/autre format";
            if ( defined($docl_feature_list{$key}) ) {
                $list_ref = $docl_feature_list{$key};
                print "Add to document feature list $key, url = $url\n" if $debug;
                $$list_ref{$url} = 1;
            }
        }

        #
        # Validate the content
        #
        Perform_Markup_Validation($url, $mime_type, $charset, $content);

        #
        # If the file is HTML content, validate it and perform a link check.
        #
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Get document language
            #
            $language = HTML_Document_Language($url, $content);

            #
            # Display content in browser window
            #
            Validator_GUI_Display_Content($url, $content);

            #
            # Perform Link check
            #
            Perform_Link_Check($url, $mime_type, $resp);

            #
            # Perform Metadata Check
            #
            Perform_Metadata_Check($url, $content, $language);

            #
            # Perform TQA check
            #
            Perform_TQA_Check($url, $content, $language, $mime_type, $resp);

            #
            # Perform CLF check
            #
            Perform_CLF_Check($url, $content, $language, $mime_type, $resp);
            
            #
            # Perform Interoperability check
            #
            Perform_Interop_Check($url, $content, $language, $mime_type, $resp);

            #
            # Perform feature check
            #
            Perform_Feature_Check($url, $mime_type, $content);
        }

        #
        # Do we have application/pdf mime type ?
        #
        elsif ( $mime_type =~ /application\/pdf/ ) {
            #
            # Perform link check
            #
            Perform_Link_Check($url, $mime_type, $resp);

            #
            # Perform PDF Properties Check check
            #
            Perform_PDF_Properties_Check($url, $content);

            #
            # Perform TQA check of PDF content
            #
            Perform_TQA_Check($url, $content, $language, $mime_type, $resp);

            #
            # Perform feature check
            #
            Perform_Feature_Check($url, $mime_type, $content);
        }

        #
        # Do we have CSS content ?
        #
        elsif ( $mime_type =~ /text\/css/ ) {
            #
            # Perform Link check
            #
            Perform_Link_Check($url, $mime_type, $resp);
            #CSS_Check_Get_Styles($url, $content);

            #
            # Perform TQA check of CSS content
            #
            Perform_TQA_Check($url, $content, $language, $mime_type, $resp);
        }

        #
        # Is the file JavaScript ? or does the URL end in a .js ?
        #
        elsif ( ($mime_type =~ /application\/x\-javascript/) ||
                ($url =~ /\.js$/i) ) {
            #
            # Perform TQA check of JavaScript content
            #
            Perform_TQA_Check($url, $content, $language, $mime_type, $resp);
        }
        #
        # Is the file XML ? or does the URL end in a .xml ?
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            #
            # Perform TQA check of XML content
            #
            Perform_TQA_Check($url, $content, $language, $mime_type, $resp);

            #
            # Perform Interoperability check
            #
            Perform_Interop_Check($url, $content, $language, $mime_type, $resp);
        }
        
        #
        # Perform content checks
        #
        Perform_Content_Check($url, $mime_type, $content);

        #
        # End this URL
        #
        Validator_GUI_End_URL($crawled_urls_tab, $url, $referrer,
                              $supporting_file);
    }
    else {
        #
        # No content
        #
        print "HTTP_Response_Callback: No content for $url\n" if $debug;
    }

    #
    # Return success
    #
    return(0);
}

#***********************************************************************
#
# Name: HTML_Document_Language
#
# Parameters: url - document URL
#             content - document content
#
# Description:
#
#   This function determines the language of a HTML document.  It first
# checks the URL to see if there is a language portion (e.g. -eng), if
# there isn't one, it checks the content.
#
#***********************************************************************
sub HTML_Document_Language {
    my ($url, $content) = @_;

    my ($lang, $lang_code, $status);

    #
    # Check the URL for language specifier
    #
    $lang_code = URL_Check_GET_URL_Language($url);
    if ( $lang_code eq "" ) {
        #
        # Cannot determine language from file name, try the content
        #
        ($lang_code, $lang, $status) = TextCat_HTML_Language($content);
        print "HTML_Document_Language TextCat language is $lang_code\n" if $debug;
    }

    #
    # Return language
    #
    print "HTML_Document_Language of $url is $lang_code\n" if $debug;
    return($lang_code);
}

#***********************************************************************
#
# Name: Save_Content_To_File
#
# Parameters: url - document URL
#             mime_type - document mime type
#             content - document content
#
# Description:
#
#   This function saves the content to a local file.
#
#***********************************************************************
sub Save_Content_To_File {
    my ($url, $mime_type, $content) = @_;

    my ($dir, $filename, $content_saved, @lines, $n);

    #
    # Are we saving content ?
    #
    if ( $save_content ) {
        #
        # Set file name
        #
        $content_file++;
        $dir = "$program_dir/results/content/";
        $filename = sprintf("%03d", $content_file);

        #
        # Determine file suffix based on mime type
        #
        if ( $mime_type =~ /application\/pdf/ ) {
            $filename .= ".pdf";

            #
            # Save content to file
            #
            unlink($filename);
            print "Create PDF file $dir/$filename\n" if $debug;
            open(PDF, ">$dir/$filename") ||
                die "Save_Content_To_File: Failed to open $dir/$filename for writing\n";
            binmode PDF;
            print PDF $content;
            close(PDF);
            $content_saved = 1;
        }
        elsif ( $mime_type =~ /text\/html/ ){
            $filename .= ".html";

            #
            # Create HTML file
            #
            unlink($filename);
            print "Create text file $dir/$filename\n" if $debug;
            open(TXT, ">$dir/$filename") ||
                die "Save_Content_To_File: Failed to open $dir/$filename for writing\n";

            #
            # Split the content on the <head tag
            #
            @lines = split(/<head/i, $content, 2);
            $n = @lines;
            if ( $n > 1 ) {
                 #
                 # Print content before <head then print <head
                 #
                 print TXT $lines[0];
                 print TXT "<head";

                 #
                 # Insert <base after the first tag close
                 #
                 $lines[1] =~ s/>/>\n<base href="$url"\\>\n/;

                 #
                 # Print the rest of the content
                 #
                 print TXT $lines[1];
            }
            else {
                 #
                 # No <head, just print the content
                 #
                 print TXT $lines[0];
            }

            close(TXT);
            $content_saved = 1;
        }
        elsif ( $mime_type =~ /text\// ){
            $filename .= ".txt";

            #
            # Save content to file
            #
            unlink($filename);
            print "Create text file $dir/$filename\n" if $debug;
            open(TXT, ">$dir/$filename") ||
                die "Save_Content_To_File: Failed to open $dir/$filename for writing\n";
            print TXT $content;
            close(TXT);
            $content_saved = 1;
        }
        else {
            #
            # Unsupported content type, don't save it.
            #
            $content_saved = 0;
        }

        #
        # Add to index file for URL to local file mapping.
        #
        if ( $content_saved ) {
            open(HTML, ">> $program_dir/results/content/index.html") ||
            die "Error: Failed to open file $program_dir/results/content/index.html\n";
            print HTML "<li><a href=\"$filename\">$url</li>\n";
            close(HTML);
        }
    }
}

#***********************************************************************
#
# Name: Direct_HTML_Input_Callback
#
# Parameters: content - document content
#             report_options - report options hash table
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when HTML content is pasted into the Direct Input tab
# for validation.
#
#***********************************************************************
sub Direct_HTML_Input_Callback {
    my ($content, %report_options) = @_;
    
    my ($resp);

    #
    # Initialize tool global variables
    #
    Initialize_Tool_Globals(%report_options);
    $save_content = 0;

    #
    # URL is direct input.
    #
    Validator_GUI_Update_Results($crawled_urls_tab, "Direct Input");

    #
    # Report header
    #
    Print_Results_Header("","");

    #
    # Is this URL flagged as "Archived on the Web" ?
    #
    $is_archived = CLF_Check_Is_Archived($clf_check_profile, "Direct Input",
                                         $content);

    #
    # Determine TQA Check exemption status
    #
    $tqa_check_exempted = TQA_Check_Exempt("Direct Input", "text/html", 
                                           $is_archived, $content, \%url_list);

    #
    # Perform markup validation check
    #
    Perform_Markup_Validation("Direct Input", "text/html", "", $content);

    #
    # Get links from document, save list in the global @links variable.
    # We need the list of links (and mime-types) in the document features
    # check.
    #
    @links = Extract_Links("Direct Input", "", "", "text/html", $content);

    #
    # Perform Metadata Check
    #
    Perform_Metadata_Check("Direct Input", $content, $Unknown_Language);

    #
    # Perform TQA check
    #
    Perform_TQA_Check("Direct Input", $content, $Unknown_Language, "text/html",
                      $resp);

    #
    # Perform CLF check
    #
    Perform_CLF_Check("Direct Input", $content, $Unknown_Language, "text/html",
                      $resp);

    #
    # Perform Interoperability check
    #
    Perform_Interop_Check("Direct Input", $content, $Unknown_Language, "text/html",
                      $resp);

    #
    # Perform Feature check
    #
    Perform_Feature_Check("Direct Input", "text/html", $content);
    
    #
    # Print document feature report
    #
    Print_Document_Features_Report();

    #
    # Site analysis complete, print report footer
    #
    Print_Results_Footer(0);
}

#***********************************************************************
#
# Name: Print_Content_Results
#
# Parameters: content_results_list - list of result objects
#
# Description:
#
#   This function prints testcase results to the content tab.
#
#***********************************************************************
sub Print_Content_Results {
    my (@content_results_list) = @_;

    my ($result_object, $status, $output_line, $message);
    
    #
    # Print results
    #
    if ( $display_content_check ) {
        foreach $result_object (@content_results_list ) {
            $status = $result_object->status;
            if ( $status != 0 ) {
                #
                # Increment error instance count
                #
                if ( ! defined($content_error_instance_count{$result_object->description}) ) {
                    $content_error_instance_count{$result_object->description} = 1;
                    $content_error_url_count{$result_object->description} = 1;
                }
                else {
                   $content_error_instance_count{$result_object->description}++;
                   $content_error_url_count{$result_object->description}++;
                }
                $error_count{$content_tab}++;

                #
                # Print error
                #
                Validator_GUI_Print_TQA_Result($content_tab, $result_object);
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_HTML_PDF_Document_Titles
#
# Parameters: none
#
# Description:
#
#   This function calls the Content Check module's URL title check routines
# to check titles of documents.
#
#***********************************************************************
sub Check_HTML_PDF_Document_Titles {

    my (@content_results_list, $pdf_url, $pdf_title, $html_url, $html_title);
    my ($url, $title, %title_errors);

    #
    # Check titles of HTML and PDF documents
    #
    @content_results_list = Content_Check_HTML_PDF_Titles(\%html_titles,
                                                          \%pdf_titles,
                                                          $content_check_profile);

    #
    # Print results
    #
    Print_Content_Results(@content_results_list);
}

#***********************************************************************
#
# Name: Check_Unique_Document_Titles
#
# Parameters: titles - address of hash table of URL/Title table
#
# Description:
#
#   This function calls the Content Check module's URL title check routines
# to check titles of documents.
#
#***********************************************************************
sub Check_Unique_Document_Titles {
    my ($titles) = @_;

    my (@content_results_list);

    #
    # Check that titles of HTML are unique
    #
    @content_results_list = Content_Check_Unique_Titles($titles,
                                                        $content_check_profile);

    #
    # Print results
    #
    Print_Content_Results(@content_results_list);
}

#***********************************************************************
#
# Name: Check_Alternate_Language_Headings
#
# Parameters: none
#
# Description:
#
#   This function calls the Content Check module's alternate language heading
# check function.
#
#***********************************************************************
sub Check_Alternate_Language_Headings {

    my (@content_results_list);

    #
    # Check for consistent number of headings in English & French
    # instances of the same document.
    #
    @content_results_list = Content_Check_Alternate_Language_Heading_Check(
                                     $content_check_profile, %headings_table);

    #
    # Print results
    #
    Print_Content_Results(@content_results_list);
}

#***********************************************************************
#
# Name: Check_Web_Feeds
#
# Parameters: none
#
# Description:
#
#   This function calls the Interoperability Check module's Web
# feed check to check Web feeds.
#
#***********************************************************************
sub Check_Web_Feeds {
    my ($titles) = @_;

    my (@interop_results_list, $result_object, $status);

    #
    # Are we displaying Interoperability checks ? If not we can skip them.
    #
    if ( ! $display_interop_check ) {
        print "Not performing Interoperability checks\n" if $debug;
        return;
    }

    #
    # Check Web feeds
    #
    @interop_results_list = Interop_Check_Feeds($interop_check_profile,
                                                @web_feed_list);

    #
    # Print results
    #
    foreach $result_object (@interop_results_list ) {
        $status = $result_object->status;
        if ( $status != 0 ) {
            #
            # Increment error counters
            #
            $error_count{$interop_tab}++;
            if ( ! defined($interop_error_instance_count{$result_object->description}) ) {
                $interop_error_instance_count{$result_object->description} = 1;
            }
            else {
                $interop_error_instance_count{$result_object->description}++
;
            }
            $interop_error_url_count{$result_object->description} = 1;

            #
            # Print URL
            #
            if ( $report_fails_only ) {
                Print_URL_To_Tab($interop_tab, $result_object->url,
                                 $error_count{$interop_tab});
            }
            else {
                Print_URL_To_Tab($interop_tab, $result_object->url,
                                 $document_count{$interop_tab});
            }

            #
            # Print error
            #
            Validator_GUI_Print_TQA_Result($interop_tab, $result_object);
        }
    }
}

#***********************************************************************
#
# Name: All_Document_Checks
#
# Parameters: none
#
# Description:
#
#   This function perfoms checks on information gathered from all
# documents analysed.  This includes checks such as duplicate document
# titles.
#
#***********************************************************************
sub All_Document_Checks {

    #
    # If we are in CGI mode, we need a heading before
    # reporting any title errors.
    #
    if ( $cgi_mode || $cli_mode ) {
        if ( $display_content_check ) {
            Validator_GUI_Update_Results($content_tab, 
                                         String_Value("Content violations"));
        }
    }

    #
    # Check titles of HTML and PDF documents
    #
    Check_HTML_PDF_Document_Titles();

    #
    # Check that titles of HTML documents are unique
    #
    Check_Unique_Document_Titles(\%html_titles);

    #
    # Check that titles of PDF documents are unique
    #
    Check_Unique_Document_Titles(\%pdf_titles);

    #
    # Check headings for alternate language content
    #
    Check_Alternate_Language_Headings();

    #
    # Check Web feeds
    #
    Check_Web_Feeds();

    #
    # Generate report of URLs, Titles and Headings
    #
    $shared_headings_report = Content_Check_HTML_Headings_Report(\%headings_table,
                                                                 \%html_titles);
}

#***********************************************************************
#
# Name: URL_List_Callback
#
# Parameters: url_list - list of URLs
#             report_options - report options hash table
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when a list of URLs is provided.  It goes through the
# list of URLs and runs the validation tools on each one.
# for validation.
#
#***********************************************************************
sub URL_List_Callback {
    my ($url_list, %report_options) = @_;
    
    my ($this_url, @urls);
    my ($resp_url, $resp, $header, $content_type, $error);

    #
    # Initialize tool global variables
    #
    Initialize_Tool_Globals(%report_options);
    Set_Link_Checker_Ignore_Patterns(@link_ignore_patterns);

    #
    # Report header
    #
    Print_Results_Header("","");

    #
    # Loop through the URLs
    #
    @urls = split(/\r/, $url_list);
    foreach $this_url (@urls) {
        #
        # Ignore blank lines
        #
        $this_url =~ s/\s+$//g;
        $this_url =~ s/^\s+//g;
        if ( $this_url eq "" ) {
            next;
        }

        #
        # Ignore comment lines
        #
        if ( $this_url =~ /^#/ ) {
            next;
        }

        #
        # Get web page
        # 
        print "Process url $this_url\n" if $debug;
        ($resp_url, $resp) = Crawler_Get_HTTP_Response($this_url, "");

        #
        # Did we get the page ?
        #
        if ( defined($resp) && ($resp->is_success) ) {
            #
            # Get mime or content type
            #
            $header = $resp->headers;
            $content_type = $header->content_type;

            #
            # Run validation using response object
            #
            HTTP_Response_Callback($this_url, "", $content_type, $resp);
        }
        else {
            #
            # Error getting document
            #
            $document_count{$crawled_urls_tab}++;
            if ( defined($resp) ) {
                $error = String_Value("HTTP Error") . " " .
                                      $resp->status_line;
            }
            else {
                $error = String_Value("Malformed URL");
            }
            Validator_GUI_Print_URL_Error($crawled_urls_tab, $this_url, 
                                          $document_count{$crawled_urls_tab},
                                          $error);
        }
    }

    #
    # Perform checks information gathered on all documents analysed.
    #
    All_Document_Checks();
    
    #
    # Print document feature report
    #
    Print_Document_Features_Report();

    #
    # Site analysis complete, print report footer
    #
    Print_Results_Footer(0);

    #
    # Finish content saving option
    #
    Finish_Content_Saving($save_content);
    
    #
    # Save Image, Atl text & title report
    #
    $shared_image_alt_text_report = Alt_Text_Check_Generate_Report(\%image_alt_text_table);
}

#***********************************************************************
#
# Name: Save_URL_Image_Alt_Report
#
# Parameters: filename - directory and filename prefix
#
# Description:
#
#   This function saves the url, image, alt report.
#
#***********************************************************************
sub Save_URL_Image_Alt_Report {
    my ($filename) = @_;

    my ($image_report, $image_filename);
    my ($sec, $min, $hour, $mday, $mon, $year, $date);

    #
    # Generate name of image report file name
    #
    $image_filename = $filename . "_img.html";
    unlink($image_filename);

    #
    # Write HTML header for report
    #
    print "Save_URL_Image_Alt_Report, image report = $image_filename\n" if $debug;
    open (REPORT, "> $image_filename");
    print REPORT '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title>' . String_Value("Image/lang/alt/title Report") . '</title>
</head>

<body>
';

    #
    # Add site information if there is some
    #
    if ( $shared_site_dir_e ne "" ) {
        print REPORT "
<h1>" . String_Value("Image report header") . "</h1>
<ul>
<li>$shared_site_dir_e</li>
<li>$shared_site_dir_f</li>
</ul>
";

    #
    # Add site analysis date
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
    $mon++;
    $year += 1900;
    $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec, $year,
                    $mon, $mday);
    print REPORT "
<p>" . String_Value("Analysis completed") . "$date
</p>
";
    }

    #
    # Add report to output file
    #
    print REPORT $shared_image_alt_text_report;
    print REPORT '
</body>
</html>
';

    #
    # Close report
    #
    close(REPORT);
}

#***********************************************************************
#
# Name: Save_Headings_Report
#
# Parameters: filename - directory and filename prefix
#
# Description:
#
#   This function saves the URL, title, heading report.
#
#***********************************************************************
sub Save_Headings_Report {
    my ($filename) = @_;

    my ($report, $save_filename);
    my ($sec, $min, $hour, $mday, $mon, $year, $date);

    #
    # Generate name of headings report file name
    #
    $save_filename = $filename . "_h.html";
    unlink($save_filename);

    #
    # Write HTML header for report
    #
    print "Save_Headings_Report, headings report = $save_filename\n" if $debug;
    open (REPORT, "> $save_filename");
    print REPORT '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title>' . String_Value("Headings Report Title") . '</title>
</head>

<body>
';

    #
    # Add site information if there is some
    #
    if ( $shared_site_dir_e ne "" ) {
        print REPORT "
<h1>" . String_Value("Headings report header") . "</h1>
<ul>
<li>$shared_site_dir_e</li>
<li>$shared_site_dir_f</li>
</ul>
";

    #
    # Add site analysis date
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
    $mon++;
    $year += 1900;
    $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec, $year,
                    $mon, $mday);
    print REPORT "
<p>" . String_Value("Analysis completed") . "$date
</p>
";
    }

    #
    # Add report to output file
    #
    print REPORT $shared_headings_report;
    print REPORT '
</body>
</html>
';

    #
    # Close report
    #
    close(REPORT);
}

#***********************************************************************
#
# Name: Results_Save_Callback
#
# Parameters: filename - directory and filename prefix
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when the user wants to save the results tab content
# in files.  This function saves the results that don't appear
# in a results tab (e.g. image alt text report).
#
#***********************************************************************
sub Results_Save_Callback {
    my ($filename) = @_;

    #
    # Save the URL, Image, Alt report.
    #
    if ( $display_content_check ) {
        Save_URL_Image_Alt_Report($filename);
    }

    #
    # Save the Headings report
    #
    if ( $display_content_check ) {
        Save_Headings_Report($filename);
    }
}

#***********************************************************************
#
# Name: Print_Results_Header
#
# Parameters: site_dir_e - English site domain & directory
#             site_dir_f - French site domain & directory
#
# Description:
#
#   This function prints out the report header.
#
#***********************************************************************
sub Print_Results_Header {
    my ($site_dir_e, $site_dir_f) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year, $date, $tab);
    my ($site_entries);

    #
    # Clear any text that may exist in the results tabs
    #
    foreach $tab ($crawled_urls_tab, $validation_tab, $link_tab,
                  $metadata_tab, $acc_tab, $clf_tab, $content_tab,
                  $doc_list_tab, $doc_features_tab, $interop_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Clear_Results($tab);
            Validator_GUI_Update_Results($tab, 
                "$program_name Version: $version");
        }
    }

    #
    # Do we have entry pages ?
    #
    if ( ($site_dir_e ne "") && ($site_dir_f ne "") ) {
        $site_entries = "\n    " . $site_dir_e .
                        "\n    " . $site_dir_f . "\n\n";

        #
        # Output header to each results tab
        #
        Validator_GUI_Update_Results($crawled_urls_tab, 
                                     String_Value("Crawled URL report header") .
                                     $site_entries);

        if ( $display_validation ) {
            Validator_GUI_Update_Results($validation_tab, 
                                         String_Value("Validation report header") .
                                         $site_entries);
        }

        if ( $display_link_check ) {
            Validator_GUI_Update_Results($link_tab,
                                         String_Value("Link report header") .
                                         $site_entries);
        }

        if ( $display_metadata_check ) {
            Validator_GUI_Update_Results($metadata_tab, 
                                        String_Value("Metadata report header") .
                                         $site_entries);
        }

        if ( $display_tqa_check ) {
            Validator_GUI_Update_Results($acc_tab,
                                         String_Value("ACC report header") .
                                         $site_entries);
        }

        if ( $display_clf_check ) {
            Validator_GUI_Update_Results($clf_tab,
                                         String_Value("CLF report header") .
                                         $site_entries);
        }

        if ( $display_interop_check ) {
            Validator_GUI_Update_Results($interop_tab,
                                         String_Value("Interop report header") .
                                         $site_entries);
        }
        
        if ( $display_content_check ) {
            Validator_GUI_Update_Results($content_tab,
                                         String_Value("Content report header") .
                                         $site_entries);
        }

        if ( $display_doc_features ) {
            Validator_GUI_Update_Results($doc_features_tab,
                                   String_Value("Document Features report header") .
                                         $site_entries);
        }

        if ( $display_document_list ) {
            Validator_GUI_Update_Results($doc_list_tab, 
                                   String_Value("Document List report header") .
                                         $site_entries);
        }
    }

    #
    # Include profile name in header
    #
    if ( $display_metadata_check ) {
        Validator_GUI_Update_Results($metadata_tab,
                                     String_Value("Metadata Profile")
                                     . " " . $metadata_profile);
        Validator_GUI_Update_Results($metadata_tab, "");
    }
    if ( $display_tqa_check ) {
        Validator_GUI_Update_Results($acc_tab,
                                     String_Value("ACC Testcase Profile")
                                     . " " . $tqa_check_profile);
        Validator_GUI_Update_Results($acc_tab, "");
    }
    if ( $display_clf_check ) {
        Validator_GUI_Update_Results($clf_tab,
                                     String_Value("CLF Testcase Profile")
                                     . " " . $clf_check_profile);
        Validator_GUI_Update_Results($clf_tab, "");
    }
    if ( $display_interop_check ) {
        Validator_GUI_Update_Results($interop_tab,
                                     String_Value("Interop Testcase Profile")
                                     . " " . $interop_check_profile);
        Validator_GUI_Update_Results($interop_tab, "");
    }
    if ( $display_content_check ) {
        Validator_GUI_Update_Results($content_tab,
                                 String_Value("Content Check Testcase Profile")
                                     . " " . $content_check_profile);
        Validator_GUI_Update_Results($content_tab, "");
    }
    if ( $display_doc_features ) {
        Validator_GUI_Update_Results($doc_features_tab,
                                     String_Value("Document Features Profile")
                                     . " " . $current_doc_features_profile);
        Validator_GUI_Update_Results($doc_features_tab, "");
    }

    #
    # Add site analysis date to each output tab.
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
    $mon++;
    $year += 1900;
    $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec, $year,
                    $mon, $mday);
    foreach $tab ($crawled_urls_tab, $validation_tab, $link_tab,
                  $metadata_tab, $acc_tab, $clf_tab, $content_tab,
                  $doc_list_tab, $doc_features_tab, $interop_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Start_Analysis($tab, $date, 
                                         String_Value("Analysis started"));
        }
    }
}

#***********************************************************************
#
# Name: Print_Results_Summary_Table
#
# Parameters: none
#
# Description:
#
#   This function prints out the results summary table for each
# result tab.
#
#***********************************************************************
sub Print_Results_Summary_Table {

    my ($tcid, $line, $tab, $faults_per_page, $faults);

    #
    # Print results table header
    #
    foreach $tab ($link_tab, $metadata_tab, $acc_tab, $clf_tab, $content_tab,
                  $interop_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");
            Validator_GUI_Update_Results($tab,
                                         String_Value("Results summary table"));
        }
    }

    #
    # Print summary results table for Link Check
    #
    if ( $display_link_check ) {
        foreach $tcid (sort(keys %link_error_url_count)) {
            Validator_GUI_Update_Results($link_tab, $tcid, 0);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $link_error_url_count{$tcid},
                            $link_error_instance_count{$tcid});

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($link_tab, $line);
            Validator_GUI_Update_Results($link_tab, "");
        }
    }

    #
    # Print summary results table for Metadata Check
    #
    if ( $display_metadata_check ) {
        foreach $tcid (sort(keys %metadata_error_url_count)) {
            Validator_GUI_Update_Results($metadata_tab, $tcid, 0);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $metadata_error_url_count{$tcid},
                            $metadata_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( $metadata_help_url{$metadata_profile} ) ) {
                $line .= " " . String_Value("help") .
                         " " . $metadata_help_url{$metadata_profile};
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($metadata_tab, $line);
            Validator_GUI_Update_Results($metadata_tab, "");
        }
    }

    #
    # Print summary results table for TQA Check
    #
    if ( $display_tqa_check ) { 
        foreach $tcid (sort(keys %tqa_error_url_count)) {
            Validator_GUI_Update_Results($acc_tab, $tcid, 0);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $tqa_error_url_count{$tcid},
                            $tqa_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( TQA_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . TQA_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($acc_tab, $line);
            Validator_GUI_Update_Results($acc_tab, "");
        }

        #
        # Add overall fault count
        #
        if ( defined($document_count{$acc_tab}) &&
             ($document_count{$acc_tab} > 0) ) {
            $faults = $fault_count{$acc_tab};
            $faults_per_page = sprintf("%4.2f", $faults / $document_count{$acc_tab});
            Validator_GUI_Print_Scan_Fault_Count($acc_tab, $faults,
                                                 $faults_per_page);
        }
    }

    #
    # Print summary results table for CLF Check
    #
    if ( $display_clf_check ) {
        foreach $tcid (sort(keys %clf_error_url_count)) {
            Validator_GUI_Update_Results($clf_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $clf_error_url_count{$tcid},
                            $clf_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( CLF_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . CLF_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($clf_tab, $line);
            Validator_GUI_Update_Results($clf_tab, "");
        }
    }

    #
    # Print summary results table for Interopability Check
    #
    if ( $display_interop_check ) {
        foreach $tcid (sort(keys %interop_error_url_count)) {
            Validator_GUI_Update_Results($interop_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $interop_error_url_count{$tcid},
                            $interop_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Interop_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Interop_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($interop_tab, $line);
            Validator_GUI_Update_Results($interop_tab, "");
        }
    }

    #
    # Print summary results table for Content Check
    #
    if ( $display_content_check ) {
        foreach $tcid (sort(keys %content_error_url_count)) {
            Validator_GUI_Update_Results($content_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $content_error_url_count{$tcid},
                            $content_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Content_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Content_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($content_tab, $line);
            Validator_GUI_Update_Results($content_tab, "");
        }
    }


    #
    # Print blank line after table.
    #
    foreach $tab ($acc_tab, $content_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");
        }
    }
}

#***********************************************************************
#
# Name: Print_Results_Footer
#
# Parameters: reached_crawl_limit - flag to indicate if crawl reached
#              limit
#
# Description:
#
#   This function prints out the report footer.
#
#***********************************************************************
sub Print_Results_Footer {
    my ($reached_crawl_limit) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year);
    my ($date, $tab);

    #
    # Print summary results tables
    #
    Print_Results_Summary_Table();

    #
    # Ignore document counts for Crawled URLs tab, we don't need
    # a summary for that tab.
    #
    delete $document_count{$crawled_urls_tab};

    #
    # Get current time/date
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
    $mon++;
    $year += 1900;
    $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec, $year,
                    $mon, $mday);

    #
    # Print footer on each tab
    #
    foreach $tab ($crawled_urls_tab, $validation_tab, $link_tab, 
                  $metadata_tab, $acc_tab, $content_tab, $doc_features_tab,
                  $clf_tab, $interop_tab, $doc_list_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");

            #
            # Do we add note about crawl limit ?
            #
            if ( $reached_crawl_limit ) {
                Validator_GUI_Update_Results($tab,
                                         String_Value("Crawl stopped after") .
                                         " $crawllimit URLs\n");
            }

            #
            # Add number of documents analysed and errors found
            #
            if ( defined($document_count{$tab}) ) {
                Validator_GUI_Update_Results($tab, "");
                Validator_GUI_Update_Results($tab, 
                    String_Value("Documents Checked") . $document_count{$tab});
                if ( defined($error_count{$tab}) ) {
                    Validator_GUI_Update_Results($tab, 
                        String_Value("Documents with errors") .
                        $error_count{$tab});
                }
                Validator_GUI_Update_Results($tab, "");
            }

            #
            # Add completion time & date.
            #
            Validator_GUI_End_Analysis($tab, $date,
                                     String_Value("Analysis completed"));
        }
    }
}

#***********************************************************************
#
# Name: Print_Document_Features_Report
#
# Parameters: none
#
# Description:
#
#   This function prints out the report of document features and the list
# of URLs containing the feature.  The features are printed in alphabetical
# order, with the URLs in each list also in alphabetical order.
#
#***********************************************************************
sub Print_Document_Features_Report {
    my ($feature_id, $this_docl_feature_list, $url, $count);

    #
    # Are we displaying document features ?
    #
    if ( ! $display_doc_features ) {
        return;
    }

    #
    # Get the sorted list of document features
    #
    print "Print_Document_Features_Report\n" if $debug;
    foreach $feature_id (sort(keys(%docl_feature_list))) {
        #
        # Get the list of URLs for this feature
        #
        print "Get list for URL for feature $feature_id\n" if $debug;
        $this_docl_feature_list = $docl_feature_list{$feature_id};

        #
        # Do we have any URLs ?
        #
        if ( keys(%$this_docl_feature_list) > 0 ) {
            #
            # Print list header
            #
            $count = keys(%$this_docl_feature_list);
            print "Print document feature list $feature_id, count = $count\n" if $debug;
            Validator_GUI_Update_Results($doc_features_tab,
                                         String_Value("List of URLs with Document Feature")
                                         . $feature_id . " ($count)\n");
        
            #
            # Print sorted list of URLs
            #
            foreach $url (sort(keys(%$this_docl_feature_list))) {
                $count = $$this_docl_feature_list{$url};
                Validator_GUI_Print_HTML_Feature($doc_features_tab,
                                                 $feature_id, $count, $url);
            }
            Validator_GUI_Update_Results($doc_features_tab, "\n");
       }
    }
}

#***********************************************************************
#
# Name: Check_Page_URL
#
# Parameters: url - URL of page to check
#             do_navigation_link_check - a flag to determine if
#               we are to check navigation links.
#
# Description:
#
#   This checks the URL of the page provided.  If the page can be retrieved
# the response URL is returned.
#
# Return:
#   resp_url - response URL
#
#***********************************************************************
sub Check_Page_URL {
    my ($url, $do_navigation_link_check) = @_;

    my ($resp_url, $resp, $language, $mime_type, $content, @links);
    my ($header, @tqa_results_list, $output, $base);
    my ($sec, $min, $hour, $mday, $mon, $year, $date, $error);

    #
    # Check for a double trailing //, this means that the page file
    # name is / and we also have a directory /.  We can remove these
    # trailing slashes to get the page address.
    #
    if ( $url =~ /\/\/$/ ) {
        $url =~ s/\/\/$//;
    }
    print "Check_Page_URL: $url\n" if $debug;
    ($resp_url, $resp) = Crawler_Get_HTTP_Response($url, "");

    #
    # Did we get the page ?
    #
    if ( (! defined($resp)) || (! $resp->is_success) ) {
        if ( defined($resp) ) {
            $error = String_Value("HTTP Error") . " " .
                                  $resp->status_line;
        }
        else {
            $error = String_Value("Malformed URL");
        }
        Validator_GUI_Print_URL_Error($crawled_urls_tab, $url, 1,
                                      $error);

        #
        # Get current time/date
        #
        ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
        $mon++;
        $year += 1900;
        $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec,
                        $year, $mon, $mday);

        Validator_GUI_End_Analysis($crawled_urls_tab, $date,
                                   String_Value("Analysis terminated"));
        return("");
    }

    #
    # Get mime type
    #
    $header = $resp->headers;
    $mime_type = $header->content_type ;

    #
    # Are we doing navigation link checks ?
    #
    if ( $do_navigation_link_check && ($mime_type =~ /text\/html/) ) {
        #
        # Check for UTF-8 content
        #
        $content = Crawler_Decode_Content($resp);

        #
        # Get document language.
        #
        $language = HTML_Document_Language($url, $content);

        #
        # Determine the abse URL for any relative URLs.  Usually this is
        # the base field from the HTTP Response object (Location field 
        # in HTTP packet).  If the response code is 200 (OK), we don't use the
        # the base field in case the Location field is set (which it should 
        # not be).
        #
        if ( $resp->code == 200 ) {
            $base = $url;
        }
        else {
            $base = $resp->base;
        }

        #
        # Extract links from the page
        #
        print "Extract links from document\n  --> $url\n" if $debug;
        @links = Extract_Links($url, $base, $language, $mime_type,
                               $content);

        #
        # Check navigation links from all navigation subsections
        # Since we don't expect to have any yet, this check initializes
        # the site_navigation_links data structure.
        #
        %all_link_sets = Extract_Links_Subsection_Links("ALL");
        TQA_Check_Links(\@tqa_results_list, $url, $tqa_check_profile,
                        $language, \%all_link_sets, \%site_navigation_links);
                        
        #
        # Check links from all navigation sections.  We do this here, not
        # to detect error rather to initialize the site links structure.
        #
        CLF_Check_Links(\@tqa_results_list, $url, "",
                        $language, \%all_link_sets, \%clf_site_links);

    }

    #
    # Return response URL
    #
    return($resp_url);
}

#***********************************************************************
#
# Name: Setup_Content_Saving
#
# Parameters: save_content - save content flag
#
# Description:
#
#   This function setups up a directory to save the web site content.
#
#***********************************************************************
sub Setup_Content_Saving {
    my ($save_content) = @_;

    my (@files);

    #
    # Are we saving content ? if so increment directory name
    #
    if ( $save_content ) {
        #
        # Do we already have a directory ?
        #
        print "Content directory = $program_dir/results/content\n" if $debug;
        if ( -d "$program_dir/results/content" ) {
            #
            # Remove any only files
            #
            print "Remove file from $program_dir/results/content\n" if $debug;
            opendir (DIR, "$program_dir/results/content");
            @files = readdir(DIR);
            foreach (@files) {
                if ( -f "$program_dir/results/content/$_" ) {
                    unlink("$program_dir/results/content/$_");
                }
            }
            closedir(DIR);
        }
        else {
            print "Create directory $program_dir/results/content\n" if $debug;
            mkdir("$program_dir/results/content", 0755);
        }

        #
        # Create index file for URL to local file mapping.
        #
        unlink("$program_dir/results/content/index.html");
        open(HTML, "> $program_dir/results/content/index.html") ||
            die "Error: Failed to create file $program_dir/results/content/index.html\n";
        print HTML "<html>
<body>
<ul>
";
        close(HTML);
    }
}

#***********************************************************************
#
# Name: Finish_Content_Saving
#
# Parameters: save_content - save content flag
#
# Description:
#
#   This function finishes up content saving by completing the index file.
#
#***********************************************************************
sub Finish_Content_Saving {
    my ($save_content) = @_;

    #
    # Finish off index file for URL to local file mapping.
    #
    if ( $save_content ) {
        open(HTML, ">> $program_dir/results/content/index.html") ||
        die "Error: Failed to open file $program_dir/results/content/index.html\n";
        print HTML "</ul>
</body>
</html>
";
        close(HTML);
    }
}

#***********************************************************************
#
# Name: Check_Login_Page
#
# Parameters: loginpage - login page URL
#             site_dir - site directory URL
#
# Description:
#
#   This function checks the login page URL.  It returns false (0)
# if the page cannot be found.  It returns true(1) if the page can be
# found, of if there is no login page set.
#
#***********************************************************************
sub Check_Login_Page {
    my ($loginpage, $site_dir) = @_;

    my ($check_url, $resp_url);
    my ($rc) = 1;

    #
    # Make sure we can get at the login page before we start
    # the crawl.
    #
    if ( defined($loginpage) && ($loginpage ne "")) {
        print "Check_Login_Page $loginpage\n" if $debug;
        if ( $loginpage =~ /^http/ ) {
            $check_url = $loginpage;
        }
        else {
            $check_url = "$site_dir/$loginpage";
        }

        #
        # Can we get this page ?
        #
        $resp_url = Check_Page_URL($check_url, 0);
        if ( $resp_url eq "" ) {
            $rc = 0;
        }
        else {
            #
            # Did the login page change ?
            #
            if ( $resp_url ne $check_url ) {
                print "Change in login page to $resp_url\n" if $debug;
            }
        }
    }

    #
    # Return status, 0 = login page is invalid
    #
    return($rc);
}

#***********************************************************************
#
# Name: Initialize_Tool_Globals
#
# Parameters: options - hash table of tool options
#
# Description:
#
#   This function extracts a number of tool options and copies them
# to program global variable for easy access.
#
#***********************************************************************
sub Initialize_Tool_Globals {
    my (%options) = @_;

    my ($html_profile_table, $html_feature_id);

    #
    # Set global report_fails_only flag
    #
    $report_fails_only = $options{"report_fails_only"};
    $save_content = $options{"save_content"};

    #
    # Setup content saving option
    #
    Setup_Content_Saving($save_content);

    #
    # Get link check profile name
    #
    $link_check_profile = $options{$link_check_profile_label};

    #
    # Get metadata profile name
    #
    $metadata_profile = $options{$metadata_profile_label};

    #
    # Get PDF property profile name
    #
    $pdf_property_profile = $options{$pdf_property_profile_label};

    #
    # Get TQA Check profile name
    #
    $tqa_check_profile = $options{$tqa_profile_label};

    #
    # Get CLF Check profile name
    #
    $clf_check_profile = $options{$clf_profile_label};
    Set_Link_Check_CLF_Profile($clf_check_profile);
    
    #
    # Get Interoperability Check profile name
    #
    $interop_check_profile = $options{$interop_profile_label};

    #
    # Get Content Check profile name
    #
    $content_check_profile = $options{$content_check_profile_label};

    #
    # Get document features profile
    #
    $current_doc_features_profile = $options{$doc_profile_label};

    #
    # Set robots handling
    #
    if ( $options{$robots_label} eq String_Value("Ignore robots.txt") ) {
        #
        # Ignore robots.txt directives
        #
        Crawler_Robots_Handling(0);
    }
    else {
        #
        # Respect robots.txt directives
        #
        Crawler_Robots_Handling(1);
    }

    #
    # Initialize document and error counts and valid markup flags
    #
    %document_count = ();
    %error_count = ();
    %fault_count = ();

    #
    # Initialize markup validity flags and other tool results
    #
    %is_valid_markup = ();
    %tqa_other_tool_results = ();
    %clf_other_tool_results = ();
    %image_alt_text_table = ();
    %html_titles = ();
    %title_html_url = ();
    %pdf_titles = ();
    %link_error_url_count = ();
    %link_error_instance_count = ();
    %tqa_error_url_count = ();
    %tqa_error_instance_count = ();
    %content_error_url_count = ();
    %content_error_instance_count = ();
    %metadata_error_url_count = ();
    %metadata_error_instance_count = ();
    $shared_site_dir_e = "";
    $shared_site_dir_f = "";
    $shared_headings_report = "";
    %clf_error_url_count = ();
    %clf_error_instance_count = ();
    %decorative_images = ();
    %non_decorative_images = ();
    $is_archived = 0;
    $tqa_check_exempted = 0;
    %url_list = ();
    @web_feed_list = ();

    #
    # Add list of decorative & non-decorative images from tool
    # configuration to their respective lists.
    #
    TQA_Check_Add_To_Image_List(\%decorative_images, @decorative_image_urls);
    TQA_Check_Add_To_Image_List(\%non_decorative_images, 
                                @non_decorative_image_urls);

    #
    # Create lists for document features
    #
    $html_profile_table = $doc_features_profile_map{$current_doc_features_profile};
    foreach $html_feature_id (keys(%$html_profile_table)) {
        my (%new_docl_feature_list);
        print "Create document feature list $html_feature_id\n" if $debug;
        $docl_feature_list{$html_feature_id} = \%new_docl_feature_list;
    }

}

#***********************************************************************
#
# Name: Perform_Site_Crawl
#
# Parameters: crawl_details - hash table of crawl details
#
# Description:
#
#   This function crawls the site to get a list of document URLs.
#
#***********************************************************************
sub Perform_Site_Crawl {
    my (%crawl_details) = @_;
    
    my ($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f);
    my ($loginpagee, $logoutpagee, $loginpagef, $logoutpagef);
    my ($loginformname, $logininterstitialcount, $logoutinterstitialcount);
    my (@url_list, @url_type, @url_last_modified, @url_size, @url_referrer);
    my ($content, $url, $resp_url, $tab, $i);
    my (@site_link_check_ignore_patterns);
    my ($sec, $min, $hour, $mday, $mon, $year, $date);

    #
    # Copy site details into local variables for easy access
    #
    $site_dir_e = $crawl_details{"sitedire"};
    $site_dir_f = $crawl_details{"sitedirf"};
    $site_entry_e = $crawl_details{"siteentrye"};
    $site_entry_f = $crawl_details{"siteentryf"};
    $loginpagee = $crawl_details{"loginpagee"};
    $logoutpagee = $crawl_details{"logoutpagee"};
    $loginpagef = $crawl_details{"loginpagef"};
    $logoutpagef = $crawl_details{"logoutpagef"};
    $loginformname = $crawl_details{"loginformname"};
    $logininterstitialcount = $crawl_details{"logininterstitialcount"};
    $logoutinterstitialcount = $crawl_details{"logoutinterstitialcount"};

    #
    # Initialize tool global variables
    # 
    Initialize_Tool_Globals(%crawl_details);

    #
    # Get crawl limit
    #
    $crawllimit = $crawl_details{"crawllimit"};

    #
    # Set global login flag to false, we have not performed login
    #
    $performed_login = 0;

    #
    # Set proxy for HTTP traffic.
    #
    Crawler_Set_Proxy($crawl_details{"httpproxy"});
    Link_Checker_Set_Proxy($crawl_details{"httpproxy"});

    #
    # Make sure we can get at the English entry page before we start
    # the crawl.
    #   
    $resp_url = Check_Page_URL("$site_dir_e/$site_entry_e", 1);
    if ( $resp_url eq "" ) {
        return;
    }

    #
    # Did the response change the site directory ? if so our crawl will
    # fail.
    #
    if ( index($resp_url, $site_dir_e) != 0 ) {
        Validator_GUI_Print_Error($crawled_urls_tab, 
                                  String_Value("Entry page") .
                                  "$site_dir_e/$site_entry_e" . 
                                  String_Value("rewritten to") .
                                  $resp_url);

        #
        # Get current time/date
        #
        ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
        $mon++;
        $year += 1900;
        $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec,
                        $year, $mon, $mday);

        Validator_GUI_End_Analysis($crawled_urls_tab, $date,
                                   String_Value("Analysis terminated"));
        return;
    }

    #
    # Make sure we can get at the French entry page before we start
    # the crawl.
    #
    $resp_url = Check_Page_URL("$site_dir_f/$site_entry_f", 1);
    if ( $resp_url eq "" ) {
        return;
    }

    #
    # Did the response change the site directory ? if so our crawl will
    # fail.
    #
    if ( index($resp_url, $site_dir_f) != 0 ) {
        Validator_GUI_Print_Error($crawled_urls_tab, 
                                  String_Value("Entry page") .
                                  "$site_dir_f/$site_entry_f" . 
                                  String_Value("rewritten to") .
                                  $resp_url);

        #
        # Get current time/date
        #
        ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
        $mon++;
        $year += 1900;
        $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec,
                        $year, $mon, $mday);

        Validator_GUI_End_Analysis($crawled_urls_tab, $date,
                                   String_Value("Analysis terminated"));
        return;
    }

    #
    # Make sure we can get at the English login page before we start
    # the crawl.
    #   
    if ( ! Check_Login_Page($loginpagee, $site_dir_e) ) {
       return;
    }

    #
    # Make sure we can get at the French login page before we start
    # the crawl.
    #
    if ( ! Check_Login_Page($loginpagef, $site_dir_f) ) {
       return;
    }

    #
    # Print report header in results window.
    #
    Print_Results_Header($site_dir_e, $site_dir_f);

    #
    # Set maximum number of URLs to crawl.
    # Set Link check ignore patters to ignore the logout pages.
    #
    Set_Crawler_Set_Maximum_URLs_To_Return($crawllimit);
    @site_link_check_ignore_patterns = @link_ignore_patterns;
    if ( defined($logoutpagee) && ($logoutpagee ne "") ) {
        push(@site_link_check_ignore_patterns, "$logoutpagee");
    }
    if ( defined($logoutpagef) && ($logoutpagef ne "") ) {
        push(@site_link_check_ignore_patterns, "$logoutpagef");
    }
    Set_Link_Checker_Ignore_Patterns(@site_link_check_ignore_patterns);

    #
    # Save site directory paths in shared variables
    #
    $shared_site_dir_e = $site_dir_e;
    $shared_site_dir_f = $site_dir_f;

    #
    # Check to see if we have a login page, if so we have to tell the
    # crawler about it.
    #
    if ( defined($loginpagee) && ($loginpagee ne "") ) {
        Set_Crawler_Login_Logout($loginpagee, $logoutpagee, $loginpagef, 
                                 $logoutpagef, $loginformname, 
                                 \&Login_Callback,
                                 $logininterstitialcount, $logoutinterstitialcount);
    }

    #
    # Crawl the site
    #
    if ( $debug ) {
        print "Perform_Site_Crawl site_dir_e = $site_dir_e\n";
        print "                   site_dir_f = $site_dir_f\n";
        print "                   site_entry_e = $site_entry_e\n";
        print "                   site_entry_f = $site_entry_f\n";
        print "                   report_fails_only = $report_fails_only\n";
        print "                   save_content = $save_content\n";
    }
    Crawl_Site($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f,
                  $max_urls_between_sleeps, $debug,
                  \@url_list, \@url_type, \@url_last_modified,
                  \@url_size, \@url_referrer);

    #
    # Perform checks information gathered on all documents analysed.
    #
    All_Document_Checks();

    #
    # Print document feature report
    #
    Print_Document_Features_Report();
 
    #
    # Site crawl is complete, print sorted list of URLs in URLs tab.
    #
    if ( $display_document_list ) {
        $i = 1;
        foreach $url (sort(@url_list)) {
            Validator_GUI_Update_Results($doc_list_tab, "$i:  $url");
            $i++;
        }
    }
    
    #
    # Check the number of documents crawled, is it the same as our
    # crawl limit ? If so add a note to the bottom of each report
    # indicating that we reached the crawl limit and there may be more
    # documents on the site that were not analysed.
    #
    if ( ! $cgi_mode ) {
        if ( $crawllimit == @url_list ) {
            Print_Results_Footer(1);
        }
        else {
            #
            # Site analysis complete, print report footer
            #
            Print_Results_Footer(0);
        }
    }

    #
    # Finish content saving option
    #
    Finish_Content_Saving($save_content);
    
    #
    # Save Image, Atl text & title report
    #
    $shared_image_alt_text_report = Alt_Text_Check_Generate_Report(\%image_alt_text_table);

    print "Return from Perform_Site_Crawl\n" if $debug;

}

#***********************************************************************
#
# Name: Print_URL_To_Tab
#
# Parameters: tab - results tab
#             url - document URL
#             number - document number
#
# Description:
#
#   This function prints the URL and the current date to the
# specified results tab.
#
#***********************************************************************
sub Print_URL_To_Tab {
    my ($tab, $url, $number) = @_;
    
    #
    # Print URL and date to results tab.
    #
    Validator_GUI_Print_URL($tab, $url, $number);
}

#***********************************************************************
#
# Name: Increment_Counts_and_Print_URL
#
# Parameters: tab - tab id
#             url - URL
#             has_errors - whether or not to increment error count
#
# Description:
#
#   This function increments the document count for the specified tab.
# It also increments the error count if the has_errors flag is TRUE.
# It prints the URL along with the appropriate counter to the tab.
#
#***********************************************************************
sub Increment_Counts_and_Print_URL {
    my ($tab, $url, $has_errors) = @_;

    #
    # Increment document & error counters
    #
    $document_count{$tab}++;
    if ( $has_errors ) {
        $error_count{$tab}++;
    }

    #
    # Print URL
    #
    if ( defined($tab) ) {
        if ( $report_fails_only ) {
            if ( $has_errors ) {
                Print_URL_To_Tab($tab, $url, $error_count{$tab});
            }
        }
        else {
            Print_URL_To_Tab($tab, $url, $document_count{$tab});
        }
    }
}

#***********************************************************************
#
# Name: Perform_Markup_Validation
#
# Parameters: url - document URL
#             mime_type - content mime type
#             charset - charset option
#             content - content to validate
#
# Description:
#
#   This function runs the HTML validator.
#
#***********************************************************************
sub Perform_Markup_Validation {
    my ( $url, $mime_type, $charset, $content ) = @_;

    my ($pattern, @results_list, $result_object, $status);

    #
    # Are we displaying markup validation ? If not we can skip them.
    #
    if ( ! $display_validation ) {
        print "Not performing markup validation\n" if $debug;
        return;
    }

    #
    # Do we want to skip validation of this document ?
    #
    foreach $pattern (@validation_url_skip_patterns) {
        if ( $url =~ /$pattern/i ) {
            print "Skipping validation on $url, matches pattern $pattern\n" if $debug;
            return;
        }
    }

    #
    # In content mode we ignore validation
    #
    if ( $content_mode ) {
        return;
    }

    #
    # Is this URL exempt from TQA checking ? if it is we don't report any faults
    #
    if ( $tqa_check_exempted ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip validation\n" if $debug;
        Increment_Counts_and_Print_URL($validation_tab, $url, 0);
    }
    else {
        #
        # Validate the HTML content.
        #
        print "Perform_Markup_Validation on URL\n  --> $url\n" if $debug;
        @results_list = Validate_Markup($url, $mime_type, $charset, $content);

        #
        # Get validation status
        #
        $status = 0;
        foreach $result_object (@results_list) {
            $status += $result_object->status;

            #
            # Check for validation failure and set valid markup flag
            #
            if ( $result_object->testcase eq "HTML_VALIDATION" ) {
                $is_valid_markup{"text/html"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "CSS_VALIDATION" ) {
                $is_valid_markup{"text/css"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "JAVASCRIPT_VALIDATION" ) {
                $is_valid_markup{"application/x-javascript"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "FEED_VALIDATION" ) {
                $is_valid_markup{"text/xml"} = ($result_object->status == 0);
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($validation_tab, $url, ($status != 0));

        #
        # Print results of each validation if it failed
        #
        if ( $display_validation ) {
            foreach $result_object (@results_list) {
                if ( $result_object->status != 0 ) {
                    Validator_GUI_Print_TQA_Result($validation_tab, $result_object);
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Perform_Metadata_Check
#
# Parameters: url - document URL
#             content - document content
#             language - URL language
#
# Description:
#
#   This function checks the metadata within the content of the specified
# URL.
#
#***********************************************************************
sub Perform_Metadata_Check {
    my ( $url, $content, $language ) = @_;

    my ($url_status, $status, $result_object, @metadata_results_list);
    my (%local_metadata_error_url_count, $title);

    #
    # Are we displaying Metadata checks ? If not we can skip them.
    #
    if ( ! $display_metadata_check ) {
        print "Not performing Metadata checks\n" if $debug;
        return;
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip metadata check\n" if $debug;
        Increment_Counts_and_Print_URL($metadata_tab, $url, 0);
    }
    else {
        #
        # Check the document
        #
        print "Perform_Metadata_Check on URL\n  --> $url\n" if $debug;
        %metadata_results = ();
        @metadata_results_list = Validate_Metadata($url, $language,
                                                   $metadata_profile, $content,
                                                   \%metadata_results);

        #
        # Save URL for this document title (if we don't already have one).
        # This is used later when checking accessibility, if a PDF
        # document has a corresponding HTML document, only the HTML is
        # checked for accessibility.
        #
        if ( defined($metadata_results{"title"}) ) {
            $result_object = $metadata_results{"title"};
            $title = $result_object->content;
            if ( ($title ne "") && (! defined($title_html_url{$title})) ) {
                $title_html_url{$title} = $url;
            }
        }
        else {
            $title = "";
        }
        $html_titles{$url} = $title;

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@metadata_results_list ) {
            if ( $result_object->status != 0 ) {
                #
                # Metadata error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($metadata_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results if it is a failure.
        #
        if ( $url_status == $tool_error ) {
            foreach $result_object (@metadata_results_list ) {
                $status = $result_object->status;
                if ( $status != 0 ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($metadata_error_instance_count{$result_object->description}) ) {
                        $metadata_error_instance_count{$result_object->description} = 1;
                    }
                    else {
                        $metadata_error_instance_count{$result_object->description}++;
                    }

                    #
                    # Set URL error count
                    #
                    $local_metadata_error_url_count{$result_object->description} = 1;
                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($metadata_tab,
                                                   $result_object);
                }
            }

            #
            # Add blank line in report after URL if we had errors
            #
            Validator_GUI_Update_Results($metadata_tab, "");
        }
        
        #
        # Set global URL error count
        #
        foreach (keys %local_metadata_error_url_count) {
            $metadata_error_url_count{$_}++;
        }
    }
}

#***********************************************************************
#
# Name: Perform_PDF_Properties_Check
#
# Parameters: url - document URL
#             content - document content
#
# Description:
#
#   This function checks the properties (metadata) within the content
# of the specified URL.
#
#***********************************************************************
sub Perform_PDF_Properties_Check {
    my ( $url, $content) = @_;

    my ($url_status, $key, $status, $message, $result_object);
    my (%pdf_property_results, @pdf_property_results, $output_line);
    my (%local_metadata_error_url_count);
    my ($error_message) = "";

    #
    # Are we displaying Metadata checks ? If not we can skip them.
    #
    if ( ! $display_metadata_check ) {
        print "Not performing PDF properties checks\n" if $debug;
        return;
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip pdf properties check\n" if $debug;
        Increment_Counts_and_Print_URL($metadata_tab, $url, 0);
    }
    else {
        #
        # Check the document
        #
        print "Perform_PDF_Properties_Check on URL\n  --> $url\n" if $debug;
        @pdf_property_results = PDF_Files_Validate_Properties($url,
                                                        $pdf_property_profile,
                                                        $content,
                                                        \%pdf_property_results);

        #
        # Do we have a title for this URL ?
        #
        if ( defined($pdf_property_results{"Title"}) ) {
            $result_object = $pdf_property_results{"Title"};
            $pdf_titles{$url} = $result_object->content;
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@pdf_property_results) {
            if ( $result_object->status != 0 ) {
                #
                # PDF Property error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($metadata_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results if it is a failure.
        #
        if ( $url_status == $tool_error ) {
            foreach $result_object (@pdf_property_results) {
                $status = $result_object->status;
                if ( $status != 0 ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($metadata_error_instance_count{$result_object->description}) ) {
                        $metadata_error_instance_count{$result_object->description} = 1;
                    }
                    else {
                        $metadata_error_instance_count{$result_object->description}++;
                    }

                    #
                    # Set URL error count
                    #
                    $local_metadata_error_url_count{$result_object->description} = 1;

                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($metadata_tab,
                                                   $result_object);
                }
            }

            #
            # Add blank line in report after URL if we had errors
            #
            Validator_GUI_Update_Results($metadata_tab, "");
        }
        
        #
        # Set global URL error count
        #
        foreach (keys %local_metadata_error_url_count) {
            $metadata_error_url_count{$_}++;
        }
    }
}

#***********************************************************************
#
# Name: Perform_TQA_Check
#
# Parameters: url - document URL
#             content - document content
#             language - URL language
#             mime_type - content mime-type
#             resp - HTTP::Response object
#
# Description:
#
#   This function performs a number of technical QA tests on the content.
#
#***********************************************************************
sub Perform_TQA_Check {
    my ($url, $content, $language, $mime_type, $resp) = @_;

    my ($url_status, $status, $message, $source_line);
    my (@tqa_results_list, $result_object, $output_line, $error_message);
    my (%local_tqa_error_url_count, @content_links, $pattern);
    my ($score, $faults, %faults_by_group, $title, $list_ref);

    #
    # Do we want to skip TQA checking of this document ?
    #
    print "Perform_TQA_Check on URL\n  --> $url\n" if $debug;
    foreach $pattern (@tqa_url_skip_patterns) {
        if ( $url =~ /$pattern/i ) {
            print "Skipping TQA check on $url, matches pattern $pattern\n" if $debug;
            return;
        }
    }

    #
    # Is this a PDF document and do we have an HTML document with the
    # same title ?
    #
    if ( $mime_type =~ /application\/pdf/ ) {
        if ( defined($pdf_titles{$url}) && ($pdf_titles{$url} ne "") ) {
            $title = $pdf_titles{$url};
            if ( defined($title_html_url{$title}) ) {
                print "PDF document has HTML equivalent " .
                      $title_html_url{$title} . 
                      " skipping TQA check\n" if $debug;

                #
                # Record this URL as an alternate format
                #
                if ( defined($docl_feature_list{"alternate/autre format"}) ) {
                    $list_ref = $docl_feature_list{"alternate/autre format"};
                    print "Add to document feature list \"alternate/autre format\", url = $url\n" if $debug;
                    $$list_ref{$url} = 1;
                }
                return;
            }
        }
    }

    #
    # Check for rel="alternate" on the link to this document.
    # If that attribute is present is is an alternate format of
    # another document and is not subject to accessibility
    # testing.  The check is only carried out for non HTML documents.
    #
    if ( ! ( $mime_type =~ /text\/html/ ) ) {
        if ( Link_Check_Has_Rel_Alternate($url) ) {
            print "URL is an alternate format, skipping TQA check\n" if $debug;

            #
            # Record this URL as an alternate format
            #
            if ( defined($docl_feature_list{"alternate/autre format"}) ) {
                $list_ref = $docl_feature_list{"alternate/autre format"};
                print "Add to document feature list \"alternate/autre format\", url = $url\n" if $debug;
                $$list_ref{$url} = 1;
            }
            return;
        }
    }

    #
    # Tell TQA Check module whether or not documents have
    # valid markup.
    #
    Set_TQA_Check_Valid_Markup($url, %is_valid_markup);

    #
    # Tell TQA Check module the results of other tools
    #
    TQA_Check_Other_Tool_Results(%tqa_other_tool_results);

    #
    # Check the document
    #
    @tqa_results_list = TQA_Check($url, $language, $tqa_check_profile,
                                  $mime_type, $resp, $content);
                                  
    #
    # If the document is an HTML document, check content and
    # navigation links
    #
    if ( $mime_type =~ /text\/html/ ) {
        TQA_Check_Links(\@tqa_results_list, $url, $tqa_check_profile, $language,
                        \%all_link_sets, \%site_navigation_links);
                                   
        #
        # Check images
        #
        TQA_Check_Images(\@tqa_results_list, $url, $tqa_check_profile, \@links,
                         \%decorative_images, \%non_decorative_images);

    }
    
    #
    # Determine overall URL status
    #
    $url_status = $tool_success;
    foreach $result_object (@tqa_results_list ) {
        if ( $result_object->status != 0 ) {
            #
            # TQA Check error, we can stop looking for more errors
            #
            $url_status = $tool_error;
            last;
        }
    }

    #
    # Is this URL exempt from TQA checking ? if it is we don't report any faults
    #
    if ( $tqa_check_exempted ) {
        Increment_Counts_and_Print_URL($acc_tab, $url, 0);
    }
    else {
        #
        # Calculate number of faults
        #
        $faults = @tqa_results_list;
        $fault_count{$acc_tab} += $faults;

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($acc_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results
        #
        if ( $url_status == $tool_error ) {
            if ( $display_tqa_check ) {
                #
                # Print fault count.
                #
                Validator_GUI_Print_URL_Fault_Count($acc_tab, $faults, $url);

                #
                # Print each of the result objects
                #
                foreach $result_object (@tqa_results_list ) {
                    $status = $result_object->status;
                    if ( $status != 0 ) {
                        #
                        # Increment error instance count
                        #
                        if ( ! defined($tqa_error_instance_count{$result_object->description}) ) {
                            $tqa_error_instance_count{$result_object->description} = 1;
                        }
                        else {
                            $tqa_error_instance_count{$result_object->description}++;
                        }

                        #
                        # Set URL error count
                        #
                        $local_tqa_error_url_count{$result_object->description} = 1;

                        #
                        # Print error
                        #
                        Validator_GUI_Print_TQA_Result($acc_tab, $result_object);
                    }
                }

                #
                # Set global URL error count
                #
                foreach (keys %local_tqa_error_url_count) {
                    $tqa_error_url_count{$_}++;
                }

                #
                # Add blank line in report after URL if we had errors
                #
                Validator_GUI_Update_Results($acc_tab, "");
            }
        }
    }
}

#***********************************************************************
#
# Name: Perform_CLF_Check
#
# Parameters: url - document URL
#             content - document content
#             language - URL language
#             mime_type - content mime-type
#             resp - HTTP::Response object
#
# Description:
#
#   This function performs a number of Common Look and Feel (CLF)
# QA tests on the content.
#
#***********************************************************************
sub Perform_CLF_Check {
    my ($url, $content, $language, $mime_type, $resp) = @_;

    my ($url_status, $status, $message, $source_line);
    my (@clf_results_list, $result_object, $output_line, $error_message);
    my (%local_clf_error_url_count, @content_links, $pattern);

    #
    # Are we displaying CLF checks ? If not we can skip them.
    #
    if ( ! $display_clf_check ) {
        print "Not performing CLF checks\n" if $debug;
        return;
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # Check for all archived on the web markers
        #
        @clf_results_list = CLF_Check_Archive_Check($url, $language,
                                                    $clf_check_profile,
                                                    $mime_type, $resp, $content);
    }
    else {
        #
        # Tell CLF Check module the results of other tools
        #
        CLF_Check_Other_Tool_Results(%clf_other_tool_results);

        #
        # Check the document
        #
        print "Perform_CLF_Check on URL\n  --> $url\n" if $debug;
        @clf_results_list = CLF_Check($url, $language, $clf_check_profile,
                                      $mime_type, $resp, $content);

        #
        # If the document is an HTML document, check
        # navigation links
        #
        if ( $mime_type =~ /text\/html/ ) {
            CLF_Check_Links(\@clf_results_list, $url,
                            $clf_check_profile, $language,
                            \%all_link_sets, \%clf_site_links);
        }
    }

    #
    # Determine overall URL status
    #
    $url_status = $tool_success;
    foreach $result_object (@clf_results_list ) {
        if ( $result_object->status != 0 ) {
            #
            # CLF Check error, we can stop looking for more errors
            #
            $url_status = $tool_error;
            last;
        }
    }

    #
    # Increment document & error counters
    #
    Increment_Counts_and_Print_URL($clf_tab, $url,
                                   ($url_status == $tool_error));

    #
    # Print results
    #
    if ( $url_status == $tool_error ) {
        foreach $result_object (@clf_results_list ) {
            $status = $result_object->status;
            if ( $status != 0 ) {
                #
                # Increment error instance count
                #
                if ( ! defined($clf_error_instance_count{$result_object->description}) ) {
                    $clf_error_instance_count{$result_object->description} = 1;
                }
                else {
                    $clf_error_instance_count{$result_object->description}++;
                }

                #
                # Set URL error count
                #
                $local_clf_error_url_count{$result_object->description} = 1;

                #
                # Print error
                #
                Validator_GUI_Print_TQA_Result($clf_tab, $result_object);
            }
        }

        #
        # Set global URL error count
        #
        foreach (keys %local_clf_error_url_count) {
            $clf_error_url_count{$_}++;
        }

        #
        # Add blank line in report after URL if we had errors
        #
        Validator_GUI_Update_Results($clf_tab, "");
    }
}

#***********************************************************************
#
# Name: Perform_Interop_Check
#
# Parameters: url - document URL
#             content - document content
#             language - URL language
#             mime_type - content mime-type
#             resp - HTTP::Response object
#
# Description:
#
#   This function performs a number of Interoperability
# QA tests on the content.
#
#***********************************************************************
sub Perform_Interop_Check {
    my ($url, $content, $language, $mime_type, $resp) = @_;

    my ($url_status, $status, $message, $source_line);
    my (@interop_results_list, $result_object, $output_line, $error_message);
    my (%local_interop_error_url_count, @content_links, $pattern);
    my ($feed_object, $result_object, $title);

    #
    # Are we displaying Interoperability checks ? If not we can skip them.
    #
    if ( ! $display_interop_check ) {
        print "Not performing Interoperability checks\n" if $debug;
        return;
    }


    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip interoperability check\n" if $debug;
        Increment_Counts_and_Print_URL($interop_tab, $url, 0);
    }
    else {
        #
        # Check the document
        #
        print "Perform_Interop_Check on URL\n  --> $url\n" if $debug;
        @interop_results_list = Interop_Check($url, $language,
                                              $interop_check_profile,
                                              $mime_type, $resp, $content);

        #
        # If the document is an HTML document, check
        # links
        #
        if ( $mime_type =~ /text\/html/ ) {

            #
            # Get the title of the URL
            #
            if ( defined($metadata_results{"title"}) ) {
                $result_object = $metadata_results{"title"};
                $title = $result_object->content;
            }
            else {
                #
                # No title, set it to the URL
                #
                $title = $url;
            }

            Interop_Check_Links(\@interop_results_list, $url, $title,
                                $mime_type, $interop_check_profile,
                                $language, \%all_link_sets);
        }
        #
        # If this appears to be a Web feed, get the feed details
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
             ($mime_type =~ /text\/xml/) ||
             ($url =~ /\.xml$/i) ) {
            $feed_object = Interop_Check_Feed_Details($url, $content);
            if ( defined($feed_object) ) {
                push(@web_feed_list, $feed_object);
            }
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@interop_results_list ) {
            if ( $result_object->status != 0 ) {
                #
                # CLF Check error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($interop_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results
        #
        if ( $url_status == $tool_error ) {
            foreach $result_object (@interop_results_list ) {
                $status = $result_object->status;
                if ( $status != 0 ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($interop_error_instance_count{$result_object->description}) ) {
                        $interop_error_instance_count{$result_object->description} = 1;
                    }
                    else {
                        $interop_error_instance_count{$result_object->description}++;
                    }

                    #
                    # Set URL error count
                    #
                    $local_interop_error_url_count{$result_object->description} = 1;

                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($interop_tab, $result_object);
                }
            }

            #
            # Set global URL error count
            #
            foreach (keys %local_interop_error_url_count) {
                $interop_error_url_count{$_}++;
            }

            #
            # Add blank line in report after URL if we had errors
            #
            Validator_GUI_Update_Results($interop_tab, "");
        }
    }
}

#***********************************************************************
#
# Name: Perform_Content_Check
#
# Parameters: url - document URL
#             mime_type - document mime type
#             content - document content
#
# Description:
#
#   This function performs a number of QA tests on the content.
#
#***********************************************************************
sub Perform_Content_Check {
    my ( $url, $mime_type, $content ) = @_;

    my ($url_status, $key, $status, $message);
    my (@content_results_list, $result_object, $output_line, $error_message);
    my (%local_error_url_count, @headings);

    #
    # Are we displaying content checks ? If not we can skip them.
    #
    if ( ! $display_content_check ) {
        print "Not performing content checks\n" if $debug;
        return;
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip content check\n" if $debug;
        Increment_Counts_and_Print_URL($content_tab, $url, 0);
    }
    else {
        #
        # Check the document
        #
        print "Perform_Content_Check on URL\n  --> $url\n" if $debug;
        @content_results_list = Content_Check($url, $content_check_profile,
                                              $mime_type, $content);

        #
        # Get list of headings from the document and save them in a
        # global table indexed by URL
        #
        if ( $mime_type =~ /text\/html/ ) {
            @headings = Content_Check_Get_Headings();
            $headings_table{$url} = \@headings;
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@content_results_list ) {
            if ( $result_object->status != 0 ) {
                #
                # Content Check error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($content_tab, $url,
                                       ($url_status != $tool_success));

        #
        # Print results if it is a failure.
        #
        if ( $url_status != $tool_success ) {
            foreach $result_object (@content_results_list ) {
                if ( $result_object->status != 0 ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($content_error_instance_count{$result_object->description}) ) {
                        $content_error_instance_count{$result_object->description} = 1;
                        $content_error_url_count{$result_object->description} = 1;
                    }
                    else {
                       $content_error_instance_count{$result_object->description}++;
                       $content_error_url_count{$result_object->description}++;
                    }

                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($content_tab, $result_object);
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Perform_Feature_Check
#
# Parameters: url - document URL
#             mime_type - mime_type of content
#             content - document content
#
# Description:
#
#   This function runs the document feature check tool on the
# supplied content.
#
#***********************************************************************
sub Perform_Feature_Check {
    my ( $url, $mime_type, $content ) = @_;

    my (%html_feature_line_no, %html_feature_column_no,
        %html_feature_count, $key, $list_ref);

    #
    # If we are not going to display document feaures, we wont
    # collect them.
    #
    if ( ! $display_doc_features ) {
        print "Not performing document features check\n" if $debug;
        return;
    }
    
    #
    # Is this URL archived on the web ? if it is we don't
    # report any document features
    #
    print "Perform_Feature_Check on URL\n  --> $url\n" if $debug;
    if ( $is_archived ) {
        #
        # Save "Archived on the Web" feature
        #
        $key = "archive";
        if ( defined($docl_feature_list{$key}) ) {
            $list_ref = $docl_feature_list{$key};
            print "Add to document feature list $key, url = $url\n" if $debug;
            $$list_ref{$url} = 1;
        }
    }
    else {
        #
        # Check HTML document
        #
        if ( $mime_type =~ /text\/html/ ) {
            HTML_Feature_Check($url, $current_doc_features_profile,
                      \%html_feature_line_no, \%html_feature_column_no,
                      \%html_feature_count, $content);

            #
            # Check links from document for special mime-types (e.g. multimedia)
            #
            HTML_Features_Check_Links($url, $current_doc_features_profile,
                      \%html_feature_line_no, \%html_feature_column_no,
                      \%html_feature_count, @links);

            #
            # Check metadata features.
            #
            HTML_Feature_Metadata_Check($url, $current_doc_features_profile,
                      \%html_feature_line_no, \%html_feature_column_no,
                      \%html_feature_count, $content);
        }
        #
        # Check PDF document
        #
        elsif ( $mime_type =~ /application\/pdf/ ) {
            PDF_Check_Features($url, $current_doc_features_profile,
                               \%html_feature_line_no, \%html_feature_column_no,
                               \%html_feature_count, $content);
        }

        #
        # Save feature counts
        #
        foreach $key (sort keys %html_feature_count ) {
            #
            # Save URL containing HTML Feature
            #
            $list_ref = $docl_feature_list{$key};
            if ( ! defined($list_ref) ) {
                my (%new_docl_feature_list);
                print "Create document feature list $key\n" if $debug;
                $docl_feature_list{$key} = \%new_docl_feature_list;
                $list_ref = \%new_docl_feature_list;
            }
            print "Add to document feature list $key, url = $url\n" if $debug;
            $$list_ref{$url} = $html_feature_count{$key};
        }
        
        if ( $debug) {
            print "docl_feature_list\n";
            foreach $key (sort(keys(%docl_feature_list))) {
                print "key = $key\n";
            }
        }
    }
}

#***********************************************************************
#
# Name: Perform_Link_Check
#
# Parameters: url - url of document to check
#             mime_type - mime-type of document
#             resp - HTTP::Response object
#
# Description:
#
#   This function runs the link checker on the URL
#
#***********************************************************************
sub Perform_Link_Check {
    my ( $url, $mime_type, $resp ) = @_;

    my ($url_status, $format, $message, $content, @link_results_list);
    my ($n_links, $i, $language, $status, $output_line, $link);
    my ($result_object, $base, %local_link_error_url_count);
    my ($error_message) = "";

    #
    # If we are in CGI mode, skip link checks
    #
    if ( $cgi_mode ) {
        return;
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip link check\n" if $debug;
        Increment_Counts_and_Print_URL($link_tab, $url, 0);
    }
    else {
        #
        # Check for UTF-8 content
        #
        $content = Crawler_Decode_Content($resp);

        #
        # Is this an HTML document ?
        #
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Get document language.
            #
            $language = HTML_Document_Language($url, $content);
        }
        #
        # Is it CSS ?
        #
        elsif ( $mime_type =~ /text\/css/ ) {
            #
            # Language is unknown and does not matter
            #
            $language = "";
        }
        #
        # Is it PDF ?
        #
        elsif ( $mime_type =~ /application\/pdf/ ) {
            #
            # Get document language.
            #
            $language = URL_Check_GET_URL_Language($url);
        }

        #
        # Determine the abse URL for any relative URLs.  Usually this is
        # the base field from the HTTP Response object (Location field 
        # in HTTP packet).  If the response code is 200 (OK), we don't use the
        # the base field in case the Location field is set (which it should 
        # not be).
        #
        if ( $resp->code == 200 ) {
            $base = $url;
        }
        else {
            $base = $resp->base;
        }

        #
        # Get links from document, save list in the global @links variable.
        # We need the list of links (and mime-types) in the document features
        # check.
        #
        print "Extract links from document\n  --> $url\n" if $debug;
        @links = Extract_Links($url, $base, $language, $mime_type, $content);
        
        #
        # Get links from all document subsections
        #
        %all_link_sets = Extract_Links_Subsection_Links("ALL");

        #
        # If we are not displaying Link Check results, we can return here.
        # No need to spend time to check links.
        #
        if ( ! $display_link_check ) {
            print "Not performing Link Check\n" if $debug;
            return;
        }

        #
        # Check links
        #
        print "Check links in URL\n  --> $url\n" if $debug;
        @link_results_list = Link_Checker($url, $language, $link_check_profile,
                                          \@links);

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $link (@link_results_list) {
            if ( $link->status != $tool_success ) {
                #
                # Link error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($link_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results if it is a failure.
        #
        if ( $url_status == $tool_error ) {
            if ( $display_link_check ) {
                #
                # Link check failed, set Other Tool Results (to be passed
                # to CLF Check).
                #
                $clf_other_tool_results{"link check"} = 1;

                #
                # Print failures
                #
                foreach $result_object (@link_results_list) {
                    $status = $result_object->status;
                    if ( defined($status) && ($status != 0) ) {
                        #
                        # Increment error instance count
                        #
                        if ( ! defined($link_error_instance_count{$result_object->description}) ) {
                            $link_error_instance_count{$result_object->description} = 1;
                        }
                        else {
                            $link_error_instance_count{$result_object->description}++;
                        }

                        #
                        # Set URL error count
                        #
                        $local_link_error_url_count{$result_object->description} = 1;

                        #
                        # Print error
                        #
                        Validator_GUI_Print_TQA_Result($link_tab, $result_object);
                    }
                }

                #
                # Add blank line in report
                #
                Validator_GUI_Update_Results($link_tab, "");
            }
        }
        else {
            #
            # Link check passed, set Other Tool Results (to be passed
            # to TQA Check).
            #
            $clf_other_tool_results{"link check"} = 0;
        }

        #
        # Set global URL error count
        #
        foreach (keys %local_link_error_url_count) {
            $link_error_url_count{$_}++;
        }

        #
        # Scan the list of links for image links.  Add information such as
        # alt text and title to the list of image links.
        #
        if ( $display_content_check ) {
            Alt_Text_Check_Record_Image_Details(\%image_alt_text_table, $url,
                                                @links);
        }
    }
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Signal handling when forking
#
$SIG{INT} = sub { die };
#$SIG{SEGV} = 'IGNORE';
$|=1; #buffering a bad idea when fork()ing

#
# Process any optional arguments
#
while ( @ARGV > 0 ) {
    if ( $ARGV[0] eq "-cgi" ) {
        $cgi_mode = 1;
        $ui_pm_dir = "CGI"
    }
    elsif ( $ARGV[0] eq "-cli" ) {
        $cli_mode = 1;
        $ui_pm_dir = "CLI"
    }
    elsif ( $ARGV[0] eq "-content" ) {
        $content_mode = 1;
    }
    elsif ( $ARGV[0] eq "-debug" ) {
        $debug = 1;
        $command_line_debug = 1;
    }
    elsif ( $ARGV[0] eq "-eng" ) {
        $lang = "eng";
    }
    elsif ( $ARGV[0] eq "-fra" ) {
        $lang = "fra";
    }
    elsif ( $ARGV[0] eq "-no_acc" ) {
        $display_tqa_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_clf" ) {
        $display_clf_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_cont" ) {
        $display_content_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_feat" ) {
        $display_doc_features = 0;
    }
    elsif ( $ARGV[0] eq "-no_interop" ) {
        $display_interop_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_link" ) {
        $display_link_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_meta" ) {
        $display_metadata_check = 0;
    }
    elsif ( $ARGV[0] eq "-no_url" ) {
        $display_document_list = 0;
    }
    elsif ( $ARGV[0] eq "-no_val" ) {
        $display_validation = 0;
    }
    else {
        #
        # Unknown argument, save it in the ui_args array
        #
        push(@ui_args, $ARGV[0]);
        print "Push " . $ARGV[0] . " onto UI arguments list\n" if $debug;
    }

    shift;
}

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
# Perform program initialization
#
Initialize;

#
# Get report option labels
#
$link_check_profile_label = String_Value("Link Check Profile");
$metadata_profile_label = String_Value("Metadata Profile");
$pdf_property_profile_label = String_Value("PDF Property Profile");
$tqa_profile_label = String_Value("ACC Testcase Profile");
$clf_profile_label = String_Value("CLF Testcase Profile");
$interop_profile_label = String_Value("Interop Testcase Profile");
$content_check_profile_label = String_Value("Content Check Testcase Profile");
$doc_profile_label = String_Value("Document Features Profile");
$robots_label = String_Value("robots.txt handling");
@robots_options = (String_Value("Ignore robots.txt"),
                   String_Value("Respect robots.txt"));
$status_401_label = String_Value("401 handling");
@status_401_options = (String_Value("Ignore"),
                       String_Value("Prompt for credentials"));
%report_options = ($link_check_profile_label, \@link_check_profiles,
                   $metadata_profile_label, \@metadata_profiles,
                   $pdf_property_profile_label, \@pdf_property_profiles,
                   $tqa_profile_label, \@tqa_check_profiles,
                   $clf_profile_label, \@clf_check_profiles,
                   $interop_profile_label, \@interop_check_profiles,
                   $content_check_profile_label, \@content_check_profiles,
                   $doc_profile_label, \@doc_features_profiles,
                   $robots_label, \@robots_options,
                   $status_401_label, \@status_401_options);
%report_options_labels = ("metadata_profile", $metadata_profile_label,
                          "pdf_profile", $pdf_property_profile_label,
                          "tqa_profile", $tqa_profile_label,
                          "clf_profile", $clf_profile_label,
                          "interop_profile", $interop_profile_label,
                          "content_profile", $content_check_profile_label,
                          "html_profile", $doc_profile_label,
                          "robots_handling", $robots_label,
                          "401_handling", $status_401_label);

#
# Setup the validator GUI
#
Validator_GUI_Report_Option_Labels(%report_options_labels);

#
# Get label for the various result tabs and the file suffix when saving results
#
$crawled_urls_tab = String_Value("Crawled URLs");
$results_file_suffixes{$crawled_urls_tab} = "crawl";
if ( $display_validation )  {
    $validation_tab = String_Value("Validation");
    $results_file_suffixes{$validation_tab} = "val";
}
if ( $display_link_check )  {
    $link_tab = String_Value("Link");
    $results_file_suffixes{$link_tab} = "link";
}
if ( $display_metadata_check )  {
    $metadata_tab = String_Value("Metadata");
    $results_file_suffixes{$metadata_tab} = "meta";
}
if ( $display_tqa_check )  {
    $acc_tab = String_Value("ACC");
    $results_file_suffixes{$acc_tab} = "acc";
}
if ( $display_clf_check )  {
    $clf_tab = String_Value("CLF");
    $results_file_suffixes{$clf_tab} = "clf";
}
if ( $display_interop_check )  {
    $interop_tab = String_Value("INT");
    $results_file_suffixes{$interop_tab} = "int";
}
if ( $display_content_check )  {
    $content_tab = String_Value("Content");
    $results_file_suffixes{$content_tab} = "cont";
}
if ( $display_doc_features )  {
    $doc_features_tab = String_Value("Document Features");
    $results_file_suffixes{$doc_features_tab} = "feat";
}
if ( $display_document_list )  {
    $doc_list_tab = String_Value("Document List");
    $results_file_suffixes{$doc_list_tab} = "urls";
}

#
# Set results file suffixes
#
Validator_GUI_Set_Results_File_Suffixes(%results_file_suffixes);

#
# Setup the validator GUI
#
Validator_GUI_Setup($lang, \&Direct_HTML_Input_Callback,
                    \&Perform_Site_Crawl, \&URL_List_Callback,
                    %report_options);

#
# Add result tabs
#
Validator_GUI_Add_Results_Tab($crawled_urls_tab);
if ( $display_validation ) {
    Validator_GUI_Add_Results_Tab($validation_tab);
}
if ( $display_link_check ) {
    Validator_GUI_Add_Results_Tab($link_tab);
}
if ( $display_metadata_check ) {
    Validator_GUI_Add_Results_Tab($metadata_tab);
}
if ( $display_tqa_check ) {
    Validator_GUI_Add_Results_Tab($acc_tab);
}
if ( $display_clf_check ) {
    Validator_GUI_Add_Results_Tab($clf_tab);
}
if ( $display_interop_check ) {
    Validator_GUI_Add_Results_Tab($interop_tab);
}
if ( $display_content_check ) {
    Validator_GUI_Add_Results_Tab($content_tab);
}
if ( $display_doc_features ) {
    Validator_GUI_Add_Results_Tab($doc_features_tab);
}
if ( $display_document_list ) {
    Validator_GUI_Add_Results_Tab($doc_list_tab);
}

#
# Set Results Save callback function
#
Validator_GUI_Set_Results_Save_Callback(\&Results_Save_Callback);

#
# Start the GUI
#
eval { Validator_GUI_Start(@ui_args); };

print "Exit WPSS Tool\n" . $@ . "\n" if $debug;
exit(0);
