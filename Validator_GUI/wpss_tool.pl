#!/usr/bin/perl
#!/opt/common/perl/bin/perl
#***********************************************************************
#
# Name:   wpss_tool.pl
#
# $Revision: 2168 $
# $URL: svn://10.36.148.185/WPSS_Tool/Validator_GUI/Tools/wpss_tool.pl $
# $Date: 2021-10-14 16:02:24 -0400 (Thu, 14 Oct 2021) $
#
# Synopsis: wpss_tool.pl [ -debug ] [ -cgi ] [ -cli ] [ -fra ] [ -eng ]
#                        [ -xml ] [ -open_data ] [ -monitor ] [ -no_login ]
#                        [ -disable_generated_markup ] [ -report_passes_only ]
#
# Where: -debug enables program debugging.
#        -fra use French interface
#        -eng use English interface
#        -cgi enter CGI mode
#        -cli enter Command Line mode
#        -xml generate XML output
#        -open_data run tool for open data files rather than web files
#        -monitor enable program resource usage monitoring
#        -no_login don't prompt for firewall login
#        -disable_generated_markup don't get generated source markup
#        -report_passes_only option to report only passes
#
# Description:
#
#   This program is a Windows GUI for the WPSS QA tools.  It allows a
# user to analyse an entire site, a list of URLs or paste in HTML code.
# It runs a number of checks against web pages;
#  - markup validation
#  - link checking
#  - metadata checking
#  - accessibility (WCAG 2.0) checking
#  - look and feel (e.g. CLF, web usability, canada.ca)
#  - interoperability
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

use FindBin;                      # locate this script
use lib "$FindBin::RealBin/lib";  # use the lib directory
use lib "$FindBin::RealBin/lib/perl5";  # use the perl5 directory

#
# Check for module to share data structures between threads
#
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
use Archive::Zip;
use File::Temp qw/ tempfile tempdir /;
use Digest::SHA;

#
# Use WPSS_Tool program modules
#
use alt_text_check;
use clf_check;
use content_check;
use content_sections;
use crawler;
use css_check;
use css_validate;
use dept_check;
use epub_check;
use epub_validate;
use extract_anchors;
use extract_links;
use html_features;
use html_language;
use html_validate;
use interop_check;
use javascript_validate;
use link_checker;
use metadata;
use metadata_result_object;
use mobile_check;
use open_data_check;
use pdf_check;
use pdf_files;
use readability;
use robots_check;
use textcat;
use tqa_check;
use wpss_strings;
use tqa_result_object;
use tqa_testcases;
use url_check;
use validate_markup;
use web_analytics_check;

use strict;


#***********************************************************************
#
# Program global variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f);
my ($url, $report_fails_only, %crawler_config_vars, $datetime_stamp);
my ($this_tab, $lang, %is_valid_markup, $process_pdf);
my (%login_form_values, $performed_login, %link_config_vars);
my (@crawler_link_ignore_patterns, %document_count, %error_count);
my (%fault_count, $user_agent_hostname, %url_list, $version);
my (@links, @ui_args, %image_alt_text_table, @web_feed_list);
my (%all_link_sets, %domain_prod_dev_map, @all_urls, $logged_in);
my ($loginpagee, $logoutpagee, $loginpagef, $logoutpagef);
my ($loginformname, $logininterstitialcount, $logoutinterstitialcount);
my ($firewall_check_url, $maximum_errors_per_url);
my ($enable_generated_markup, $cmnd_line_disable_generated_markup);
my (%gui_config, %epub_file_count, %tab_reported_doc_count);
my (%epub_error_count);
my ($report_passes_only) = 0;
my ($ui_pm_dir) = "GUI";
my ($no_login_mode) = 0;

#
# Shared variables for use between treads
#
my ($shared_image_alt_text_report, $shared_file_details_filename);
my ($shared_site_dir_e, $shared_site_dir_f);
my ($shared_headings_report, $shared_web_page_size_filename);
my ($shared_save_content, $shared_save_content_directory);
my ($shared_testcase_results_summary_csv_filename);
my ($shared_links_details_filename);
if ( $have_threads ) {
    share(\$shared_image_alt_text_report);
    share(\$shared_site_dir_e);
    share(\$shared_site_dir_f);
    share(\$shared_headings_report);
    share(\$shared_web_page_size_filename);
    share(\$shared_file_details_filename);
    share(\$shared_save_content);
    share(\$shared_save_content_directory);
    share(\$shared_testcase_results_summary_csv_filename);
    share(\$shared_links_details_filename);
}

#
# Content saving variables
#
my ($content_file) = 0;

#
# Save image file details in inventory
#
my ($save_image_file_details_in_inventory) = 0;

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
my ($open_data_mode) = 0;

my ($debug) = 0;
my ($monitoring) = 0;
my ($monitoring_file_name);
my ($command_line_debug) = 0;
my ($max_urls_between_sleeps) = 2;
my ($user_agent_name) = "wpss_test.pl";

my (%report_options, %results_file_suffixes, @active_results_tabs);
my ($crawled_urls_tab, $validation_tab, $metadata_tab, $doc_list_tab,
    $acc_tab, $link_tab, $dept_tab, $doc_features_tab, $mobile_tab,
    $clf_tab, $interop_tab, $open_data_tab, $content_tab, $crawllimit);
my (@csv_summary_results_fields) = ("type", "SC", "tc label", "tcid", "URL count", "Error count", "Help URL");

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
# Markup validate check variables
#
my (@markup_validate_profiles, %markup_validate_profile_map);
my (%markup_validate_profiles_languages, $markup_validate_profile_label);
my ($markup_validate_profile);

#
# Link check variables
#
my (@link_check_profiles, $link_check_profile, $link_check_profile_label);
my ($link_testcase_url_help_file_name, %link_check_profile_map);
my (%link_check_profiles_languages);
my (%networkscope_map, %domain_alias_map, %link_check_config);
my (@redirect_ignore_patterns, @link_ignore_patterns);
my (%link_error_url_count, %link_error_instance_count);

#
# PDF Check Variables
#
my (@pdf_property_profiles, $pdf_property_profile_label, %pdf_property_results);
my (%pdf_property_profile_tag_required_map,
    %pdf_property_profile_content_required_map,
    $pdf_property_profile, %pdf_property_profiles_languages);

#
# Metadata Check Variables
#
my (@metadata_profiles, $metadata_profile_label);
my (%metadata_profile_tag_required_map,
    %metadata_profile_content_required_map,
    %metadata_profile_content_type_map,
    %metadata_profile_scheme_values_map,
    %metadata_profile_invalid_content_map,
    $metadata_profile,
    %metadata_profiles_languages);
my (%metadata_error_url_count, %metadata_error_instance_count);
my (%metadata_help_url, %metadata_results);

#
# Department testcases Check variables
#
my (%dept_check_profile_map, $dept_check_profile);
my (@dept_check_profiles, $dept_check_profile_label);
my (%html_titles, %pdf_titles, %title_html_url);
my (%dept_error_url_count, %dept_error_instance_count);
my ($dept_testcase_url_help_file_name);
my (%headings_table, %content_section_markers);
my (%dept_check_profiles_languages);

#
# TQA Check variables
#
my (%tqa_check_profile_map, %tqa_testcase_data);
my (@tqa_check_profiles, $tqa_profile_label, $tqa_check_profile);
my (%tqa_error_url_count, %tqa_error_instance_count);
my ($tqa_testcase_url_help_file_name, %site_navigation_links);
my (%decorative_images,%non_decorative_images);
my (@decorative_image_urls, @non_decorative_image_urls);
my (%tqa_testcase_profile_types);
my ($tqa_check_exempted, %tqa_check_profiles_languages);

#
# Layout and design Check variables
#
my (%clf_check_profile_map);
my (@clf_check_profiles, $clf_profile_label, $clf_check_profile);
my (%clf_error_url_count, %clf_error_instance_count);
my ($clf_testcase_url_help_file_name, %clf_other_tool_results);
my ($is_archived, %clf_site_links, %clf_check_profiles_languages);

#
# Standard on Privacy and Web Analytics variables
#
my (%wa_check_profile_map);
my (@wa_check_profiles, $wa_profile_label, $wa_check_profile);
my ($wa_testcase_url_help_file_name, %wa_check_profiles_languages);

#
# Interoperability Check variables
#
my (%interop_check_profile_map);
my (@interop_check_profiles, $interop_profile_label, $interop_check_profile);
my (%interop_error_url_count, %interop_error_instance_count);
my ($interop_testcase_url_help_file_name, %interop_check_profiles_languages);

#
# Open Data Check variables
#
my (%open_data_check_profile_map, @open_data_check_profiles);
my ($open_data_profile_label, $open_data_check_profile);
my (%open_data_error_url_count, %open_data_error_instance_count);
my ($open_data_testcase_url_help_file_name, %open_data_dictionary);
my (@open_data_file_types) = ("DICTIONARY", "DATA", "RESOURCE", "API",
                              "ALTERNATE_DATA");
my (%open_data_check_profiles_languages);
my (@open_data_file_details_fields) = ("type", "url", "mime-type", "sha1 checksum",
                                       "size", "component size", "rows",
                                       "columns", "headings");

#
# Open data content check variables
#
my (%content_error_instance_count, %content_error_url_count);

#
# Document Features variables
#
my (%doc_features_profile_map, %doc_feature_list);
my (@doc_features_profiles, $doc_profile_label, $current_doc_features_profile);
my (%doc_features_metadata_profile_map, @doc_directory_paths);
my (%doc_features_profiles_languages);

#
# Mobile check variables
#
my ($mobile_check_profile, $web_page_size_file_handle);
my (%mobile_check_profile_map, @mobile_check_profiles, $mobile_profile_label);
my (%mobile_error_url_count, %mobile_error_instance_count);
my ($mobile_testcase_url_help_file_name);
my (%mobile_check_profiles_languages);

#
# Web Page Details variables
#
my (@web_page_details_fields) = ("url", "title", "lang", "h1", "breadcrumb",
                                 "archived", "mime-type",
                                 "dcterms.issued", "dcterms.modified",
                                 "dcterms.subject", "dcterms.creator", 
                                 "content size", "flesch-kincaid");
my (%web_page_details_values, $files_details_fh);

#
# Web Page Link Details variables
#
my (@links_details_fields) = ("url", "type", "line", "column", "href");
my ($links_details_fh);

#
# Testcase profile group variables
#
my (@testcase_profile_groups, %testcase_profile_group_map);
my (%testcase_profile_groups_profiles_languages);
my ($testcase_profile_group_label);
my (@od_testcase_profile_groups, %od_testcase_profile_group_map);
my (%od_testcase_profile_groups_profiles_languages);

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
# Name: New_Markup_Validate_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Markup_Validate Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_Markup_Validate_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@markup_validate_profiles, $profile_name);
    $markup_validate_profile_map{$profile_name} = \%testcases;
    $markup_validate_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_Markup_Validate_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Markup_Validate Check configuration file.
#
#***********************************************************************
sub Read_Markup_Validate_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($markup_validate_profile_name, $profile_type, $other_profile_name);
    my (@profile_names, $exemption_type, $exemption_value);
    my (@alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Markup_Validate_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
            undef(@profile_names);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Markup_Validate_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $markup_validate_profile_name = $fields[1];
            push(@profile_names, $markup_validate_profile_name);
            ($testcases) =
                New_Markup_Validate_Check_Profile_Hash_Tables($markup_validate_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $markup_validate_profile_map{$other_profile_name} = $testcases;
                $markup_validate_profiles_languages{$other_profile_name} = $markup_validate_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Markup_Validate_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            push(@profile_names, $other_profile_name);
            if ( defined($testcases) ) {
                $markup_validate_profile_map{$other_profile_name} = $testcases;
                $markup_validate_profiles_languages{$other_profile_name} = $markup_validate_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required Markup_Validate testcase, get testcase id and store
            # in hash table.
            #
            $testcase_id = $fields[1];
            if ( defined($testcase_id) ) {
                $$testcases{$testcase_id} = 1;
            }
        }
    }
    close(CONFIG_FILE);
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
    $doc_features_profiles_languages{$profile_name} = $profile_name;

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
    my (@alternate_lang_profiles);

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
    binmode CONFIG_FILE;

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "HTML_Features_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($feature_list);
            undef($metadata_feature_list);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "HTML_Features_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $html_features_profile_name = $fields[1];
            ($feature_list, $metadata_feature_list) =
                New_HTML_Features_Profile_Hash_Table($html_features_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $doc_features_profile_map{$other_profile_name} = $feature_list;
                $doc_features_metadata_profile_map{$other_profile_name} = $metadata_feature_list;
                $doc_features_profiles_languages{$other_profile_name} = $html_features_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "HTML_Features_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($feature_list) ) {
                $doc_features_profile_map{$other_profile_name} = $feature_list;
                $doc_features_metadata_profile_map{$other_profile_name} = $metadata_feature_list;
                $doc_features_profiles_languages{$other_profile_name} = $html_features_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
        elsif ( $config_type =~ /doc_directory_path/i ) {
           #
           # Alternate format documents directory path
           #
           @fields = split(/\s+/, $_, 2);
           $feature_id = $fields[1];
           push(@doc_directory_paths, $feature_id);
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
    $metadata_profiles_languages{$profile_name} = $profile_name;

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
    my ($other_profile_name, $url, @alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Metadata_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($tag_required);
            undef($content_required);
            undef($content_type);
            undef($scheme_values);
            undef($invalid_content);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Metadata_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $metadata_profile_name = $fields[1];
            ($tag_required, $content_required, $content_type, $scheme_values,
             $invalid_content) =
                New_Metadata_Profile_Hash_Tables($metadata_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $metadata_profile_tag_required_map{$other_profile_name} = $tag_required;
                $metadata_profile_content_required_map{$other_profile_name} = $content_required;
                $metadata_profile_content_type_map{$other_profile_name} = $content_type;
                $metadata_profile_scheme_values_map{$other_profile_name} = $scheme_values;
                $metadata_profile_invalid_content_map{$other_profile_name} = $invalid_content;
                $metadata_profiles_languages{$other_profile_name} = $metadata_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Metadata_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($tag_required) ) {
                $metadata_profile_tag_required_map{$other_profile_name} = $tag_required;
                $metadata_profile_content_required_map{$other_profile_name} = $content_required;
                $metadata_profile_content_type_map{$other_profile_name} = $content_type;
                $metadata_profile_scheme_values_map{$other_profile_name} = $scheme_values;
                $metadata_profile_invalid_content_map{$other_profile_name} = $invalid_content;
                $metadata_profiles_languages{$other_profile_name} = $metadata_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
            # Set the thesaurus filename for this language and scheme
            #
            Set_Metadata_Thesaurus_File($scheme, $filename, $thesaurus_language);
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
    $pdf_property_profiles_languages{$profile_name} = $profile_name;

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
    my ($profile_name, $other_profile_name, @alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Property_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($tag_required);
            undef($content_required);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Property_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $profile_name = $fields[1];
            ($tag_required, $content_required) =
                New_PDF_Properties_Profile_Hash_Tables($profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $pdf_property_profile_tag_required_map{$other_profile_name} = $tag_required;
                $pdf_property_profile_content_required_map{$other_profile_name} = $content_required;
                $pdf_property_profiles_languages{$other_profile_name} = $profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Property_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($tag_required) ) {
                $pdf_property_profile_tag_required_map{$other_profile_name} = $tag_required;
                $pdf_property_profile_content_required_map{$other_profile_name} = $content_required;
                $pdf_property_profiles_languages{$other_profile_name} = $profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
    $tqa_check_profiles_languages{$profile_name} = $profile_name;

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
    my (@alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "TQA_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
            undef(@profile_names);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "TQA_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $tqa_check_profile_name = $fields[1];
            push(@profile_names, $tqa_check_profile_name);
            ($testcases) =
                New_TQA_Check_Profile_Hash_Tables($tqa_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $tqa_check_profile_map{$other_profile_name} = $testcases;
                $tqa_check_profiles_languages{$other_profile_name} = $tqa_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "TQA_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            push(@profile_names, $other_profile_name);
            if ( defined($testcases) ) {
                $tqa_check_profile_map{$other_profile_name} = $testcases;
                $tqa_check_profiles_languages{$other_profile_name} = $tqa_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /TQA_Check_Profile_Type/i ) {
            #
            # Profile type value.
            #
            $profile_type = $fields[1];
            foreach $other_profile_name (@profile_names) {
                $tqa_testcase_profile_types{$other_profile_name} = $profile_type;
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
            $value =~ s/\s+$//g;

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
    $clf_check_profiles_languages{$profile_name} = $profile_name;

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
    my ($archived_value, @alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "CLF_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "CLF_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $clf_check_profile_name = $fields[1];
            ($testcases) =
                New_CLF_Check_Profile_Hash_Tables($clf_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $clf_check_profile_map{$other_profile_name} = $testcases;
                $clf_check_profiles_languages{$other_profile_name} = $clf_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "CLF_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $clf_check_profile_map{$other_profile_name} = $testcases;
                $clf_check_profiles_languages{$other_profile_name} = $clf_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
                $value =~ s/\s+$//g;
                Set_CLF_Check_Testcase_Data($clf_check_profile_name, $testcase_id, $value);
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
# Name: New_WA_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for WA Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_WA_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@wa_check_profiles, $profile_name);
    $wa_check_profile_map{$profile_name} = \%testcases;
    $wa_check_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_WA_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a WA Check configuration file.
#
#***********************************************************************
sub Read_WA_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($wa_check_profile_name, $other_profile_name, @alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Web_Analytics_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Web_Analytics_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $wa_check_profile_name = $fields[1];
            ($testcases) =
                New_WA_Check_Profile_Hash_Tables($wa_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $wa_check_profile_map{$other_profile_name} = $testcases;
                $wa_check_profiles_languages{$other_profile_name} = $wa_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Web_Analytics_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $wa_check_profile_map{$other_profile_name} = $testcases;
                $wa_check_profiles_languages{$other_profile_name} = $wa_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required WA testcase, get testcase id and store
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
            if ( defined($wa_check_profile_name) && defined($value) ) {
                $value =~ s/\s+$//g;
                Set_WA_Check_Testcase_Data($wa_check_profile_name, $testcase_id, $value);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $wa_testcase_url_help_file_name = $fields[1];
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
    $link_check_profiles_languages{$profile_name} = $profile_name;

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
    my ($archived_value, @alternate_lang_profiles);

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
        # Start of a new Link testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Link_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new Link testcase profile. Get hash tables to
        # store Link Check attributes
        #
        if ( $config_type eq "Link_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $link_check_profile_name = $fields[1];
            ($testcases) =
                New_Link_Check_Profile_Hash_Tables($link_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $link_check_profile_map{$other_profile_name} = $testcases;
                $link_check_profiles_languages{$other_profile_name} = $link_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Link_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $link_check_profile_map{$other_profile_name} = $testcases;
                $link_check_profiles_languages{$other_profile_name} = $link_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
    $interop_check_profiles_languages{$profile_name} = $profile_name;

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
    my (@alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Interop_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Interop_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $interop_check_profile_name = $fields[1];
            ($testcases) =
                New_Interop_Check_Profile_Hash_Tables($interop_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $interop_check_profile_map{$other_profile_name} = $testcases;
                $interop_check_profiles_languages{$other_profile_name} = $interop_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Interop_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $interop_check_profile_map{$other_profile_name} = $testcases;
                $interop_check_profiles_languages{$other_profile_name} = $interop_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
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
                $value =~ s/\s+$//g;
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
# Name: New_Mobile_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Mobileerability Check test cases
# and saves the address in the global test case profile table.
#
#***********************************************************************
sub New_Mobile_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@mobile_check_profiles, $profile_name);
    $mobile_check_profile_map{$profile_name} = \%testcases;
    $mobile_check_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}


#***********************************************************************
#
# Name: Read_Mobile_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Mobileerability Check configuration file.
#
#***********************************************************************
sub Read_Mobile_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($mobile_check_profile_name, $other_profile_name);
    my (@alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Mobile_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Mobile_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $mobile_check_profile_name = $fields[1];
            ($testcases) =
                New_Mobile_Check_Profile_Hash_Tables($mobile_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $mobile_check_profile_map{$other_profile_name} = $testcases;
                $mobile_check_profiles_languages{$other_profile_name} = $mobile_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Mobile_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $mobile_check_profile_map{$other_profile_name} = $testcases;
                $mobile_check_profiles_languages{$other_profile_name} = $mobile_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required Mobileerability testcase, get testcase id and store
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
            if ( defined($mobile_check_profile_name) && defined($value) ) {
                $value =~ s/\s+$//g;
                Set_Mobile_Check_Testcase_Data($mobile_check_profile_name,
                                               $testcase_id, $value);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $mobile_testcase_url_help_file_name = $fields[1];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Dept_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for department Check test cases
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_Dept_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@dept_check_profiles, $profile_name);
    $dept_check_profile_map{$profile_name} = \%testcases;
    $dept_check_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_Dept_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a Department Check configuration file.
#
#***********************************************************************
sub Read_Dept_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $testcases);
    my ($dept_check_profile_name, $value, @alternate_lang_profiles);
    my ($other_profile_name);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Dept_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Dept_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $dept_check_profile_name = $fields[1];
            ($testcases) =
                New_Dept_Check_Profile_Hash_Tables($dept_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $dept_check_profile_map{$other_profile_name} = $testcases;
                $dept_check_profiles_languages{$other_profile_name} = $dept_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Dept_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $dept_check_profile_map{$other_profile_name} = $testcases;
                $dept_check_profiles_languages{$other_profile_name} = $dept_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
           #
           # Department testcase, get testcase id and store
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
            $dept_testcase_url_help_file_name = $fields[1];
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
            if ( defined($dept_check_profile_name) && defined($value) ) {
                $value =~ s/\s+$//g;
                Set_Dept_Check_Testcase_Data($dept_check_profile_name,
                                             $testcase_id, $value);
            }
        }
    }
    close(CONFIG_FILE);
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

    my (@fields, $config_type);
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

        if ( $config_type =~ /CONTENT_SECTION_START/i ) {
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
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Open_Data_Check_Profile_Hash_Tables
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for Open Data Check test cases
# and saves the address in the global test case profile table.
#
#***********************************************************************
sub New_Open_Data_Check_Profile_Hash_Tables {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@open_data_check_profiles, $profile_name);
    $open_data_check_profile_map{$profile_name} = \%testcases;
    $open_data_check_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: Read_Open_Data_Check_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads an Open Data  Check configuration file.
#
#***********************************************************************
sub Read_Open_Data_Check_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, $testcase_id, $value, $testcases);
    my ($open_data_check_profile_name, $other_profile_name);
    my (@alternate_lang_profiles);

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Open_Data_Check_Profile_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Start of a new testcase profile. Get hash tables to
        # store attributes
        #
        if ( $config_type eq "Open_Data_Check_Profile_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $open_data_check_profile_name = $fields[1];
            ($testcases) =
                New_Open_Data_Check_Profile_Hash_Tables($open_data_check_profile_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $open_data_check_profile_map{$other_profile_name} = $testcases;
                $open_data_check_profiles_languages{$other_profile_name} = $open_data_check_profile_name;
            }
        }
        #
        # Alternate language label for this profile
        #
        elsif ( $config_type =~ "Open_Data_Check_Profile_" ) {
            #
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $open_data_check_profile_map{$other_profile_name} = $testcases;
                $open_data_check_profiles_languages{$other_profile_name} = $open_data_check_profile_name;
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
        }
        elsif ( $config_type =~ /tcid/i ) {
            #
            # Required Open Data testcase, get testcase id and store
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
            if ( defined($open_data_check_profile_name) && defined($value) ) {
                $value =~ s/\s+$//g;
                Set_Open_Data_Check_Testcase_Data($testcase_id, $value);
            }
        }
        elsif ( $config_type =~ /Testcase_URL_Help_File/i ) {
            #
            # Name of testcase & help URL file
            #
            $open_data_testcase_url_help_file_name = $fields[1];
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: New_Testcase_Profile_Group_Hash_Table
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for testcase profile groups
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_Testcase_Profile_Group_Hash_Table {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@testcase_profile_groups, $profile_name);
    $testcase_profile_group_map{$profile_name} = \%testcases;
    $testcase_profile_groups_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
}

#***********************************************************************
#
# Name: New_OD_Testcase_Profile_Group_Hash_Table
#
# Parameters: profile_name - name of profile
#
# Description:
#
#   This function create a hash tables for testcase profile groups
# and saves the address in the global test case profile
# table.
#
#***********************************************************************
sub New_OD_Testcase_Profile_Group_Hash_Table {
    my ($profile_name) = @_;

    my (%testcases);

    #
    # Save address of hash tables
    #
    push(@od_testcase_profile_groups, $profile_name);
    $od_testcase_profile_group_map{$profile_name} = \%testcases;
    $od_testcase_profile_groups_profiles_languages{$profile_name} = $profile_name;

    #
    # Return addresses
    #
    return(\%testcases);
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

    my (@fields, $config_type, @alternate_lang_profiles, $testcases);
    my ($other_profile_name, $tc_profile_group_name, $name, $value);
    my ($inside_testcase_group) = 0;

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
        # Start of a new testcase profile. Empty out the alternate
        # language list and testcase hash table address
        #
        if ( $config_type eq "Testcase_Profile_Group_eng" ) {
            undef(@alternate_lang_profiles);
            undef($testcases);
        }

        #
        # Configuration types
        #
        if ( $config_type eq "Crawler_Link_Ignore_Pattern" ) {
            #
            # Save crawler ignore pattern
            #
            if ( @fields > 1 ) {
                push(@crawler_link_ignore_patterns, $fields[1]);
            }
        }
        elsif ( $config_type =~ /Non_Decorative_Image_URL/i ) {
            #
            # List of non-decorative image URLs.
            # Check non decorative tag first since the decorative
            # tag is a substring of this tag.
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
        elsif ( $config_type eq "default_windows_chrome_path" ) {
            #
            # Set Windows default chrome browser path value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $crawler_config_vars{"default_windows_chrome_path"} = $fields[1];
            }
            else {
                $crawler_config_vars{"default_windows_chrome_path"} = 0;
            }
        }
        elsif ( $config_type eq "Domain_Alias" ) {
            #
            # Save domain and its alias
            #
            if ( @fields > 2 ) {
                $domain_alias_map{$fields[2]} = $fields[1];
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
        elsif ( $config_type eq "Domain_Prod_Dev" ) {
            #
            # Save production and development domains
            #
            if ( @fields > 2 ) {
                $domain_prod_dev_map{$fields[1]} = $fields[2];
            }
        }
        elsif ( $config_type eq "Firewall_Block_Pattern" ) {
            #
            # Save firewall block pattern
            #
            if ( @fields > 1 ) {
                if ( ! defined($link_config_vars{$config_type}) ) {
                    $link_config_vars{$config_type} = $fields[1];
                }
                else {
                    $link_config_vars{$config_type} .= "\n" . $fields[1];
                }
            }
        }
        elsif ( $config_type eq "Firewall_Check_URL" ) {
            #
            # Save URL value
            #
            if ( @fields > 1 ) {
                $firewall_check_url = $fields[1];
            }
        }
        elsif ( $config_type eq "GUI_DIRECT_HTML_SIZE" ) {
            #
            # Save GUI configuration
            #
            if ( @fields > 1 ) {
                $gui_config{"GUI_DIRECT_HTML_SIZE"} = $fields[1];
            }
        }
        elsif ( $config_type eq "GUI_URL_LIST_SIZE" ) {
            #
            # Save GUI configuration
            #
            if ( @fields > 1 ) {
                $gui_config{"GUI_URL_LIST_SIZE"} = $fields[1];
            }
        }
        elsif ( $config_type eq "Link_Ignore_Pattern" ) {
            #
            # Save link check ignore pattern
            #
            if ( @fields > 1 ) {
                push(@link_ignore_patterns, $fields[1]);
            }
        }
        elsif ( $config_type eq "Maximum_Errors_Per_URL" ) {
            #
            # Save user agent maximum number of errors to report per URL or file
            #
            if ( @fields > 1 ) {
                $maximum_errors_per_url = $fields[1];
            }
        }
        elsif ( $config_type eq "OD_Testcase_Profile_Group_End" ) {
            #
            # End of open data testcase group profile
            #
            $inside_testcase_group = 0;
        }
        elsif ( $config_type eq "OD_Testcase_Profile_Group_" . $lang ) {
            #
            # Start of a open data new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $tc_profile_group_name = $fields[1];
            ($testcases) =
                New_OD_Testcase_Profile_Group_Hash_Table($tc_profile_group_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $od_testcase_profile_group_map{$other_profile_name} = $testcases;
                $od_testcase_profile_groups_profiles_languages{$other_profile_name} = $tc_profile_group_name;

            }
            $inside_testcase_group = 1;
        }
        elsif ( $config_type =~ "OD_Testcase_Profile_Group_" ) {
            #
            # Alternate language label for this profile
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $od_testcase_profile_group_map{$other_profile_name} = $testcases;
                $od_testcase_profile_groups_profiles_languages{$other_profile_name} = $tc_profile_group_name
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
            $inside_testcase_group = 1;
        }
        elsif ( $config_type eq "puppeteer_chrome_min_version" ) {
            #
            # Set puppeteer minimum Chrome version value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $crawler_config_vars{"puppeteer_chrome_min_version"} = $fields[1];
            }
            else {
                $crawler_config_vars{"puppeteer_chrome_min_version"} = 0;
            }
        }
        elsif ( $config_type eq "Redirect_Ignore_Pattern" ) {
            #
            # Save link redirect ignore value
            #
            if ( @fields > 1 ) {
                push(@redirect_ignore_patterns, $fields[1]);
            }
        }
        elsif ( $config_type eq "Testcase_Profile_Group_End" ) {
            #
            # End of testcase group profile
            #
            $inside_testcase_group = 0;
        }
        elsif ( $config_type eq "Testcase_Profile_Group_" . $lang ) {
            #
            # Start of a new testcase profile. Get hash tables to
            # store attributes
            #
            @fields = split(/\s+/, $_, 2);
            $tc_profile_group_name = $fields[1];
            ($testcases) =
                New_Testcase_Profile_Group_Hash_Table($tc_profile_group_name);

            #
            # Do we have alternate language names for this profile ?
            #
            foreach $other_profile_name (@alternate_lang_profiles) {
                $testcase_profile_group_map{$other_profile_name} = $testcases;
                $testcase_profile_groups_profiles_languages{$other_profile_name} = $tc_profile_group_name;
                
            }
            $inside_testcase_group = 1;
        }
        elsif ( $config_type =~ "Testcase_Profile_Group_" ) {
            #
            # Alternate language label for this profile
            # Match this profile name to the current language profile.
            # If we don't have the testcase profile data structure yet,
            # just save the name.
            #
            @fields = split(/\s+/, $_, 2);
            $other_profile_name = $fields[1];
            if ( defined($testcases) ) {
                $testcase_profile_group_map{$other_profile_name} = $testcases;
                $testcase_profile_groups_profiles_languages{$other_profile_name} = $tc_profile_group_name
            }
            else {
                push(@alternate_lang_profiles, $other_profile_name);
            }
            $inside_testcase_group = 1;
        }
        elsif ( $config_type =~ /TQA_CHECK_Ignore_Pattern/i ) {
            #
            # Pattern of URLs to skip for TQA Check testing
            #
            @fields = split(/\s+/, $_, 2);
            push(@tqa_url_skip_patterns, $fields[1]);
        }
        elsif ( $config_type eq "User_Agent_Hostname" ) {
            #
            # Save user agent host name value
            #
            if ( @fields > 1 ) {
                $user_agent_hostname = $fields[1];
                $crawler_config_vars{"user_agent_hostname"} = $user_agent_hostname;
            }
        }
        elsif ( $config_type eq "User_Agent_Max_Size" ) {
            #
            # Save user agent maximum HTTP response size value
            #
            if ( @fields > 1 ) {
                $crawler_config_vars{"user_agent_max_size"} = $fields[1];
            }
        }
        elsif ( $config_type eq "User_Agent_Name" ) {
            #
            # Save user agent name value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $user_agent_name = $fields[1];
                $crawler_config_vars{"user_agent_name"} = $user_agent_name;
            }
        }
        elsif ( $config_type eq "Markup_Server_Port" ) {
            #
            # Save markup server port value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $crawler_config_vars{"markup_server_port"} = $fields[1];
            }
        }
        elsif ( $config_type eq "Use_Markup_Server" ) {
            #
            # Set use markup server value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $crawler_config_vars{"use_markup_server"} = $fields[1];
            }
            else {
                $crawler_config_vars{"use_markup_server"} = 0;
            }
        }
        elsif ( $config_type =~ /Validation_Ignore_Pattern/i ) {
            #
            # Pattern of URLs to skip for validation
            #
            @fields = split(/\s+/, $_, 2);
            push(@validation_url_skip_patterns, $fields[1]);
        }
        elsif ( $inside_testcase_group ) {
            #
            # Are we inside a testcase profile group ?
            #
            ($name, $value) = split(/\s+/, $_, 2);
            if ( defined($value) && defined($testcases) ) {
                $$testcases{$name} = $value;
            }
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
    Set_Dept_Check_Debug($debug);
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
    Set_Web_Analytics_Check_Debug($debug);
    Validate_Markup_Debug($debug);
    PDF_Files_Debug($debug);
    Set_Interop_Check_Debug($debug);
    HTML_Language_Debug($debug);
    Set_Open_Data_Check_Debug($debug);
    Set_Mobile_Check_Debug($debug);
    Set_Readability_Debug($debug);
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

    my ($tmp);

    #
    # Only check if we did not have a command line debug option
    #
    if ( ! $command_line_debug ) {
        #
        # Do we have the debug file ? If so turn on debuging
        # and redirect stdout & stderr to files.
        #
        if ( -f "$program_dir/debug.txt" ) {
            $debug = 1;
            unlink("$program_dir/stderr.txt");
            unlink("$program_dir/stdout.txt");
            if ( open( STDERR, ">$program_dir/stderr.txt") ) {
                open( STDOUT, ">$program_dir/stdout.txt");
            }
            else {
                #
                # Could not create files in program diectory,
                # try the temp directory.
                #
                if ( defined($ENV{"TMP"}) ) {
                    $tmp = $ENV{"TMP"};
                }
                else {
                    $tmp = "/tmp";
                }

                #
                # Save stdout & stderr files in /tmp
                #
                unlink("$tmp/stderr.txt");
                unlink("$tmp/stdout.txt");
                open( STDERR, ">$tmp/stderr.txt");
                open( STDOUT, ">$tmp/stdout.txt");
            }
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
    my ($key, $value, $metadata_profile);
    my ($tag_required, $content_required, $content_type, $scheme_values);
    my ($invalid_content, $pdf_profile, $tmp);
    my ($sec, $min, $hour, $mday, $mon, $year);

    #
    # Remove any possible debug flag file
    #
    chdir($program_dir);
    unlink("$program_dir/debug.txt");

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
    Read_Dept_Check_Config_File("$program_dir/conf/so_dept_check.config");
    Read_CLF_Check_Config_File("$program_dir/conf/so_clf_check.config");
    Read_WA_Check_Config_File("$program_dir/conf/web_analytics_config.txt");
    Read_Interop_Check_Config_File("$program_dir/conf/so_interop_check.config");
    Read_Mobile_Check_Config_File("$program_dir/conf/mobile_check_config.txt");
    Read_Open_Data_Check_Config_File("$program_dir/conf/open_data_config.txt");
    Read_Markup_Validate_Check_Config_File("$program_dir/conf/markup_validate_config.txt");

    #
    # Set testcase/url help information
    #
    if ( defined($tqa_testcase_url_help_file_name) ) {
        TQA_Testcase_Read_URL_Help_File($tqa_testcase_url_help_file_name);
    }
    if ( defined($dept_testcase_url_help_file_name) ) {
        Dept_Check_Read_URL_Help_File($dept_testcase_url_help_file_name);
    }
    if ( defined($clf_testcase_url_help_file_name) ) {
        CLF_Check_Read_URL_Help_File($clf_testcase_url_help_file_name);
    }
    if ( defined($wa_testcase_url_help_file_name) ) {
        Web_Analytics_Check_Read_URL_Help_File($wa_testcase_url_help_file_name);
    }
    if ( defined($interop_testcase_url_help_file_name) ) {
        Interop_Check_Read_URL_Help_File($interop_testcase_url_help_file_name);
    }
    if ( defined($mobile_testcase_url_help_file_name) ) {
        Mobile_Check_Read_URL_Help_File($mobile_testcase_url_help_file_name);
    }
    if ( defined($open_data_testcase_url_help_file_name) ) {
        Open_Data_Check_Read_URL_Help_File($open_data_testcase_url_help_file_name);
    }

    #
    # Set department Check testcase profiles and other configuration
    #
    while ( ($key,$value) =  each %dept_check_profile_map) {
        Set_Dept_Check_Test_Profile($key, $value);
    }

    #
    # Set message language.
    #
    Set_Content_Check_Language($lang);
    Set_TQA_Check_Language($lang);
    Alt_Text_Check_Language($lang);
    Set_Link_Checker_Language($lang);
    Set_CLF_Check_Language($lang);
    Set_Web_Analytics_Check_Language($lang);
    Metadata_Check_Language($lang);
    PDF_Files_Language($lang);
    Validate_Markup_Language($lang);
    Set_Interop_Check_Language($lang);
    Set_Mobile_Check_Language($lang);
    Set_Open_Data_Check_Language($lang);

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
    # Set Web Analytics Check testcase profiles
    #
    while ( ($key,$value) = each %wa_check_profile_map) {
        Set_Web_Analytics_Check_Test_Profile($key, $value);
    }

    #
    # Set Interoperability Check testcase profiles
    #
    while ( ($key,$value) = each %interop_check_profile_map) {
        Set_Interop_Check_Test_Profile($key, $value);
    }

    #
    # Set Markup Validation testcase profiles
    #
    while ( ($key,$value) = each %markup_validate_profile_map) {
        Set_Validate_Markup_Test_Profile($key, $value);
    }

    #
    # Set Mobile Check testcase profiles
    #
    while ( ($key,$value) = each %mobile_check_profile_map) {
        Set_Mobile_Check_Test_Profile($key, $value);
    }

    #
    # Set Open Data Check testcase profiles
    #
    while ( ($key,$value) = each %open_data_check_profile_map) {
        Set_Open_Data_Check_Test_Profile($key, $value);
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
    $crawler_config_vars{"content_file"} = 0;
    Crawler_Config(%crawler_config_vars);

    Set_Crawler_Domain_Alias_Map(%domain_alias_map);
    Set_Crawler_Domain_Prod_Dev_Map(%domain_prod_dev_map);
    Set_Crawler_HTTP_Response_Callback(\&HTTP_Response_Callback);
    Set_Crawler_URL_Ignore_Patterns(@crawler_link_ignore_patterns);

    #
    # Configure the Link Checker package
    #
    Set_Link_Checker_Domain_Networkscope_Map(%networkscope_map);
    Set_Link_Checker_Domain_Alias_Map(%domain_alias_map);
    Set_Link_Checker_Redirect_Ignore_Patterns(@redirect_ignore_patterns);
    
    #
    # Set maximum errors per URL or file if we have a configuration
    # value for it.
    #
    if ( defined($maximum_errors_per_url) ) {
        $TQA_Result_Object_Maximum_Errors = $maximum_errors_per_url;
    }

    #
    # Get current date and time
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime(time))[0, 1, 2, 3, 4, 5];
    $datetime_stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);

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

    #
    # Are we doing resource monitoring ?
    #
    if ( $monitoring ) {
        $monitoring_file_name = "$program_dir/wpss_tool_resource_usage.txt";
        unlink($monitoring_file_name);
        if ( ! open( RESOURCE, ">$monitoring_file_name") ) {
            #
            # Could not create files in program directory, try 
            # the temp directory.
            #
            if ( defined($ENV{"TMP"}) ) {
                $tmp = $ENV{"TMP"};
            }
            else {
                $tmp = "/tmp";
            }
            $monitoring_file_name = "$tmp/wpss_tool_resource_usage.txt";

            #
            # Open the resource monitoring file
            #
            if ( ! open( RESOURCE, ">$monitoring_file_name") ) {
                print STDERR "Error: Failed to create resource monitoring file\n";
                print STDERR " -> $monitoring_file_name\n";
                $monitoring = 0;
            }
        }
    }

    #
    # Print resource usage monitoring header
    #
    if ( $monitoring ) {
        print RESOURCE "Resource usage monitoring started at $datetime_stamp\n";
        close(RESOURCE);
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
    # Are we not prompting for login credentials ?
    #
    if ( $no_login_mode ) {
        return("","");
    }
    
    #
    # Is the URL the firewall check URL ?
    #
    if ( $url eq $firewall_check_url ) {
        #
        # Reset URL to an empty string when we are in CLI mode
        # to force the CLI layer to prompt for credentials.
        # Normally in CLI mode credentials are not prompted for.
        #
        if ( $cli_mode ) {
            $url = "";
        }
    }
    
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
                   ($this_input->type eq "email") ||
                   ($this_input->type eq "password") ||
                   ($this_input->type eq "text")
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

    #
    # We are now logged in
    #
    $logged_in = 1;
}

#***********************************************************************
#
# Name: Save_Web_Page_Details
#
# Parameters: none
#
# Description:
#
#   This function saves the web page details in the details CSV file.
#
#***********************************************************************
sub Save_Web_Page_Details {

    my ($field, $value);
    my ($printed_one) = 0;

    #
    # Quick check for url field, if we don't have this one we
    # are not tracking values for the current URL (e.g. could be a
    # supporting file).
    #
    if ( ! defined($web_page_details_values{"url"}) ) {
        return;
    }

    #
    # Save the details in the file.
    #
    foreach $field (@web_page_details_fields) {
        if ( defined($web_page_details_values{$field}) ) {
            $value = $web_page_details_values{$field};

            #
            # Remove any quote characters. Excel has problems importing
            # fields with imbedded quotes (even if they are escaped).
            # Remove any comma characters.  Excel may treat a comma
            # inside a quoted string as a cell break.
            #
            $value =~ s/"//g;
            $value =~ s/,//g;
        }
        else {
            $value = "";
        }

        #
        # Convert new line into whitespace
        #
        $value =~ s/\n/ /g;
        $value =~ s/\r/ /g;

        #
        # Do we print a comma before this field ?
        #
        if ( $printed_one ) {
            print $files_details_fh ",";
        }

        #
        # Print the field value
        #
        print "Web page details $field = \"$value\"\n" if $debug;
        print $files_details_fh "\"$value\"";
        $printed_one = 1;
    }

    #
    # Print newline to end this record
    #
    print $files_details_fh "\r\n";
}

#***********************************************************************
#
# Name: Print_Resource_Usage
#
# Parameters: url - document URL
#             when - before/after indicator
#             count - URL count
#
# Description:
#
#   This function prints a number of resource usage statistics to
# a resource monitoring log.  This function is used for debugging
# purposes.
#
#***********************************************************************
sub Print_Resource_Usage {
    my ($url, $when, $count) = @_;

    my ($mem_string);
    my ($sec, $min, $hour, $mday, $mon, $year, $datetime_stamp);

    #
    # Are we doing resource monitoring?
    #
    if ( ! $monitoring ) {
        return;
    }
    
    #
    # Get current date and time
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime(time))[0, 1, 2, 3, 4, 5];
    $datetime_stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);

    #
    # Print time stamp and URL
    #
    open( RESOURCE, ">>$monitoring_file_name");
    print RESOURCE "$count $datetime_stamp $when URL $url\n";

    #
    # Are we running under Windows ?
    #
    if ( $^O =~ /MSWin32/ ) {
        $mem_string = `tasklist /FI "PID eq $$"`;
        $mem_string =~ s/\n/\n  /g;
        print RESOURCE "  tasklist /FI \"PID eq $$\"\n";
        print RESOURCE "  $mem_string\n";
    }
    #
    # Assume linux
    #
    else {
        $mem_string = `ps -p $$ -F`;
        $mem_string =~ s/\n/\n  /g;
        print RESOURCE "  ps -p $$ -F\n";
        print RESOURCE "  $mem_string\n";
    }
    close(RESOURCE);
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

    my ($content, $generated_content, $url_line, $language, $key, $list_ref);
    my ($image_file, $image_file_path, $title, $result_object, %skipped_urls);
    my ($skipped, $count, $error_string, $tab);
    my ($supporting_file) = 0;

    #
    # Check for debug flag file
    #
    Check_Debug_File();
    
    #
    # If the tool is doing a site crawl, some URLs may have been
    # skipped between the last URL and this one.  Get the list of
    # skipped URLs.
    #
    %skipped_urls = Crawler_Get_Skipped_Urls();
    $count = 0;
    foreach $skipped (keys(%skipped_urls)) {
        $count++;
        Validator_GUI_Start_URL($crawled_urls_tab,
                                String_Value("Skipped") .
                                " $skipped -> " . $skipped_urls{$skipped},
                                $referrer, $supporting_file,
                                $document_count{$crawled_urls_tab} . ".$count");
        Validator_GUI_End_URL($crawled_urls_tab, $skipped, $referrer,
                              $supporting_file);
    }

    #
    # If we are doing process monitoring, print out some resource
    # usage statistics
    #
    Print_Resource_Usage($url, "before",
                         $document_count{$crawled_urls_tab} + 1);

    #
    # Check for logout page
    #
    if ( ($url eq $logoutpagee) || ($url eq $logoutpagef) ) {
        $logged_in = 0;
        print "Found logout page\n" if $debug;
    }

    #
    # Initialize markup validity flags and other tool results
    #
    print "HTTP_Response_Callback url = $url, mime-type = $mime_type\n" if $debug;
    %is_valid_markup = ();
    %clf_other_tool_results = ();
    $is_archived = 0;

    #
    # Is this a PDF document and are we ignoring them ?
    #
    if ( ($mime_type =~ /application\/pdf/) && (! $process_pdf) ) {
        $document_count{$crawled_urls_tab}++;
        Validator_GUI_Start_URL($crawled_urls_tab,
                                String_Value("Not reviewed") . " $url",
                                $referrer, $supporting_file,
                                $document_count{$crawled_urls_tab});

        #
        # End this URL
        #
        Validator_GUI_End_URL($crawled_urls_tab, $url, $referrer,
                              $supporting_file);
        return(0);
    }

    #
    # Add URL to list of URLs
    #
    $url_list{$url} = $mime_type;

    #
    # Clear any existing web page details
    #
    %web_page_details_values = ();

    #
    # Get content from HTTP::Response object.
    #
    $content = Crawler_Decode_Content($resp);
    
    #
    # If this is an HTML document, get the full markup after applying
    # JavaScript.  Don't do this if we are behind a login.  The headless
    # user agent is not logged into the site, so we may not get the generated
    # markup for the logged in page.
    #
    $image_file = "";
    if ( ($mime_type =~ /text\/html/) && (! $logged_in) ) {
        #
        # Are we saving content ? If so generate an image of the web page
        #
        if ( $shared_save_content ) {
            #
            # Set file name
            #
            $image_file = sprintf("%03d%s", $content_file + 1, ".jpeg");
            $image_file_path = "$shared_save_content_directory/$image_file";
        }

        #
        # Get generated code
        #
        if ( $enable_generated_markup ) {
            $generated_content = Crawler_Get_Generated_Content($resp, $url,
                                                               $image_file_path);
                                                               
            #
            # If the generated content is empty, we may have encountered
            # an error with the headless user agent
            #
            if ( $generated_content eq "" ) {
                $error_string = Crawler_Error_String();
                if ( $error_string ne "" ) {
                    print STDERR "Crawler error $error_string\n";
                    foreach $tab (@active_results_tabs) {
                        if ( defined($tab) ) {
                            Validator_GUI_Update_Results($tab,
                                                         String_Value("Crawler error") .
                                                         " $error_string");
                        }
                    }
                }
                $generated_content = $content;
            }
        }
        else {
            $generated_content = $content;
        }
    }
    else {
        $generated_content = $content;
    }

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
        $title = "";

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
        # Is this URL flagged as "Archived on the Web" ?
        #
        if ( $mime_type =~ /text\/html/ ) {
            $is_archived = CLF_Check_Is_Archived($clf_check_profile, $url,
                                                 \$generated_content);
        }

        #
        # Determine TQA Check exemption status
        #
        $tqa_check_exempted = TQA_Check_Exempt($url, $mime_type, $is_archived,
                                               \$content, \%url_list);

        #
        # Are we tracking TQA Exempt as an document feature ?
        #
        if ( ($tqa_check_exempted) && ( ! ($mime_type =~ /text\/html/) ) ) {
            #
            # Save "Alternate Format" feature (if the document is exempt from
            # TQA it must be an alternate format)
            #
            $key = "alternate/autre format";
            if ( defined($doc_feature_list{$key}) ) {
                $list_ref = $doc_feature_list{$key};
                print "Add to document feature list $key, url = $url\n" if $debug;
                $$list_ref{$url} = 1;
            }
        }

        #
        # Validate the content
        #
        Print_Resource_Usage($url, "Perform_Markup_Validation",
                             $document_count{$crawled_urls_tab});
        Perform_Markup_Validation($url, $mime_type, $resp, \$content);

        #
        # If the file is HTML content, validate it and perform a link check.
        #
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Get document language
            #
            $language = HTML_Document_Language($url, \$content);

            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = $language;
            $web_page_details_values{"content size"} = length($content);

            #
            # Display content in browser window
            #
            Validator_GUI_Display_Content($url, \$content);

            #
            # Perform Link check
            #
            Print_Resource_Usage($url, "Perform_Link_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_Link_Check($url, $mime_type, $resp, \$content,
                               $language, \$generated_content);

            #
            # Perform Metadata Check
            #
            Print_Resource_Usage($url, "Perform_Metadata_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_Metadata_Check($url, \$generated_content, $language);
            
            #
            # Do we have a page title ?
            #
            if ( defined($metadata_results{"title"}) ) {
                $result_object = $metadata_results{"title"};
                $title = $result_object->content;
            }

            #
            # Perform TQA check
            #
            Print_Resource_Usage($url, "Perform_TQA_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_TQA_Check($url, \$generated_content, $language,
                              $mime_type, $resp, $logged_in);

            #
            # Perform CLF check
            #
            Print_Resource_Usage($url, "Perform_CLF_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_CLF_Check($url, \$generated_content, $language,
                              $mime_type, $resp);

            #
            # Perform Interoperability check
            #
            Print_Resource_Usage($url, "Perform_Interop_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_Interop_Check($url, \$generated_content, $language,
                                  $mime_type, $resp);

            #
            # Perform Mobile check
            #
            Print_Resource_Usage($url, "Perform_Mobile_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_Mobile_Check($url, $language, $mime_type, $resp,
                                 \$content, \$generated_content);

            #
            # Perform feature check
            #
            Print_Resource_Usage($url, "Perform_Feature_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_Feature_Check($url, $mime_type, \$generated_content);
            
            #
            # Perform readability analysis
            #
            Print_Resource_Usage($url, "Perform_Readability_Analysis",
                                 $document_count{$crawled_urls_tab});
            Perform_Readability_Analysis($url, \$generated_content, $language,
                                         $mime_type, $resp);
        }

        #
        # Do we have application/epub+zip mime type for EPUB documents ?
        #
        elsif ( ($mime_type =~ /application\/epub\+zip/) ||
                ($url =~ /\.epub$/i) ) {
            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = "";
            $web_page_details_values{"content size"} = length($content);

            #
            # Perform EPUB checks
            #
            Print_Resource_Usage($url, "Perform_EPUB_Check",
                                 $document_count{$crawled_urls_tab});
            Perform_EPUB_Check($url, \$content, $language, $mime_type, $resp);
        }

        #
        # Do we have application/pdf mime type ?
        #
        elsif ( $mime_type =~ /application\/pdf/ ) {
            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = "";
            $web_page_details_values{"content size"} = length($content);

            #
            # Get document language from the URL
            #
            $language = URL_Check_GET_URL_Language($url);

            #
            # Perform link check
            #
            Perform_Link_Check($url, $mime_type, $resp, \$content, $language,
                               \$content);

            #
            # Perform PDF Properties Check check
            #
            Perform_PDF_Properties_Check($url, \$content);

            #
            # Do we have a page title ?
            #
            if ( defined($pdf_property_results{"title"}) ) {
                $title = $pdf_property_results{"title"};
            }

            #
            # Perform TQA check of PDF content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);

            #
            # Perform feature check
            #
            Perform_Feature_Check($url, $mime_type, \$content);
        }

        #
        # Do we have CSS content ?
        #
        elsif ( $mime_type =~ /text\/css/ ) {
            #
            # Perform Link check
            #
            Perform_Link_Check($url, $mime_type, $resp, \$content, "",
                               \$content);

            #
            # Perform TQA check of CSS content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);

            #
            # Perform Mobile check
            #
            Perform_Mobile_Check($url, $language, $mime_type, $resp, \$content,
                                 \$generated_content);
        }

        #
        # Is the file JavaScript ? or does the URL end in a .js ?
        #
        elsif ( ($mime_type =~ /application\/x\-javascript/) ||
                ($mime_type =~ /text\/javascript/) ||
                ($url =~ /\.js$/i) ) {
            #
            # Perform TQA check of JavaScript content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);

            #
            # Perform Mobile check
            #
            Perform_Mobile_Check($url, $language, $mime_type, $resp, \$content,
                                 \$generated_content);
        }

        #
        # Is the file a CSV file ?
        #
        elsif ( ($mime_type =~ /text\/x-comma-separated-values/) ||
                ($mime_type =~ /text\/csv/) ||
                ($url =~ /\.csv$/i) ) {
            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = "";
            $web_page_details_values{"content size"} = length($content);

            #
            # Perform TQA check of CSV content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);
        }

        #
        # Is the file XML ? or does the URL end in a .xml ?
        #
        elsif ( ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/rss\+xml/) ||
                ($mime_type =~ /application\/ttml\+xml/) ||
                ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            #
            # Get document language
            #
            $language = XML_Document_Language($url, \$content);

            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = $language;
            $web_page_details_values{"content size"} = length($content);

            #
            # Perform link check
            #
            Perform_Link_Check($url, $mime_type, $resp, \$content, $language,
                               \$content);

            #
            # Perform TQA check of XML content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);

            #
            # Perform Interoperability check
            #
            Perform_Interop_Check($url, \$content, $language, $mime_type,
                                  $resp);

            #
            # Perform Mobile check
            #
            Perform_Mobile_Check($url, $language, $mime_type, $resp, \$content,
                                 \$generated_content);

            #
            # Save "non-HTML primary format" feature
            #
            $key = "non-html primary format/format principal non-html";
            if ( defined($doc_feature_list{$key}) ) {
                $list_ref = $doc_feature_list{$key};
                print "Add to document feature list $key, url = $url\n" if $debug;
                $$list_ref{$url} = 1;
            }
        }

        #
        # Do we have an image mime type ?
        #
        elsif ( $mime_type =~ /^image/i ) {
            #
            # Perform Mobile check
            #
            Perform_Mobile_Check($url, $language, $mime_type, $resp, \$content,
                                 \$generated_content);

            #
            # Are we saving image file details ?
            #
            if ( $save_image_file_details_in_inventory ) {
                $web_page_details_values{"url"} = $url;
                $web_page_details_values{"lang"} = "";
                $web_page_details_values{"content size"} = length($content);
            }
        }

        #
        # Do we have the robots.txt file ?
        #
        elsif ( $url =~ /robots\.txt$/i ) {
            #
            # No special processing
            #
        }

        #
        # Is the file a MARC file ?
        #
        elsif ( ($mime_type =~ /application\/marc/) ||
                ($url =~ /\.mrc$/i) ) {
            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = "";
            $web_page_details_values{"content size"} = length($content);

            #
            # Perform TQA check of CSV content
            #
            Perform_TQA_Check($url, \$content, $language, $mime_type, $resp,
                              $logged_in);
        }

        #
        # Unknown mime-type, save URL as non-HTML primary format
        #
        else {
            #
            # Save "non-HTML primary format" feature
            #
            $key = "non-html primary format/format principal non-html";
            if ( defined($doc_feature_list{$key}) ) {
                $list_ref = $doc_feature_list{$key};
                print "Add to document feature list $key, url = $url\n" if $debug;
                $$list_ref{$url} = 1;
            }

            #
            # Save web page details
            #
            $web_page_details_values{"url"} = $url;
            $web_page_details_values{"lang"} = "";
            $web_page_details_values{"content size"} = length($content);
        }

        #
        # Perform department checks
        #
        Perform_Department_Check($url, $language, $mime_type, $resp, \$content);

        #
        # End this URL
        #
        Validator_GUI_End_URL($crawled_urls_tab, $url, $referrer,
                              $supporting_file);

        #
        # Are we saving web page details for this URL ?
        #
        if ( defined($web_page_details_values{"url"}) ) {
            $web_page_details_values{"mime-type"} = $mime_type;
            $web_page_details_values{"archived"} = $is_archived;
        }

        #
        # Save web page details
        #
        Save_Web_Page_Details();

        #
        # Save content in a local file
        #
        Save_Content_To_File($url, $mime_type, \$generated_content, $image_file,
                             $title);
    }
    else {
        #
        # No content
        #
        print "HTTP_Response_Callback: No content for $url\n" if $debug;
    }

    #
    # If we are doing process monitoring, print out some resource
    # usage statistics
    #
    Print_Resource_Usage($url, "after",
                         $document_count{$crawled_urls_tab});

    #
    # Return success
    #
    return(0);
}

#***********************************************************************
#
# Name: HTML_Document_Language
#
# Parameters: url - URL
#             content - content pointer
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

       #
       # If we still don't have a language, get the default language of the
       # page as specified in the <html> tag.
       #
       if ( $lang_code eq "" ) {
           $lang_code = HTML_Language($url, $content);
       }
    }

    #
    # Return language
    #
    print "HTML_Document_Language of $url is $lang_code\n" if $debug;
    return($lang_code);
}

#***********************************************************************
#
# Name: XML_Document_Language
#
# Parameters: url - document URL
#             content - content pointer
#
# Description:
#
#   This function determines the language of a XML document.  It first
# checks the URL to see if there is a language portion (e.g. -eng), if
# there isn't one, it checks the content.
#
#***********************************************************************
sub XML_Document_Language {
    my ($url, $content) = @_;

    my ($lang, $lang_code, $status);

    #
    # Check the URL for language specifier
    #
    $lang_code = URL_Check_GET_URL_Language($url);
    if ( $lang_code eq "" ) {
        #
        # Cannot determine language from file name
        #
        print "Cannot determine language of XML document from URL\n" if $debug;
    }

    #
    # Return language
    #
    print "XML_Document_Language of $url is $lang_code\n" if $debug;
    return($lang_code);
}

#***********************************************************************
#
# Name: Save_Content_To_File
#
# Parameters: url - document URL
#             mime_type - document mime type
#             content - document content
#             image_file - name of web page image file (screen
#               capture of the web page)
#             title - title of page
#
# Description:
#
#   This function saves the content to a local file.
#
#***********************************************************************
sub Save_Content_To_File {
    my ($url, $mime_type, $content, $image_file, $title) = @_;

    my ($filename, $content_saved, @lines, $n);

    #
    # Are we saving content ?
    #
    if ( $shared_save_content ) {
        #
        # Set file name
        #
        $content_file++;
        $filename = sprintf("%03d", $content_file);

        #
        # Determine file suffix based on mime type
        #
        if ( $mime_type =~ /application\/pdf/ ) {
            $filename .= ".pdf";

            #
            # Save content to file
            #
            print "Create PDF file $shared_save_content_directory/$filename\n" if $debug;
            open(PDF, ">$shared_save_content_directory/$filename") ||
                die "Save_Content_To_File: Failed to open $shared_save_content_directory/$filename for writing\n";
            binmode PDF;
            print PDF $$content;
            close(PDF);
            $content_saved = 1;
        }
        elsif ( $mime_type =~ /text\/html/ ){
            $filename .= ".html";

            #
            # Create HTML file
            #
            print "Create text file $shared_save_content_directory/$filename\n" if $debug;
            open(TXT, ">$shared_save_content_directory/$filename") ||
                die "Save_Content_To_File: Failed to open $shared_save_content_directory/$filename for writing\n";
            binmode TXT;

            #
            # Split the content on the <head tag
            #
            @lines = split(/<head/i, $$content, 2);
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
                 $lines[1] =~ s/>/><!-- Page content saved by wpss_tool.pl at $datetime_stamp. The following base tag was inserted by the tool --><base href="$url" \/>/;

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
            print "Create text file $shared_save_content_directory/$filename\n" if $debug;
            open(TXT, ">$shared_save_content_directory/$filename") ||
                die "Save_Content_To_File: Failed to open $shared_save_content_directory/$filename for writing\n";
            binmode TXT;
            print TXT $$content;
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
            open(HTML, ">> $shared_save_content_directory/index.html") ||
            die "Error: Failed to open file $shared_save_content_directory/index.html\n";
            print HTML "<tr>
<td>$content_file</td>
<th scope=\"row\"><a href=\"$url\">$url</a></th>
<td><a href=\"$filename\">$filename</a></th>
<td>$mime_type</td>
<td>$title</td>
";

            #
            # Do we have screen shot file ?
            #
            if ( defined($image_file) && ($image_file ne "") ) {
                print HTML "<td><a href=\"$image_file\"><img src=\"$image_file\" alt=\"screen shot for $url\" height=\"150\" width=\"150\"></a></td>";
            }
            else {
                print HTML "<td>\&nbsp;</td>";
            }
            print HTML "</tr>\n";
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
    Initialize_Tool_Globals("Direct HTML", %report_options);
    $shared_save_content = 0;

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
                                         \$content);

    #
    # Determine TQA Check exemption status
    #
    $tqa_check_exempted = TQA_Check_Exempt("Direct Input", "text/html",
                                           $is_archived, \$content, \%url_list);

    #
    # Perform markup validation check
    #
    Perform_Markup_Validation("Direct Input", "text/html", undef, \$content);

    #
    # Get links from document, save list in the global @links variable.
    # We need the list of links (and mime-types) in the document features
    # check.
    #
    @links = Extract_Links("Direct Input", "", "", "text/html", \$content);

    #
    # Get links from all document subsections
    #
    %all_link_sets = Extract_Links_Subsection_Links("ALL");

    #
    # Perform Metadata Check
    #
    Perform_Metadata_Check("Direct Input", \$content, $Unknown_Language);

    #
    # Perform TQA check
    #
    Perform_TQA_Check("Direct Input", \$content, $Unknown_Language, "text/html",
                      $resp, $logged_in);

    #
    # Perform CLF check
    #
    Perform_CLF_Check("Direct Input", \$content, $Unknown_Language, "text/html",
                      $resp);

    #
    # Perform Interoperability check
    #
    Perform_Interop_Check("Direct Input", \$content, $Unknown_Language,
                          "text/html", $resp);

    #
    # Perform Feature check
    #
    Perform_Feature_Check("Direct Input", "text/html", \$content);

    #
    # Print document feature report
    #
    Print_Document_Features_Report();

    #
    # Site analysis complete, print report footer
    #
    Print_Results_Footer(0, 0);
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
    foreach $result_object (@content_results_list ) {
        $status = $result_object->status;
        if ( $status != 0 ) {
            #
            # Increment error instance count
            #
            if ( ! defined($dept_error_instance_count{$result_object->description}) ) {
                $dept_error_instance_count{$result_object->description} = 1;
                $dept_error_url_count{$result_object->description} = 1;
            }
            else {
               $dept_error_instance_count{$result_object->description}++;
               $dept_error_url_count{$result_object->description}++;
            }
            $error_count{$dept_tab}++;

            #
            # Print error
            #
            Validator_GUI_Print_TQA_Result($dept_tab, $result_object);
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
sub Check_For_PDF_Only_Document {

    my ($url, $title, $html_url, $pattern, $found_html, $list_ref);

    #
    # Are we checking for non HTML primary format ?
    #
    if ( defined($doc_feature_list{"non-html primary format/format principal non-html"}) ) {
        #
        # Get list for this feature
        #
        $list_ref = $doc_feature_list{"non-html primary format/format principal non-html"};

        #
        # Look through each PDF document looking for am matching HTML
        #
        while ( ($url, $title) = each %pdf_titles ) {
            #
            # Do we have a matching HTML document title ?
            #
            print "Checking PDF $url, title = \"$title\"\n" if $debug;
            $found_html = 0;
            if ( defined($title_html_url{$title}) ) {
                print "Found matching HTML title at " . $title_html_url{$title} .
                      "\n" if $debug;
                $found_html = 1;
            }
            else {
                #
                # Do we have a match on the URL ?
                #
                foreach $pattern (@doc_directory_paths) {
                    $html_url = $url;
                    $html_url =~ s/\.pdf$/.html/i;
                    $html_url =~ s/\/$pattern\//\//g;
                    if ( defined($html_titles{$html_url}) ) {
                        #
                        # Found match, go to next URL
                        #
                        print "Found HTML URL at $html_url\n" if $debug;
                        $found_html = 1;
                        last;
                    }
                }
            }

            #
            # If we didn't find an HTML equivalent, this is a non-HTML
            # format document.
            #
            if ( ! $found_html ) {
                print "Add to document feature list \"non-html primary format/format principal non\", url = $url\n" if $debug;
                $$list_ref{$url} = 1;
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
                                                          $dept_check_profile);

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
                                                        $dept_check_profile);

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
                                     $dept_check_profile, %headings_table);

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
    # Check Web feeds
    #
    print "Check_Web_Feeds\n" if $debug;
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
    # Beed a heading before reporting any title errors.
    #
    Validator_GUI_Update_Results($dept_tab, String_Value("Content violations"));

    #
    # Check for PDF only versions of documents
    #
    Check_For_PDF_Only_Document();

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

    my ($this_url, @urls, $tab, %crawler_options);
    my ($resp_url, $resp, $header, $content_type, $error);

    #
    # Initialize tool global variables
    #
    Initialize_Tool_Globals("URL List", %report_options);
    Set_Link_Checker_Ignore_Patterns(@link_ignore_patterns);
    Crawler_Abort_Crawl(0);

    #
    # Set crawler options
    #
    if ( defined($report_options{"crawler_page_delay_secs"}) ) {
        $crawler_options{"crawler_page_delay_secs"} = $report_options{"crawler_page_delay_secs"};
    }
    Set_Crawler_Options(\%crawler_options);

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
        # Are we aborting the URL analysis ? Check crawler module flag
        # in case the abort was called from another thread (i.e. the UI layer)
        #
        if ( Crawler_Abort_Crawl_Status() == 1 ) {
            last;
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
            HTTP_Response_Callback($resp_url, "", $content_type, $resp);
        }
        else {
            #
            # Error getting document
            #
            $document_count{$crawled_urls_tab}++;
            if ( defined($resp) ) {
                $error = String_Value("HTTP Error") . " " .
                                      $resp->status_line;
                if ( defined($resp->header("Client-Warning")) ) {
                    $error .= ", " . $resp->header("Client-Warning");
                }
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
    # Was the crawl aborted ?
    #
    if ( Crawler_Abort_Crawl_Status() == 1 ) {
        #
        # Add a note to all tabs indicating that analysis was aborted.
        #
        foreach $tab (@active_results_tabs) {
            if ( defined($tab) ) {
                Validator_GUI_Update_Results($tab,
                                             String_Value("Analysis Aborted"),
                                             0);
            }
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
    Print_Results_Footer(0, 0);

    #
    # Close the web page details list
    #
    close($files_details_fh);

    #
    # Close the web page size file
    #
    if ( defined($web_page_size_file_handle) ) {
        close($web_page_size_file_handle);
    }

    #
    # Save Image, Atl text & title report
    #
    $shared_image_alt_text_report = Alt_Text_Check_Generate_Report(\%image_alt_text_table);
}

#***********************************************************************
#
# Name: show_call_stack
#
# Parameters: none
#
# Description:
#
#   This function generates a stack trace of function calls.
#
#***********************************************************************
sub show_call_stack {
    my ($path, $line, $subr, $message);
    my $max_depth = 30;
    my $i = 1;
    
    $message = "--- Begin stack trace ---\n";
    while ( (my @call_details = (caller($i++))) && ($i<$max_depth) ) {
      $message .=  "$call_details[1] line $call_details[2] in function $call_details[3]\n";
    }
    $message .= "--- End stack trace ---\n";
    return($message);
}

#***********************************************************************
#
# Name: Runtime_Error_Callback
#
# Parameters: message - runtime error message
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when the validator engine has a runtime error and
# aborts.  The result tabs are updated with an error message.
#
#***********************************************************************
sub Runtime_Error_Callback {
    my ($message) = @_;

    my ($tab, $call_stack);

    #
    # Add a note to all tabs indicating that analysis failed due
    # runtime error.
    #
    $call_stack = show_call_stack();
    foreach $tab (@active_results_tabs) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "", 0);
            Validator_GUI_Update_Results($tab,
                                         String_Value("Runtime Error Analysis Aborted"),
                                         0);
            Validator_GUI_Update_Results($tab, $message, 0);
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
    Print_Results_Footer(0, 0);

    #
    # Close the web page details list
    #
    if ( defined($files_details_fh) ) {
        close($files_details_fh);
    }

    #
    # Close the web page size file
    #
    if ( defined($web_page_size_file_handle) ) {
        close($web_page_size_file_handle);
    }

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
    print REPORT '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
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
    print REPORT '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
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
# Name: Save_Testcase_Summary_CSV
#
# Parameters: none
#
# Description:
#
#   This function saves the testcase results summaries in a
# temporary CSV file. The CSV file has a _rslt_summary.csv suffix.
#
#***********************************************************************
sub Save_Testcase_Summary_CSV {

    my ($csv_results_fh, $csv_object, $status, @fields);
    my ($tcid, $help_url, $tc_label, $sc, %sc_url, %sc_instance, @sc_list);

    #
    # Do we already have a results summary CSV file (e.g. from a previous run)?
    #
    if ( defined($shared_testcase_results_summary_csv_filename) ) {
        unlink($shared_testcase_results_summary_csv_filename);
    }

    #
    # Create testcase results summary CSV file
    #
    print "Save results summary CSV\n" if $debug;
    ($csv_results_fh, $shared_testcase_results_summary_csv_filename) =
       tempfile("WPSS_TOOL_WP_XXXXXXXXXX",
                SUFFIX => '.csv',
                TMPDIR => 1);
    if ( ! defined($csv_results_fh) ) {
        print "Error: Failed to create temporary file in Save_Testcase_Summary_CSV\n";
        return;
    }
    binmode $csv_results_fh, ":utf8";
    
    #
    # Add UTF-8 BOM
    #
    print $csv_results_fh chr(0xFEFF);
    print "Testcase results summary file name = $shared_testcase_results_summary_csv_filename\n" if $debug;

    #
    # Create CSV object
    #
    $csv_object = Text::CSV->new ( { binary => 1, eol => $/ } );
    $csv_object->print($csv_results_fh, \@csv_summary_results_fields);

    #
    # Print summary results for Link Check
    #
    if ( defined($link_tab) ) {
        foreach $tcid (sort(keys %link_error_url_count)) {
            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($link_tab, "", "", $tcid, $link_error_url_count{$tcid},
                       $link_error_instance_count{$tcid}, "");

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $link_tab\n";
            }
        }
    }

    #
    # Print summary results for Metadata Check
    #
    if ( defined($metadata_tab) ) {
        foreach $tcid (sort(keys %metadata_error_url_count)) {
            #
            # Get help URL
            #
            if ( defined( $metadata_help_url{$metadata_profile} ) ) {
                $help_url = $metadata_help_url{$metadata_profile};
            }
            else {
                $help_url = "";
            }

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($metadata_tab, "", "", $tcid, $metadata_error_url_count{$tcid},
                       $metadata_error_instance_count{$tcid}, $help_url);

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $metadata_tab\n";
            }
        }
    }

    #
    # Print summary results table for TQA Check
    #
    if ( defined($acc_tab) ) {
        foreach $tcid (sort(keys %tqa_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            # Get the success criteria for this testcase
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;
            $sc = $tc_label;
            $sc =~ s/\s\D+[\.\d]+//g;
            $tc_label =~ s/^.*\s//g;
            
            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($acc_tab, $sc, $tc_label, $tcid,
                       $tqa_error_url_count{$tcid},
                       $tqa_error_instance_count{$tcid},
                       TQA_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $acc_tab\n";
            }
            
            #
            # Get the list of success criterion for this textcase
            #
            $sc =~ s/\s*//g;
            @sc_list = split(/,/, $sc);
            foreach $sc (@sc_list) {
                $sc_url{$sc} += $tqa_error_url_count{$tcid};
                $sc_instance{$sc} += $tqa_error_instance_count{$tcid};
            }
        }
        
        #
        # Add success criterion error counts to the CSV
        #
        foreach $sc (sort(keys %sc_url)) {
            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($acc_tab, $sc, "",
                       TQA_Testcase_Success_Criteria_Description($sc),
                       $sc_url{$sc}, $sc_instance{$sc},
                       TQA_Testcase_URL($sc));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $acc_tab\n";
            }
        }
    }

    #
    # Print summary results table for CLF Check and Web Analytics Check
    #
    if ( defined($clf_tab)) {
        foreach $tcid (sort(keys %clf_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($clf_tab, "", $tc_label, $tcid, $clf_error_url_count{$tcid},
                       $clf_error_instance_count{$tcid},
                       CLF_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $clf_tab\n";
            }
        }
    }

    #
    # Print summary results table for Interopability Check
    #
    if ( defined($interop_tab) ) {
        foreach $tcid (sort(keys %interop_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($interop_tab, "", $tc_label, $tcid, $interop_error_url_count{$tcid},
                       $interop_error_instance_count{$tcid},
                       Interop_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $interop_tab\n";
            }
        }
    }

    #
    # Print summary results table for Mobile Check
    #
    if ( defined($mobile_tab) ) {
        foreach $tcid (sort(keys %mobile_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($mobile_tab, "", $tc_label, $tcid, $mobile_error_url_count{$tcid},
                       $mobile_error_instance_count{$tcid},
                       Mobile_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $mobile_tab\n";
            }
        }
    }

    #
    # Print summary results table for department Check
    #
    if ( defined($dept_tab) ) {
        foreach $tcid (sort(keys %dept_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;
            
            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($dept_tab, "", $tc_label, $tcid, $dept_error_url_count{$tcid},
                       $dept_error_instance_count{$tcid},
                       Dept_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $dept_tab\n";
            }
        }
    }

    #
    # Print summary results table for open data content Check
    #
    if ( defined($content_tab) ) {
        foreach $tcid (sort(keys %content_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($content_tab, "", $tc_label, $tcid, $content_error_url_count{$tcid},
                       $content_error_instance_count{$tcid},
                       Open_Data_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $content_tab\n";
            }
        }
    }
    
    #
    # Print summary results table for open data Check
    #
    if ( defined($open_data_tab) ) {
        foreach $tcid (sort(keys %open_data_error_url_count)) {
            #
            # Get testcase label by removing the description portion
            # (characters after the colon).
            #
            $tc_label = $tcid;
            $tc_label =~ s/:.*//g;

            #
            # Save fields of the result object in the CSV file
            #
            @fields = ($open_data_tab, "", $tc_label, $tcid, $open_data_error_url_count{$tcid},
                       $open_data_error_instance_count{$tcid},
                       Open_Data_Check_Testcase_URL($tcid));

            $status = $csv_object->print($csv_results_fh, \@fields);
            if ( ! $status ) {
                print "Error in CSV print, status = $status, " .
                      $csv_object->error_diag() . ", tab = $open_data_tab\n";
            }
        }
    }

    #
    # Close the CSV file
    #
    close($csv_results_fh);
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

    my ($save_filename);

    #
    # Save the URL, Image, Alt report.
    #
    Save_URL_Image_Alt_Report($filename);

    #
    # Save the Headings report
    #
    Save_Headings_Report($filename);

    #
    # Save web page size details
    #
    $save_filename = $filename . "_page_size.csv";
    print "Page size file name = $save_filename\n" if $debug;
    unlink($save_filename);
    print "Copy $shared_web_page_size_filename, $save_filename\n" if $debug;
    if ( -f $shared_web_page_size_filename ) {
        copy($shared_web_page_size_filename, $save_filename);
    }
    unlink($shared_web_page_size_filename);

    #
    # Save any saved web page content
    #
    Finish_Content_Saving($filename);
    
    #
    # Save testcase results summary in a CSV file
    #
    $save_filename = $filename . "_rslt_summary.csv";
    print "Testcase reults summary file name = $save_filename\n" if $debug;
    unlink($save_filename);
    print "Copy $shared_testcase_results_summary_csv_filename, $save_filename\n" if $debug;
    if ( -f $shared_testcase_results_summary_csv_filename ) {
        copy($shared_testcase_results_summary_csv_filename, $save_filename);
    }
    unlink($shared_testcase_results_summary_csv_filename);

    #
    # Copy the web page details CSV to the results directory.
    #
    $save_filename = $filename . "_page_inventory.csv";
    unlink($save_filename);
    print "Copy $shared_file_details_filename, $save_filename\n" if $debug;
    if ( -f $shared_file_details_filename ) {
        copy($shared_file_details_filename, $save_filename);
    }
    unlink($shared_file_details_filename);

    #
    # Copy the web page links details CSV to the results directory.
    #
    $save_filename = $filename . "_link_details.csv";
    unlink($save_filename);
    print "Copy $shared_links_details_filename, $save_filename\n" if $debug;
    if ( -f $shared_links_details_filename ) {
        copy($shared_links_details_filename, $save_filename);
    }
    unlink($shared_links_details_filename);
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
    my ($site_entries, %user_agent_details, $user_agent, $details);
    my (%tool_versions, $tool, $version);

    #
    # Clear any text that may exist in the results tabs
    #
    foreach $tab (@active_results_tabs) {
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

        Validator_GUI_Update_Results($validation_tab,
                                     String_Value("Validation report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($link_tab,
                                     String_Value("Link report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($metadata_tab,
                                    String_Value("Metadata report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($acc_tab,
                                     String_Value("ACC report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($clf_tab,
                                     String_Value("CLF report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($interop_tab,
                                     String_Value("Interop report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($mobile_tab,
                                     String_Value("Mobile report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($dept_tab,
                                     String_Value("Department report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($doc_features_tab,
                               String_Value("Document Features report header") .
                                     $site_entries);

        Validator_GUI_Update_Results($doc_list_tab,
                               String_Value("Document List report header") .
                                     $site_entries);
    }
    
    #
    # Add user agent details.
    #
    %user_agent_details = Crawler_User_Agent_Details();
    if ( scalar(keys(%user_agent_details)) > 0 ) {
        foreach $tab (@active_results_tabs) {
            if ( defined($tab) ) {
                Validator_GUI_Update_Results($tab, "");
                foreach $user_agent (sort(keys(%user_agent_details))) {
                    $details = $user_agent_details{$user_agent};
                    Validator_GUI_Update_Results($tab,
                                                 String_Value("User agent details") .
                                                 " $user_agent $details");
                }
                Validator_GUI_Update_Results($tab, "");
            }
        }
    }

    if ( defined($content_tab) ) {
        Validator_GUI_Update_Results($content_tab,
                                     String_Value("Content report header"));
    }
    if ( defined($open_data_tab) ) {
        Validator_GUI_Update_Results($open_data_tab,
                                     String_Value("Open Data report header"));
    }

    #
    # Include profile name in header
    #
    if ( defined($validation_tab) ) {
        Validator_GUI_Update_Results($validation_tab,
                                     String_Value("Markup Validation Profile")
                                     . " " . $markup_validate_profile);
    }
    if ( defined($link_tab) ) {
        Validator_GUI_Update_Results($link_tab,
                                     String_Value("Link Check Profile")
                                     . " " . $link_check_profile);
    }
    if ( defined($metadata_tab) ) {
        Validator_GUI_Update_Results($metadata_tab,
                                     String_Value("Metadata Profile")
                                     . " " . $metadata_profile);
    }
    if ( defined($acc_tab) ) {
        #
        # Include supporting tool versions
        #
        %tool_versions = TQA_Check_Tools_Versions();
        foreach $tool (sort(keys(%tool_versions))) {
            $version = $tool_versions{$tool};
            Validator_GUI_Update_Results($acc_tab,
                                         String_Value("Supporting tool") .
                                         " $tool : $version");
        }

        Validator_GUI_Update_Results($acc_tab, "");
        Validator_GUI_Update_Results($acc_tab,
                                     String_Value("ACC Testcase Profile")
                                     . " " . $tqa_check_profile);

    }
    if ( defined($clf_tab) ) {
        Validator_GUI_Update_Results($clf_tab,
                                     String_Value("CLF Testcase Profile")
                                     . " " . $clf_check_profile);
        Validator_GUI_Update_Results($clf_tab,
                                     String_Value("Web Analytics Testcase Profile")
                                     . " " . $wa_check_profile);
    }
    if ( defined($interop_tab) ) {
        Validator_GUI_Update_Results($interop_tab,
                                     String_Value("Interop Testcase Profile")
                                     . " " . $interop_check_profile);
    }
    if ( defined($mobile_tab) ) {
        Validator_GUI_Update_Results($mobile_tab,
                                     String_Value("Mobile Testcase Profile")
                                     . " " . $mobile_check_profile);
    }
    if ( defined($dept_tab) ) {
        Validator_GUI_Update_Results($dept_tab,
                                 String_Value("Department Check Testcase Profile")
                                     . " " . $dept_check_profile);
    }
    if ( defined($content_tab) ) {
        Validator_GUI_Update_Results($content_tab,
                                     String_Value("Content Testcase Profile")
                                     . " " . $open_data_check_profile);
    }
    if ( defined($open_data_tab) ) {
        Validator_GUI_Update_Results($open_data_tab,
                                     String_Value("Open Data Testcase Profile")
                                     . " " . $open_data_check_profile);
    }
    if ( defined($doc_features_tab) ) {
        Validator_GUI_Update_Results($doc_features_tab,
                                     String_Value("Document Features Profile")
                                     . " " . $current_doc_features_profile);
    }

    #
    # Add site analysis date to each output tab.
    #
    ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0,1,2,3,4,5];
    $mon++;
    $year += 1900;
    $date = sprintf("%02d:%02d:%02d %4d/%02d/%02d", $hour, $min, $sec, $year,
                    $mon, $mday);
    foreach $tab (@active_results_tabs) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");
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
    foreach $tab ($link_tab, $metadata_tab, $acc_tab, $clf_tab, $dept_tab,
                  $interop_tab, $open_data_tab, $content_tab) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");
            Validator_GUI_Update_Results($tab,
                                         String_Value("Results summary table"));
        }
    }

    #
    # Print summary results table for Link Check
    #
    if ( defined($link_tab) ) {
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
    if ( defined($metadata_tab) ) {
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
    if ( defined($acc_tab) ) {
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
    }

    #
    # Add overall fault count
    #
    if ( defined($acc_tab) && defined($document_count{$acc_tab}) &&
         ($document_count{$acc_tab} > 0) ) {
        $faults = $fault_count{$acc_tab};
        $faults_per_page = sprintf("%4.2f", $faults / $document_count{$acc_tab});
        Validator_GUI_Print_Scan_Fault_Count($acc_tab, $faults,
                                             $faults_per_page);
    }

    #
    # Print summary results table for CLF Check and Web Analytics Check
    #
    if ( defined($clf_tab)) {
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
            elsif ( defined( Web_Analytics_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Web_Analytics_Check_Testcase_URL($tcid);
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
    if ( defined($interop_tab) ) {
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
    # Print summary results table for Mobile Check
    #
    if ( defined($mobile_tab) ) {
        foreach $tcid (sort(keys %mobile_error_url_count)) {
            Validator_GUI_Update_Results($mobile_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $mobile_error_url_count{$tcid},
                            $mobile_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Mobile_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Mobile_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($mobile_tab, $line);
            Validator_GUI_Update_Results($mobile_tab, "");
        }
    }

    #
    # Print summary results table for department Check
    #
    if ( defined($dept_tab) ) {
        foreach $tcid (sort(keys %dept_error_url_count)) {
            Validator_GUI_Update_Results($dept_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $dept_error_url_count{$tcid},
                            $dept_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Dept_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Dept_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($dept_tab, $line);
            Validator_GUI_Update_Results($dept_tab, "");
        }
    }

    #
    # Print summary results table for Open Data content Check
    #
    if ( defined($content_tab) ) {
        foreach $tcid (sort(keys %content_error_url_count)) {
            Validator_GUI_Update_Results($content_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $content_error_url_count{$tcid},
                            $content_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Open_Data_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Open_Data_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($content_tab, $line);
            Validator_GUI_Update_Results($content_tab, "");
        }
    }

    #
    # Print summary results table for open data Check
    #
    if ( defined($open_data_tab) ) {
        foreach $tcid (sort(keys %open_data_error_url_count)) {
            Validator_GUI_Update_Results($open_data_tab, $tcid);
            $line = sprintf("  URLs %5d " . String_Value("instances") .
                            " %5d ", $open_data_error_url_count{$tcid},
                            $open_data_error_instance_count{$tcid});

            #
            # Add help link, if there is one
            #
            if ( defined( Open_Data_Check_Testcase_URL($tcid) ) ) {
                $line .= " " . String_Value("help") .
                         " " . Open_Data_Check_Testcase_URL($tcid);
            }

            #
            # Print summary line
            #
            Validator_GUI_Update_Results($open_data_tab, $line);
            Validator_GUI_Update_Results($open_data_tab, "");
        }
    }

    #
    # Print blank line after table.
    #
    foreach $tab ($acc_tab, $link_tab, $metadata_tab, $interop_tab,
                  $open_data_tab, $content_tab, $dept_tab) {
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
#             crawl_depth - crawl depth value
#
# Description:
#
#   This function prints out the report footer.
#
#***********************************************************************
sub Print_Results_Footer {
    my ($reached_crawl_limit, $crawl_depth) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year);
    my ($date, $tab);

    #
    # Print summary results tables
    #
    Print_Results_Summary_Table();

    #
    # Create summary results CSV
    #
    Save_Testcase_Summary_CSV();
    
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
    foreach $tab (@active_results_tabs) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "");

            #
            # Do we add note about crawl limit ?
            #
            if ( $reached_crawl_limit ) {
                Validator_GUI_Update_Results($tab,
                                         String_Value("Crawl limit set to") .
                                         " $crawllimit URLs\n");
            }

            #
            # Do we add note about crawl depth ?
            #
            if ( $crawl_depth > 0 ) {
                Validator_GUI_Update_Results($tab,
                                         String_Value("Crawl depth set to") .
                                         " $crawl_depth\n");
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
    my ($feature_id, $this_doc_feature_list, $url, $count);

    #
    # Get the sorted list of document features
    #
    print "Print_Document_Features_Report\n" if $debug;
    foreach $feature_id (sort(keys(%doc_feature_list))) {
        #
        # Get the list of URLs for this feature
        #
        print "Get list for URL for feature $feature_id\n" if $debug;
        $this_doc_feature_list = $doc_feature_list{$feature_id};

        #
        # Do we have any URLs ?
        #
        if ( keys(%$this_doc_feature_list) > 0 ) {
            #
            # Print list header
            #
            $count = keys(%$this_doc_feature_list);
            print "Print document feature list $feature_id, count = $count\n" if $debug;
            Validator_GUI_Update_Results($doc_features_tab,
                                         String_Value("List of URLs with Document Feature")
                                         . $feature_id . " ($count)\n");

            #
            # Print sorted list of URLs
            #
            foreach $url (sort(keys(%$this_doc_feature_list))) {
                $count = $$this_doc_feature_list{$url};
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
    my ($header, @tqa_results_list, $output, $base, $generated_content);
    my ($sec, $min, $hour, $mday, $mon, $year, $date, $error);
    my ($error_string);

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
            if ( defined($resp->header("Client-Warning")) ) {
                $error .= ", " . $resp->header("Client-Warning");
            }
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
    $mime_type = $header->content_type;

    #
    # Are we doing navigation link checks ?
    #
    if ( $do_navigation_link_check && ($mime_type =~ /text\/html/) ) {
        #
        # Get content from HTTP::Response object.
        #
        $content = Crawler_Decode_Content($resp);

        #
        # Get generated markup (after JavaScript is loaded and run)
        #
        print "Get generated content for web page\n" if $debug;
        if ( $enable_generated_markup ) {
            $generated_content = Crawler_Get_Generated_Content($resp, $url);
        }

        #
        # The above request would have primed the headless user agent cache,
        # but the page may not have fully loaded due to timeouts. Request
        # the mark up again to be sure we have the full generated markup.
        #
        print "Request generated content a 2nd time\n" if $debug;
        if ( $enable_generated_markup ) {
            $generated_content = Crawler_Get_Generated_Content($resp, $url);
            
            #
            # If the generated content is empty, we may have encountered
            # an error with the headless user agent
            #
            if ( $generated_content eq "" ) {
                $error_string = Crawler_Error_String();
                $generated_content = $content;
            }
        }
        else {
            #
            # Set generated content to be the same as the non-generated
            # content.
            #
            $generated_content = $content;
        }

        #
        # Get document language.
        #
        $language = HTML_Document_Language($url, \$content);

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
                               \$content, \$generated_content);

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
                        $language, \%all_link_sets, \%clf_site_links,
                        $logged_in);

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
#             url - URL for page title
#
# Description:
#
#   This function setups up a directory to save the web site content.
#
#***********************************************************************
sub Setup_Content_Saving {
    my ($shared_save_content, $url) = @_;

    #
    # Are we saving content ? if so create a temporary directory
    #
    if ( $shared_save_content ) {
        $shared_save_content_directory = tempdir();

        #
        # Create index file for URL to local file mapping.
        #
        unlink("$shared_save_content_directory/index.html");
        open(HTML, "> $shared_save_content_directory/index.html") ||
            die "Error: Failed to create file $shared_save_content_directory/index.html\n";
        print HTML "<!DOCTYPE html>
<html lang=\"en\">
<head>
<title>Content Inventory for $url</title>
<meta charset=\"utf-8\" />
<style>
table, th, td {
   border: 1px solid black;
} 
</style>
</head>
<body>
<h1>Content Inventory for $url</h1>
<table>
<thead>
<th scope=\"col\">Number</th>
<th scope=\"col\">URL</th>
<th scope=\"col\">Captured Markup</th>
<th scope=\"col\">Mime-type</th>
<th scope=\"col\">Title</th>
<th scope=\"col\">Page Image</th>
</thead>
";
        close(HTML);
    }
}

#***********************************************************************
#
# Name: Finish_Content_Saving
#
# Parameters: filename - directory and filename prefix
#
# Description:
#
#   This function finishes up content saving by completing the index file.
#
#***********************************************************************
sub Finish_Content_Saving {
    my ($filename) = @_;

    my ($saved_content_directory, @files, $path);

    #
    # Finish off index file for URL to local file mapping.
    #
    print "Finish_Content_Saving\n" if $debug;
    if ( $shared_save_content ) {
        open(HTML, ">> $shared_save_content_directory/index.html") ||
        die "Error: Failed to open file $shared_save_content_directory/index.html\n";
        print HTML "</table>
</body>
</html>
";
        close(HTML);

        #
        # Create the saved content directory path
        #
        $saved_content_directory = $filename . "_content";

        #
        # Do we already have a directory ?
        #
        print "Content directory = $saved_content_directory\n" if $debug;
        if ( -d "$saved_content_directory" ) {
            #
            # Remove any old files
            #
            print "Remove files from $saved_content_directory\n" if $debug;
            opendir (DIR, "$saved_content_directory");
            @files = readdir(DIR);
            foreach $path (@files) {
                if ( -f "$saved_content_directory/$path" ) {
                    unlink("$saved_content_directory/$path");
                }
            }
            closedir(DIR);
        }
        else {
            print "Create directory $saved_content_directory\n" if $debug;
            if ( ! mkdir("$saved_content_directory", 0755) ) {
                print "Failed to create saved content directory $saved_content_directory, error = $!\n" if $debug;
            }
        }

        #
        # Copy files from the temporary saved content directory to the
        # final directory
        #
        if ( -d "$shared_save_content_directory" ) {
            #
            # Copy file
            #
            print "Copy files from $shared_save_content_directory\n" if $debug;
            opendir (DIR, "$shared_save_content_directory");
            @files = readdir(DIR);
            foreach $path (@files) {
                if ( -f "$shared_save_content_directory/$path" ) {
                    copy("$shared_save_content_directory/$path", "$saved_content_directory/$path");
                    unlink("$shared_save_content_directory/$path");
                }
            }
            closedir(DIR);

            #
            # Remove the temporary directory
            #
            rmdir($shared_save_content_directory);
        }
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
# Name: Remove_Temporary_Files
#
# Parameters: none
#
# Description:
#
#   This function removes any temporary files that may have been created
# by the program.
#
#***********************************************************************
sub Remove_Temporary_Files {

    my (@files, $path);

    #
    # Clean up any temporary file from a possible previous analysis run
    #
    print "Remove_Temporary_Files\n" if $debug;
    if ( defined($shared_links_details_filename)
         && ($shared_links_details_filename ne "") ) {
        print "Remove link details file $shared_links_details_filename\n" if $debug;
        if ( defined($links_details_fh) ) {
            close($links_details_fh);
        }
        if ( ! unlink($shared_links_details_filename) ) {
            print "Failed to remove file $shared_links_details_filename, error $! \n" if $debug;
        }
    }
    if ( defined($shared_web_page_size_filename)
         && ($shared_web_page_size_filename ne "") ) {
        unlink($shared_web_page_size_filename);
    }
    if ( defined($shared_file_details_filename)
         && ($shared_file_details_filename ne "") ) {
        unlink($shared_file_details_filename);
    }
    if ( defined($shared_testcase_results_summary_csv_filename)
         && ($shared_testcase_results_summary_csv_filename ne "") ) {
        unlink($shared_testcase_results_summary_csv_filename);
    }
    if ( defined($shared_save_content_directory)
         && ($shared_save_content_directory ne "")
         && (-d "$shared_save_content_directory") ) {
        #
        # Remove files
        #
        print "Remove files from $shared_save_content_directory\n" if $debug;
        opendir (DIR, "$shared_save_content_directory");
        @files = readdir(DIR);
        foreach $path (@files) {
            unlink("$shared_save_content_directory/$path");
        }
        closedir(DIR);

        #
        # Remove the temporary directory
        #
        rmdir($shared_save_content_directory);
    }
    
    #
    # Remove temporary files from Validator GUI module
    #
    Validator_GUI_Remove_Temporary_Files();
    
    #
    # Remove any cache or temporary files from the Crawler module
    #
    Crawler_Remove_Temporary_Files();
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
    my ($url, %options) = @_;

    my ($html_profile_table, $html_feature_id, $resp_url, $resp, $tab);
    my ($filename);

    #
    # Clean up any temporary file from a possible previous analysis run
    #
    Remove_Temporary_Files();

    #
    # Set global report_fails_only flag
    #
    $report_fails_only = $options{"report_fails_only"};
    $shared_save_content = $options{"save_content"};
    $process_pdf = $options{"process_pdf"};
    
    #
    # Are we enabling or disabling generated source markup ?
    #
    if ( ! defined($cmnd_line_disable_generated_markup) ) {
        $enable_generated_markup = $options{"enable_generated_markup"};
    }
    else {
        #
        # Command line option disables use of generated source
        #
        $enable_generated_markup = 0;
    }

    #
    # Setup content saving option
    #
    Setup_Content_Saving($shared_save_content, $url);

    #
    # Get link check profile name
    #
    $link_check_profile = $options{$link_check_profile_label};

    #
    # Get markup validation profile name
    #
    $markup_validate_profile = $options{$markup_validate_profile_label};

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
    # Get Web Analytics Check profile name
    #
    $wa_check_profile = $options{$wa_profile_label};

    #
    # Get Interoperability Check profile name
    #
    $interop_check_profile = $options{$interop_profile_label};

    #
    # Get Mobile Check profile name
    #
    $mobile_check_profile = $options{$mobile_profile_label};

    #
    # Get department Check profile name
    #
    $dept_check_profile = $options{$dept_check_profile_label};

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
    # Make sure we are authenticated with the firewall before we start.
    #
    if ( defined($firewall_check_url) ){
        Set_Crawler_HTTP_401_Callback(\&HTTP_401_Callback);
        print "Check firewall URL $firewall_check_url\n" if $debug;
        ($resp_url, $resp) = Crawler_Get_HTTP_Response($firewall_check_url, "");
        
        #
        # Clean up any possible temporary file
        #
        if ( defined($resp) && defined($resp->header("WPSS-Content-File")) ) {
            $filename = $resp->header("WPSS-Content-File");
            unlink($filename);
        }
    }

    #
    # set HTTP code 401 handling (respect or ignore)
    #
    if ( defined($options{$status_401_label})
         && ($options{$status_401_label} eq String_Value("Prompt for credentials")) ) {
        Set_Crawler_HTTP_401_Callback(\&HTTP_401_Callback);
    }
    else {
        Set_Crawler_HTTP_401_Callback(undef);
    }

    #
    # Initialize document and error counts and valid markup flags
    #
    %document_count = ();
    %error_count = ();
    %fault_count = ();
    foreach $tab ($crawled_urls_tab, $validation_tab, $link_tab,
                  $metadata_tab, $acc_tab, $clf_tab, $dept_tab,
                  $interop_tab, $mobile_tab) {
        $document_count{$tab} = 0;
        $error_count{$tab} = 0;
        $fault_count{$tab} = 0;
        $tab_reported_doc_count{$tab} = 0;
    }

    #
    # Initialize markup validity flags and other tool results
    #
    %is_valid_markup = ();
    %clf_other_tool_results = ();
    %image_alt_text_table = ();
    %html_titles = ();
    %title_html_url = ();
    %pdf_titles = ();
    %link_error_url_count = ();
    %link_error_instance_count = ();
    %tqa_error_url_count = ();
    %tqa_error_instance_count = ();
    %mobile_error_url_count = ();
    %mobile_error_instance_count = ();
    %dept_error_url_count = ();
    %dept_error_instance_count = ();
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
    $logged_in = 0;

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
        my (%new_doc_feature_list);
        print "Create document feature list $html_feature_id\n" if $debug;
        $doc_feature_list{$html_feature_id} = \%new_doc_feature_list;
    }

    #
    # Create web page details temporary file
    #
    ($files_details_fh, $shared_file_details_filename) =
       tempfile("WPSS_TOOL_WP_XXXXXXXXXX",
                SUFFIX => '.csv',
                TMPDIR => 1);
    if ( ! defined($files_details_fh) ) {
        print "Error: Failed to create temporary file in Initialize_Tool_Globals\n";
        return;
    }
    binmode $files_details_fh, ":utf8";

    #
    # Add UTF-8 BOM and column headings
    #
    print $files_details_fh chr(0xFEFF);
    print $files_details_fh join(",", @web_page_details_fields) . "\r\n";

    #
    # Create web page links details temporary file
    #
    ($links_details_fh, $shared_links_details_filename) =
       tempfile("WPSS_TOOL_WP_XXXXXXXXXX",
                SUFFIX => '.csv',
                TMPDIR => 1);
    if ( ! defined($links_details_fh) ) {
        print "Error: Failed to create temporary file in Initialize_Tool_Globals\n";
        return;
    }
    binmode $links_details_fh, ":utf8";

    #
    # Add UTF-8 BOM and column headings
    #
    print $links_details_fh chr(0xFEFF);
    print $links_details_fh join(",", @links_details_fields) . "\r\n";
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
    my (@url_list, @url_type, @url_last_modified, @url_size, @url_referrer);
    my ($content, $url, $resp_url, $tab, $i, $depth);
    my (@site_link_check_ignore_patterns, %crawler_options);
    my ($sec, $min, $hour, $mday, $mon, $year, $date, $rc);

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
    Initialize_Tool_Globals($site_dir_e, %crawl_details);

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
    # Print report header in results window.
    #
    Print_Results_Header($site_dir_e, $site_dir_f);

    #
    # Check to see if English and French entry pages exist.
    # If we have login/logout pages, those will be checked instead
    # (the entry pages may be behind the login).
    #
    if ( (! defined($loginpagee)) || ($loginpagee eq "") ) {
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
    # Set crawler options
    #
    $crawler_options{"max_urls_to_return"} = $crawllimit;
    $crawler_options{"max_urls_between_sleeps"} = $max_urls_between_sleeps;
    if ( defined($crawl_details{"crawl_depth"}) ) {
        $crawler_options{"crawl_depth"} = $crawl_details{"crawl_depth"};
        $depth = $crawl_details{"crawl_depth"};
    }
    else {
        $depth = 0;
    }
    if ( defined($crawl_details{"crawler_page_delay_secs"}) ) {
        $crawler_options{"crawler_page_delay_secs"} = $crawl_details{"crawler_page_delay_secs"};
    }

    #
    # Set maximum number of URLs to crawl.
    # Set Link check ignore patters to ignore the logout pages.
    #
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
        print "                   save_content = $shared_save_content\n";
        print "                   process_pdf = $process_pdf\n";
    }
    $rc = Crawl_Site($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f,
                     \%crawler_options,
                     \@url_list, \@url_type, \@url_last_modified,
                     \@url_size, \@url_referrer);

    #
    # Was the crawl successful or was it aborted ?
    #
    if ( $rc ) {
        #
        # Add a note to all tabs indicating that analysis was aborted.
        #
        foreach $tab (@active_results_tabs) {
            if ( defined($tab) ) {
                Validator_GUI_Update_Results($tab,
                                             String_Value("Analysis Aborted"),
                                             0);
            }
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
    # Site crawl is complete, print sorted list of URLs in URLs tab.
    #
    $i = 1;
    foreach $url (sort(@url_list)) {
        Validator_GUI_Update_Results($doc_list_tab, "$i:  $url");
        $i++;
    }

    #
    # Check the number of documents crawled, is it the same as our
    # crawl limit ? If so add a note to the bottom of each report
    # indicating that we reached the crawl limit and there may be more
    # documents on the site that were not analysed.
    #
    if ( ! $cgi_mode ) {
        if ( $crawllimit == @url_list ) {
            Print_Results_Footer(1, $depth);
        }
        else {
            #
            # Site analysis complete, print report footer
            #
            Print_Results_Footer(0, $depth);
        }
    }

    #
    # Close the web page details file and the link details
    #
    close($files_details_fh);
    close($links_details_fh);

    #
    # Close the web page size file
    #
    if ( defined($web_page_size_file_handle) ) {
        close($web_page_size_file_handle);
    }

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
    # Do we have a valid tab and URL ?
    #
    if ( defined($tab) && ($url ne "") ) {
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
        if ( $report_passes_only ) {
            if ( ! $has_errors ) {
                $tab_reported_doc_count{$tab}++;
                Print_URL_To_Tab($tab, $url, $tab_reported_doc_count{$tab});
            }
        }
        elsif ( $report_fails_only ) {
            if ( $has_errors ) {
                $tab_reported_doc_count{$tab}++;
                Print_URL_To_Tab($tab, $url, $tab_reported_doc_count{$tab});
            }
        }
        else {
            $tab_reported_doc_count{$tab}++;
            Print_URL_To_Tab($tab, $url, $tab_reported_doc_count{$tab});
        }
    }
}

#***********************************************************************
#
# Name: Perform_Markup_Validation
#
# Parameters: url - document URL
#             mime_type - content mime type
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function runs the HTML validator.
#
#***********************************************************************
sub Perform_Markup_Validation {
    my ($url, $mime_type, $resp, $content) = @_;

    my ($pattern, @results_list, $result_object, $status);

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
        # Validate the content.
        #
        print "Perform_Markup_Validation on URL\n  --> $url\n" if $debug;
        @results_list = Validate_Markup($url, $markup_validate_profile,
                                        $mime_type, $resp, $content);

        #
        # Get validation status
        #
        $status = 0;
        foreach $result_object (@results_list) {
            $status += $result_object->status;

            #
            # Check for validation failure and set valid markup flag
            #
            if ( $result_object->testcase eq "CSS_VALIDATION" ) {
                $is_valid_markup{"text/css"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "EPUB_VALIDATION" ) {
                $is_valid_markup{"application/epub+zip"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "HTML_VALIDATION" ) {
                $is_valid_markup{"text/html"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "JAVASCRIPT_VALIDATION" ) {
                $is_valid_markup{"application/x-javascript"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "MARC_VALIDATION" ) {
                $is_valid_markup{"application/marc"} = ($result_object->status == 0);
            }
            elsif ( $result_object->testcase eq "XML_VALIDATION" ) {
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
        if ( ! $report_passes_only ) {
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
#             content - content pointer
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
    my (%local_metadata_error_url_count, $title, $value, $name);

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip metadata check\n" if $debug;
        Increment_Counts_and_Print_URL($metadata_tab, $url, 0);

        #
        # We still extract the metadata to populate the title/url table.
        # This is needed to detect HTML & PDF versions of the same document.
        #
        print "Extract_Metadata on URL\n  --> $url\n" if $debug;
        %metadata_results = Extract_Metadata($url, $content);
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
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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

    #
    # Save URL for this document title (if we don't already have one).
    # This is used later when checking accessibility, if a PDF
    # document has a corresponding HTML document, only the HTML is
    # checked for accessibility.  Save with lowercase title as we
    # don't care if the case doesn't match, just that the text matches.
    #
    if ( defined($metadata_results{"title"}) ) {
        $result_object = $metadata_results{"title"};
        $title = lc($result_object->content);
        if ( ($title ne "") && (! defined($title_html_url{$title})) ) {
            $title_html_url{$title} = $url;
        }
    }
    else {
        $title = "";
    }
    $html_titles{$url} = $title;

    #
    # Save metadata web page details
    #
    foreach $name ("title", "dcterms.issued", "dcterms.modified", "dcterms.subject") {
        if ( defined($metadata_results{$name}) ) {
            $result_object = $metadata_results{$name};
            $web_page_details_values{$name} = decode_entities($result_object->content);
        }
        else {
            $web_page_details_values{$name} = "";
        }
    }

    #
    # Check for dcterms.creator or dc.creator
    #
    $name = "dcterms.creator";
    if ( defined($metadata_results{$name}) ) {
        $result_object = $metadata_results{$name};
        $web_page_details_values{$name} = $result_object->content;
    }
    elsif ( defined($metadata_results{"dc.creator"}) ) {
        $result_object = $metadata_results{"dc.creator"};
        $web_page_details_values{$name} = $result_object->content;
    }
    else {
        $web_page_details_values{$name} = "";
    }
}

#***********************************************************************
#
# Name: Perform_PDF_Properties_Check
#
# Parameters: url - document URL
#             content - content pointer
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
    my (@pdf_property_results, $output_line);
    my (%local_metadata_error_url_count, $title);

    #
    # Is this URL marked as archived on the web ?
    #
    %pdf_property_results = ();
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip pdf properties check\n" if $debug;
        Increment_Counts_and_Print_URL($metadata_tab, $url, 0);

        #
        # We still extract the properties to populate the title/url table.
        # This is needed to detect HTML & PDF versions of the same document.
        #
        print "PDF_Files_Get_Properties_From_Content on URL\n  --> $url\n" if $debug;
        %pdf_property_results = PDF_Files_Get_Properties_From_Content($content);
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
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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

    #
    # Do we have a title for this URL ?
    #
    if ( defined($pdf_property_results{"Title"}) ) {
        $result_object = $pdf_property_results{"Title"};
        $title = lc($result_object->content);
    }
    else {
        $title = "";
    }
    $pdf_titles{$url} = $title;
    $web_page_details_values{"title"} = $title;
}

#***********************************************************************
#
# Name: Perform_TQA_Check
#
# Parameters: url - document URL
#             content - content pointer
#             language - URL language
#             mime_type - content mime-type
#             resp - HTTP::Response object
#             logged_in - flag to indicate if we are logged into an
#               application
#
# Description:
#
#   This function performs a number of technical QA tests on the content.
#
#***********************************************************************
sub Perform_TQA_Check {
    my ($url, $content, $language, $mime_type, $resp, $logged_in) = @_;

    my ($url_status, $status, $message, $source_lin, $tcid);
    my (@tqa_results_list, $result_object, $output_line);
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
                if ( defined($doc_feature_list{"alternate/autre format"}) ) {
                    $list_ref = $doc_feature_list{"alternate/autre format"};
                    print "Add to document feature list \"alternate/autre format\", url = $url\n" if $debug;
                    $$list_ref{$url} = 1;
                }
                return;
            }
        }
    }

    #
    # Check for rel="alternate" on the link to this document.
    # If that attribute is present it is an alternate format of
    # another document and is not subject to accessibility
    # testing.  The check is only carried out for non HTML documents.
    #
    if ( ! ( $mime_type =~ /text\/html/ ) ) {
        if ( Link_Check_Has_Rel_Alternate($url) ) {
            print "URL is an alternate format, skipping TQA check\n" if $debug;

            #
            # Record this URL as an alternate format
            #
            if ( defined($doc_feature_list{"alternate/autre format"}) ) {
                $list_ref = $doc_feature_list{"alternate/autre format"};
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
    # Check the document
    #
    @tqa_results_list = TQA_Check($url, $language, $tqa_check_profile,
                                  $mime_type, $resp, $content, \@links,
                                  $logged_in);

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
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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

#***********************************************************************
#
# Name: Perform_CLF_Check
#
# Parameters: url - document URL
#             content - content pointer
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

    my ($url_status, $status, $message, $source_line, $tcid);
    my (@clf_results_list, $result_object, $output_line, @wa_results_list);
    my (%local_clf_error_url_count, @content_links, $pattern);
    my ($found_web_analytics, $analytics_type, $list_ref);

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # Check for all archived on the web markers
        #
        @clf_results_list = CLF_Check_Archive_Check($url, $language,
                                                    $clf_check_profile,
                                                    $mime_type, $resp,
                                                    $content);
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
                            \%all_link_sets, \%clf_site_links, $logged_in);
        }
    }

    #
    # Check Web Analytics
    #
    @wa_results_list = Web_Analytics_Check($url, $language, $wa_check_profile,
                                           $mime_type, $resp, $content);

    #
    # Add Web Analytics results to the CLF results
    #
    foreach $result_object (@wa_results_list) {
        push(@clf_results_list, $result_object);
    }

    #
    # Check if this URL has web analytics code on the page.  The above
    # checks were for invalid analytics, we want to record a HTML feature
    # if the page has analytics.
    #
    ($found_web_analytics, $analytics_type) = Web_Analytics_Has_Web_Analytics();
    if ( $found_web_analytics ) {
        print "URL has Web Analytics\n" if $debug;

        #
        # Record this URL as having web analytics
        #
        if ( defined($doc_feature_list{"Web Analytics/Web analytique"}) ) {
            $list_ref = $doc_feature_list{"Web Analytics/Web analytique"};
            print "Add to document feature list \"Web Analytics/Web analytique\", url = $url\n" if $debug;
            $$list_ref{$url} = 1;
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
    if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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
# Name: Perform_Readability_Analysis
#
# Parameters: url - document URL
#             content - content pointer
#             language - URL language
#             mime_type - content mime-type
#             resp - HTTP::Response object
#
# Description:
#
#   This function performs a readability analysis of the content.
#
#***********************************************************************
sub Perform_Readability_Analysis {
    my ($url, $content, $language, $mime_type, $resp) = @_;

    my (%scores);

    #
    # Compute readability score
    #
    print "Perform_Readability_Analysis on URL\n  --> $url\n" if $debug;
    %scores = Readability_Grade_HTML($url, $content);
    
    #
    # Save Flesch-Kincaid score value
    #
    $web_page_details_values{"flesch-kincaid"} = $scores{"Flesch-Kincaid"};
}

#***********************************************************************
#
# Name: Perform_Interop_Check
#
# Parameters: url - document URL
#             content - content pointer
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
    my (@interop_results_list, $result_object, $output_line);
    my (%local_interop_error_url_count, @content_links, $pattern);
    my ($feed_object, $title, $key, $list_ref);

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

            #
            # Check links for Interoperability
            #
            Interop_Check_Links(\@interop_results_list, $url, $title,
                                $mime_type, $interop_check_profile,
                                $language, \%all_link_sets);

            #
            # Does this URL have HTML Data mark-up ?
            #
            if ( Interop_Check_Has_HTML_Data($url) ) {
                #
                # Add to HTML features list
                #
                $key = "HTML Data/données HTML";
                if ( defined($doc_feature_list{$key}) ) {
                    $list_ref = $doc_feature_list{$key};
                    print "Add to document feature list $key, url = $url\n" if $debug;
                    $$list_ref{$url} = 1;
                }
            }
        }
        #
        # If this appears to be a Web feed, get the feed details
        #
        elsif ( ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/rss\+xml/) ||
                ($mime_type =~ /application\/ttml\+xml/) ||
                ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            $feed_object = Interop_Check_Feed_Details($url, $content);
            if ( defined($feed_object) ) {
                push(@web_feed_list, $feed_object);

                #
                # Save "Web Feed" feature
                #
                $key = "Web feed/fil de nouvelles";
                if ( defined($doc_feature_list{$key}) ) {
                    $list_ref = $doc_feature_list{$key};
                    print "Add to document feature list $key, url = $url\n" if $debug;
                    $$list_ref{$url} = 1;
                }
            }
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@interop_results_list ) {
            if ( $result_object->status != 0 ) {
                #
                # Interop Check error, we can stop looking for more errors
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
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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
# Name: Perform_Department_Check
#
# Parameters: url - document URL
#             language - URL language
#             mime_type - document mime type
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function performs a number of QA tests departmental check points.
#
#***********************************************************************
sub Perform_Department_Check {
    my ( $url, $language, $mime_type, $resp, $content ) = @_;

    my ($url_status, $key, $status, $message);
    my (@content_results_list, $result_object, $output_line);
    my (%local_error_url_count, @headings, $first_h1, $h);

    #
    # Check the document
    #
    print "Perform_Department_Check on URL\n  --> $url\n" if $debug;
    @content_results_list = Dept_Check($url, $language, $dept_check_profile,
                                       $mime_type, $resp, $content);

    #
    # Get list of headings from the document and save them in a
    # global table indexed by URL
    #
    if ( $mime_type =~ /text\/html/ ) {
        @headings = Content_Check_Get_Headings();
        $headings_table{$url} = \@headings;

        #
        # Get first H1 heading
        #
        if ( @headings > 0 ) {
            #
            # Take first heading incase we don't find a h1
            #
            $first_h1 = $headings[0];
            foreach $h (@headings) {
                #
                # Is this a h1 ?
                #
                if ( $h =~ /^1:/ ) {
                    $first_h1 = $h;
                    last;
                }
            }

            #
            # Strip off heading level number
            #
            $first_h1 =~ s/^\d://g;
        }
        else {
            $first_h1 = "";
        }
        $web_page_details_values{"h1"} = decode_entities($first_h1);
    }

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip department check\n" if $debug;
        Increment_Counts_and_Print_URL($dept_tab, $url, 0);
    }
    else {
        #
        # If the document is an HTML document, check links
        #
        if ( $mime_type =~ /text\/html/ ) {
            Dept_Check_Links(\@content_results_list, $url,
                             $dept_check_profile, $language,
                             \%all_link_sets, $logged_in);
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@content_results_list) {
            if ( $result_object->status != 0 ) {
                #
                # Department Check error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($dept_tab, $url,
                                       ($url_status != $tool_success));

        #
        # Print results if it is a failure.
        #
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
            foreach $result_object (@content_results_list) {
                if ( $result_object->status != 0 ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($dept_error_instance_count{$result_object->description}) ) {
                        $dept_error_instance_count{$result_object->description} = 1;
                        $dept_error_url_count{$result_object->description} = 1;
                    }
                    else {
                       $dept_error_instance_count{$result_object->description}++;
                       $dept_error_url_count{$result_object->description}++;
                    }

                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($dept_tab, $result_object);
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
#             content - content pointer
#
# Description:
#
#   This function runs the document feature check tool on the
# supplied content.
#
#***********************************************************************
sub Perform_Feature_Check {
    my ($url, $mime_type, $content) = @_;

    my (%html_feature_line_no, %html_feature_column_no,
        %html_feature_count, $key, $list_ref);

    #
    # Is this URL archived on the web ? if it is we don't
    # report any document features
    #
    print "Perform_Feature_Check on URL\n  --> $url\n" if $debug;
    if ( $is_archived ) {
        #
        # Is this URL exempt from the standard on web accessibility ?
        #
        if ( $tqa_check_exempted ) {
            $key = "archive accessibility exempt/accessibilité exonérés";
        }
        else {
            #
            # "Archived on the Web" feature
            #
            $key = "archive";
        }
        if ( defined($doc_feature_list{$key}) ) {
            print "Add to document feature list $key, url = $url\n" if $debug;
            $list_ref = $doc_feature_list{$key};
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
            $list_ref = $doc_feature_list{$key};
            if ( ! defined($list_ref) ) {
                my (%new_doc_feature_list);
                print "Create document feature list $key\n" if $debug;
                $doc_feature_list{$key} = \%new_doc_feature_list;
                $list_ref = \%new_doc_feature_list;
            }
            print "Add to document feature list $key, url = $url\n" if $debug;
            $$list_ref{$url} = $html_feature_count{$key};
        }

        if ( $debug) {
            print "doc_feature_list\n";
            foreach $key (sort(keys(%doc_feature_list))) {
                print "key = $key\n";
            }
        }
    }
}

#***********************************************************************
#
# Name: Perform_Mobile_Check
#
# Parameters: url - url of document to check
#             language - language of page
#             mime_type - mime-type of document
#             resp - HTTP::Response object
#             content - content pointer
#             generated_content - content pointer
#
# Description:
#
#   This function runs the mobile checker on the URL
#
#***********************************************************************
sub Perform_Mobile_Check {
    my ( $url, $language, $mime_type, $resp, $content, $generated_content) = @_;

    my ($url_status, @mobile_results_list, $tcid);
    my ($result_object, $status, %local_mobile_error_url_count);
    my ($size_string);

    #
    # Is this URL marked as archived on the web ?
    #
    if ( $is_archived ) {
        #
        # We don't report any faults
        #
        print "Archived document, skip mobile check\n" if $debug;
        Increment_Counts_and_Print_URL($mobile_tab, $url, 0);
    }
    else {
        #
        # Compute web page size
        #
        $size_string = Mobile_Check_Compute_Page_Size($url, $resp,
                                                      \%all_link_sets);

        #
        # Save web page size values
        #
        ($web_page_size_file_handle, $shared_web_page_size_filename) =
              Mobile_Check_Save_Web_Page_Size($web_page_size_file_handle,
                                              $shared_web_page_size_filename,
                                              $url, $size_string);

        #
        # Perform mobile optimization checks
        #
        @mobile_results_list = Mobile_Check($url, $language, $mobile_check_profile,
                                            $mime_type, $resp, $content,
                                            $generated_content);

        #
        # If the document is an HTML document, check links
        #
        if ( $mime_type =~ /text\/html/ ) {
            Mobile_Check_Links(\@mobile_results_list, $url,
                               $mobile_check_profile, $language,
                               \%all_link_sets, $content);
        }

        #
        # Determine overall URL status
        #
        $url_status = $tool_success;
        foreach $result_object (@mobile_results_list) {
            if ( $result_object->status != 0 ) {
                #
                # Error, we can stop looking for more errors
                #
                $url_status = $tool_error;
                last;
            }
        }

        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($mobile_tab, $url,
                                       ($url_status == $tool_error));

        #
        # Print results if it is a failure.
        #
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
            #
            # Print failures
            #
            foreach $result_object (@mobile_results_list) {
                $status = $result_object->status;
                if ( defined($status) && ($status != 0) ) {
                    #
                    # Increment error instance count
                    #
                    if ( ! defined($mobile_error_instance_count{$result_object->description}) ) {
                        $mobile_error_instance_count{$result_object->description} = 1;
                    }
                    else {
                        $mobile_error_instance_count{$result_object->description}++;
                    }

                    #
                    # Set URL error count
                    #
                    $local_mobile_error_url_count{$result_object->description} = 1;

                    #
                    # Print error
                    #
                    Validator_GUI_Print_TQA_Result($mobile_tab, $result_object);
                }
            }

            #
            # Add blank line in report
            #
            Validator_GUI_Update_Results($mobile_tab, "");
        }

        #
        # Set global URL error count
        #
        foreach (keys %local_mobile_error_url_count) {
            $mobile_error_url_count{$_}++;
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
#             content - content pointer
#             language - content language
#             generated_content - generated content pointer
#
# Description:
#
#   This function runs the link checker on the URL
#
#***********************************************************************
sub Perform_Link_Check {
    my ($url, $mime_type, $resp, $content, $language, $generated_content) = @_;

    my ($url_status, @link_results_list, $anchor_list, $href, $clean_url);
    my ($i, $status, $link, $breadcrumb, $list_addr);
    my ($result_object, $base, %local_link_error_url_count);

    #
    # If we are in CGI mode, skip link checks
    #
    if ( $cgi_mode ) {
        return;
    }

    #
    # Determine the base URL for any relative URLs.  Usually this is
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
    # Get the list of all anchors in this URL.  Force a refresh in case we
    # have already seen this URL.
    #
    if ( $mime_type =~ /text\/html/ ) {
        $anchor_list = Extract_Anchors($url, $resp, $generated_content, 1);
    }

    #
    # Get links from document, save list in the global @links variable.
    # We need the list of links (and mime-types) in the document features
    # check.
    #
    print "Extract links from document\n  --> $url\n" if $debug;
    @links = Extract_Links($url, $base, $language, $mime_type, $content,
                           $generated_content);

    #
    # Print link details to the CSV file
    #
    $clean_url = $url;
    $clean_url =~ s/"/""/g;
    if ( defined($links_details_fh) ) {
        foreach $link (@links) {
            #
            # Print details for anchor links only.
            # Skip javascript and mailto links.
            #
            $href = $link->abs_url();
            if ( ($link->link_type() eq "a") &&
                 ! ($href =~ /^javascript:/) &&
                 ! ($href =~ /^mailto:/) ) {
                $href =~ s/"/""/g;
                print $links_details_fh "\"$url\"," . $link->link_type() . "," .
                                        $link->line_no() . "," .
                                        $link->column_no() . ",\"$href\"\r\n";
            }
        }
    }
    
    #
    # Get links from all document subsections
    #
    %all_link_sets = Extract_Links_Subsection_Links("ALL");

    #
    # Construct breadcrumb trail from the set of breadcrumb links
    #
    $breadcrumb = "";
    if ( defined($all_link_sets{"BREADCRUMB"}) ) {
        $list_addr = $all_link_sets{"BREADCRUMB"};
        foreach $link (@$list_addr) {
            if ( $breadcrumb ne "" ) {
                $breadcrumb .= " | " . $link->anchor;
            }
            else {
                $breadcrumb = $link->anchor;
            }
        }
    }

    #
    # Save breadcrumb details for web page
    #
    $web_page_details_values{"breadcrumb"} = decode_entities($breadcrumb);

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
        # Check links
        #
        print "Check links in URL\n  --> $url\n" if $debug;
        @link_results_list = Link_Checker($url, $language, $link_check_profile,
                                          $mime_type, \@links);

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
        if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
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
        Alt_Text_Check_Record_Image_Details(\%image_alt_text_table, $url,
                                                @links);
    }
}

#***********************************************************************
#
# Name: Record_EPUB_Accessibility_Check_Results
#
# Parameters: url - dataset file URL
#             file_number - EPUB file number
#             results - list of testcase results
#
# Description:
#
#   This function records EPUB accessibility checks results.
#
#***********************************************************************
sub Record_EPUB_Accessibility_Check_Results {
    my ($url, $file_number, @results) = @_;


    my ($url_status, $status, $result_object);
    my (%local_tqa_error_url_count, $number);

    #
    # Check EPUB accessibility results
    #
    print "Record EPUB accessibility check results, file number = $file_number\n" if $debug;
    $url_status = $tool_success;
    foreach $result_object (@results) {
        if ( $result_object->status != $tool_success ) {
            #
            # EPUB accessibility error, we can stop looking for more errors
            #
            $url_status = $tool_error;
            last;
        }
    }
    
    #
    # Check EPUB file number.  If the number is 0, this is the
    # main EPUB file container.
    #
    if ( defined($acc_tab) && ($url ne "") ) {
        if ( $file_number == 0 ) {
            $epub_file_count{$acc_tab} = 0;
            $epub_error_count{$acc_tab} = 0;
            $document_count{$acc_tab}++;
        }

        #
        # Increment epub error counter
        #
        if ( $url_status == $tool_error ) {
            $epub_error_count{$acc_tab}++;
            
            #
            # Increment the accessibility tab error count
            # only of the first epub error.  We only count the
            # epub file for a single accessability tab error
            # otherwise we may end up with more acc tab errors
            # than URLs checked.
            #
            if ( $epub_error_count{$acc_tab} == 1 ) {
                $error_count{$acc_tab}++;
            }
        }

        #
        # Print URL
        #
        if ( $report_passes_only ) {
            if ( $url_status != $tool_error ) {
                if ( $epub_error_count{$acc_tab} == 1 ) {
                    $tab_reported_doc_count{$acc_tab}++;
                    $number = $tab_reported_doc_count{$acc_tab};
                }
                else {
                    $epub_file_count{$acc_tab}++;
                    $number = $tab_reported_doc_count{$acc_tab} . "." .
                              $epub_file_count{$acc_tab};
                }
                Print_URL_To_Tab($acc_tab, $url, $number);
            }
        }
        elsif ( $report_fails_only ) {
            if ( $url_status == $tool_error ) {
                if ( $epub_error_count{$acc_tab} == 1 ) {
                    $tab_reported_doc_count{$acc_tab}++;
                    $number = $tab_reported_doc_count{$acc_tab};
                }
                else {
                    $epub_file_count{$acc_tab}++;
                    $number = $tab_reported_doc_count{$acc_tab} . "." .
                              $epub_file_count{$acc_tab};
                }
                Print_URL_To_Tab($acc_tab, $url, $number);
            }
        }
        else {
            $epub_file_count{$acc_tab}++;
            if ( $epub_file_count{$acc_tab} == 1 ) {
                $tab_reported_doc_count{$acc_tab}++;
                $number = $tab_reported_doc_count{$acc_tab};
            }
            else {
                $number = $tab_reported_doc_count{$acc_tab} . "." .
                          $epub_file_count{$acc_tab};
            }
            Print_URL_To_Tab($acc_tab, $url, $number);
        }
    }

    #
    # Print results if it is a failure.
    #
    if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
        #
        # Print failures
        #
        foreach $result_object (@results) {
            $status = $result_object->status;
            if ( defined($status) && ($status != 0) ) {
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
        # Add blank line in report
        #
        Validator_GUI_Update_Results($acc_tab, "");
    }

    #
    # Set global URL error count
    #
    foreach (keys %local_tqa_error_url_count) {
        $tqa_error_url_count{$_}++;
    }
    if ( $debug ) {
      print "epub_file_count{acc_tab} = " . $epub_file_count{$acc_tab} . "\n";
      print "epub_error_count{acc_tab} = " . $epub_error_count{$acc_tab} . "\n";
      print "document_count{acc_tab} = " . $document_count{$acc_tab} . "\n";
    }
}

#***********************************************************************
#
# Name: Perform_EPUB_Check
#
# Parameters: url - EPUB URL
#             content - content pointer
#             language - content language
#             mime_type - mime-type of document
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks EPUB documents.
#
#***********************************************************************
sub Perform_EPUB_Check {
    my ($url, $content, $language, $mime_type, $resp) = @_;

    my ($epub_file, $pattern, @tqa_results_list, @links);
    my ($results_list_addr, $opf_file_names, $epub_uncompressed_dir);
    my ($file_count, $epub_opf_object, $manifest_list, $list_item);
    my ($file_name, $opf_file_name, %properties);
    
    #
    # Do we want to skip checking of this document ?
    #
    print "Perform_EPUB_Check\n  --> $url\n" if $debug;
    foreach $pattern (@tqa_url_skip_patterns) {
        if ( $url =~ /$pattern/i ) {
            print "Skipping check on EPUB $url, matches pattern $pattern\n" if $debug;
            return;
        }
    }

    #
    # If we are doing process monitoring, print out some resource
    # usage statistics
    #
    Print_Resource_Usage($url, "EPUB TQA_Check",
                         $document_count{$crawled_urls_tab});

    #
    # Tell TQA Check module whether or not documents have
    # valid markup.
    #
    Set_TQA_Check_Valid_Markup($url, %is_valid_markup);

    #
    # Check the accessibility of the complete EPUB document
    #
    @tqa_results_list = TQA_Check($url, $language, $tqa_check_profile,
                                  $mime_type, $resp, $content, \@links,
                                  $logged_in);

    #
    # Record results
    #
    Record_EPUB_Accessibility_Check_Results($url, 0, @tqa_results_list);

    #
    # Get the META-INF/container.xml file and the list of OPF rootfiles
    # specified in it. The OPF files contain the details of the rest
    # of the EPUB files.
    #
    $file_count = 1;
    Validator_GUI_Start_URL($crawled_urls_tab, "$url:META-INF/container.xml", "",
                            0, $document_count{$crawled_urls_tab} . ".$file_count");
    print "Parse and get the META-INF/container.xml and OPF file\n" if $debug;
    ($results_list_addr, $opf_file_names, $epub_uncompressed_dir) =
        EPUB_Check_Get_OPF_File($url, $resp, $tqa_check_profile, $content);

    #
    # Record results
    #
    Record_EPUB_Accessibility_Check_Results($url, $file_count, @$results_list_addr);
    Validator_GUI_End_URL($crawled_urls_tab, "$url:META-INF/container.xml", "", 0);

    #
    # Parse the list OPF container files to get the other EPUB files details
    #
    if ( @$opf_file_names != 0 ) {
        #
        # Go through the list of OPF files in reverse order.
        # We want to end up with the first file as the last one parsed. The
        # first OPF file represents the default rendition of the EPUB, and
        # this rendition must be the accessible one.
        #
        $file_count++;
        foreach $opf_file_name (reverse(@$opf_file_names)) {
            Validator_GUI_Start_URL($crawled_urls_tab, "$url:$opf_file_name", "",
                                    0, $document_count{$crawled_urls_tab} . ".$file_count");
            undef($epub_opf_object);
            ($results_list_addr, $epub_opf_object) = EPUB_Check_OPF_Parse($url,
                                                               $epub_uncompressed_dir,
                                                               $opf_file_name,
                                                               $tqa_check_profile);

            #
            # Record results
            #
            Record_EPUB_Accessibility_Check_Results("$url:$opf_file_name",
                                                    $file_count,
                                                    @$results_list_addr);
            Validator_GUI_End_URL($crawled_urls_tab, "$url:$opf_file_name", "", 0);
        }

        #
        # Check each of the EPUB content files for accessibility checks
        # Since the above checks of the OPF files was done in reverse order,
        # we will only be checking the files of the default rendition.
        #
        print "Check files in OPF container\n" if $debug;
        if ( defined($epub_opf_object) ) {
            $manifest_list = $epub_opf_object->manifest();
            for $list_item (@$manifest_list) {
                #
                # Is this a navigation file? If so skip it for now,
                # we will check the navigation files last.
                #
                %properties = $list_item->properties();
                if ( defined($properties{"nav"}) ) {
                    print "Skip nav item\n" if $debug;
                    next;
                }
                
                #
                # Are we aborting the URL analysis ? Check crawler module flag
                # in case the abort was called from another thread
                # (i.e. the UI layer)
                #
                if ( Crawler_Abort_Crawl_Status() == 1 ) {
                    last;
                }

                #
                # Increment found count and get the file name
                #
                $file_count++;
                $file_name = $list_item->href();
                Validator_GUI_Start_URL($crawled_urls_tab, "$url:$file_name", "",
                                        0, $document_count{$crawled_urls_tab} . ".$file_count");

                #
                # Perform accessibility checks on this manifest file
                #
                @tqa_results_list = EPUB_Check_Manifest_File($epub_opf_object,
                                          $list_item,
                                          "$url:$file_name",
                                          $tqa_check_profile,
                                          $file_name, $epub_uncompressed_dir);

                #
                # Record accessibility results
                #
                Record_EPUB_Accessibility_Check_Results("$url:$file_name",
                                                        $file_count,
                                                        @tqa_results_list);
                Validator_GUI_End_URL($crawled_urls_tab, "$url:$file_name", "", 0);
            }

            #
            # Check navigation files
            #
            print "Check navigation files in OPF container\n" if $debug;
            for $list_item (@$manifest_list) {
                #
                # Is this a navigation file? If not skip it as we
                # have already processed it above.
                #
                %properties = $list_item->properties();
                if ( ! defined($properties{"nav"}) ) {
                    print "Skip non-nav item\n" if $debug;
                    next;
                }

                #
                # Are we aborting the URL analysis ? Check crawler module flag
                # in case the abort was called from another thread
                # (i.e. the UI layer)
                #
                if ( Crawler_Abort_Crawl_Status() == 1 ) {
                    last;
                }

                #
                # Increment found count and get the file name
                #
                $file_count++;
                $file_name = $list_item->href();
                Validator_GUI_Start_URL($crawled_urls_tab, "$url:$file_name", "",
                                        0, $document_count{$crawled_urls_tab} . ".$file_count");

                #
                # Perform accessibility checks on this manifest file
                #
                @tqa_results_list = EPUB_Check_Manifest_File($epub_opf_object,
                                          $list_item,
                                          "$url:$file_name",
                                          $tqa_check_profile,
                                          $file_name, $epub_uncompressed_dir);

                #
                # Record accessibility results
                #
                Record_EPUB_Accessibility_Check_Results("$url:$file_name",
                                                        $file_count,
                                                        @tqa_results_list);
                Validator_GUI_End_URL($crawled_urls_tab, "$url:$file_name", "", 0);
            }
        }
    }

    #
    # Cleanup temporary files from EPUB file
    #
    EPUB_Check_Cleanup($epub_uncompressed_dir);

    #
    # Remove local epub file
    #
    if ( defined($resp) && (defined($resp->header("WPSS-Content-File"))) ) {
        $epub_file = $resp->header("WPSS-Content-File");
        print "Remove epub file $epub_file\n" if $debug;
        if ( ! unlink($epub_file) ) {
            print "Error, failed to remove EPUB file $epub_file\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Record_Open_Data_Check_Results
#
# Parameters: url - dataset file URL
#             results - list of testcase results
#
# Description:
#
#   This function records open data checks results.
#
#***********************************************************************
sub Record_Open_Data_Check_Results {
    my ( $url, @results ) = @_;

    my ($url_status, $status, $result_object);
    my (%local_open_data_error_url_count);

    #
    # Check open data results
    #
    print "Record open data check results\n" if $debug;
    $url_status = $tool_success;
    foreach $result_object (@results) {
        if ( $result_object->status != $tool_success ) {
            #
            # Open data error, we can stop looking for more errors
            #
            $url_status = $tool_error;
            last;
        }
    }

    #
    # Increment document & error counters
    #
    Increment_Counts_and_Print_URL($open_data_tab, $url,
                                   ($url_status == $tool_error));

    #
    # Print results if it is a failure.
    #
    if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
        #
        # Print failures
        #
        foreach $result_object (@results) {
            $status = $result_object->status;
            if ( defined($status) && ($status != 0) ) {
                #
                # Increment error instance count
                #
                if ( ! defined($open_data_error_instance_count{$result_object->description}) ) {
                    $open_data_error_instance_count{$result_object->description} = 1;
                }
                else {
                    $open_data_error_instance_count{$result_object->description}++;
                }

                #
                # Set URL error count
                #
                $local_open_data_error_url_count{$result_object->description} = 1;

                #
                # Print error
                #
                Validator_GUI_Print_TQA_Result($open_data_tab, $result_object);
            }
        }

        #
        # Add blank line in report
        #
        Validator_GUI_Update_Results($open_data_tab, "");
    }

    #
    # Set global URL error count
    #
    foreach (keys %local_open_data_error_url_count) {
        $open_data_error_url_count{$_}++;
    }
}

#***********************************************************************
#
# Name: Record_Open_Data_Content_Check_Results
#
# Parameters: url - dataset file URL
#             results - list of testcase results
#
# Description:
#
#   This function records open data content checks results.
#
#***********************************************************************
sub Record_Open_Data_Content_Check_Results {
    my ( $url, @results ) = @_;

    my ($url_status, $status, $result_object);
    my (%local_open_data_error_url_count);

    #
    # Check open data results
    #
    print "Record open data content check results\n" if $debug;
    $url_status = $tool_success;
    foreach $result_object (@results) {
        if ( $result_object->status != $tool_success ) {
            #
            # Open data error, we can stop looking for more errors
            #
            $url_status = $tool_error;
            last;
        }
    }

    #
    # Increment document & error counters
    #
    Increment_Counts_and_Print_URL($content_tab, $url,
                                   ($url_status == $tool_error));

    #
    # Print results if it is a failure.
    #
    if ( ($url_status == $tool_error) && ( ! $report_passes_only ) ) {
        #
        # Print failures
        #
        foreach $result_object (@results) {
            $status = $result_object->status;
            if ( defined($status) && ($status != 0) ) {
                #
                # Increment error instance count
                #
                if ( ! defined($content_error_instance_count{$result_object->description}) ) {
                    $content_error_instance_count{$result_object->description} = 1;
                }
                else {
                    $content_error_instance_count{$result_object->description}++;
                }

                #
                # Set URL error count
                #
                $local_open_data_error_url_count{$result_object->description} = 1;

                #
                # Print error
                #
                Validator_GUI_Print_TQA_Result($content_tab, $result_object);
            }
        }

        #
        # Add blank line in report
        #
        Validator_GUI_Update_Results($content_tab, "");
    }

    #
    # Set global URL error count
    #
    foreach (keys %local_open_data_error_url_count) {
        $content_error_url_count{$_}++;
    }
}

#***********************************************************************
#
# Name: Perform_Open_Data_Check
#
# Parameters: url - dataset file URL
#             format - optional content format
#             data_file_type - type of dataset file
#             resp - HTTP::Response object
#
# Description:
#
#   This function runs open data checks on the supplied URL.
#
#***********************************************************************
sub Perform_Open_Data_Check {
    my ($url, $format, $data_file_type, $resp) = @_;

    my ($contents, $zip, @members, $member_name, $header, $mime_type);
    my (@results, $member_url, $member, $filename, $t, $size, $h);
    my ($rows, $cols, $sha, $checksum, $resp_valid);

    #
    # Check for possible ZIP content (a zip file containing the
    # open data files).
    #
    print "Perform_Open_Data_Check check for content\n" if $debug;
    if ( defined($resp) && $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;
        $resp_valid = 1;
    }
    else {
        #
        # Error in getting URL.
        # Unknown mime-type
        #
        $mime_type = "";
        $resp_valid = 0;
    }

    #
    # If mime-type is a ZIP file, get at ZIP archive content.
    #
    if ( $resp_valid &&
         (($mime_type =~ /application\/zip/) ||
          ($url =~ /\.zip$/i)) ) {
        print "Open data ZIP file\n" if $debug;
        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "Open_Data_Check_Zip_Content",
                             $document_count{$crawled_urls_tab});

        #
        # Get the ZIP file contents
        #
        ($zip, @results) = Open_Data_Check_Zip_Content($url,
                                                       $open_data_check_profile,
                                                       $data_file_type,
                                                       $resp);

        #
        # Record any errors from the ZIP container (e.g. malformed
        # zip file).
        #
        Record_Open_Data_Check_Results($url, @results);

        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "after Open_Data_Check_Zip_Content",
                             $document_count{$crawled_urls_tab});

        #
        # Get file details
        #
        if ( defined($resp) && $resp->is_success ) {
            $filename = $resp->header("WPSS-Content-File");
            $size = -s $filename;

            #
            # Compute SHA-1 checksum for this file
            #
            $sha = Digest::SHA->new("SHA-1");
            $sha->addfile($filename);
            $checksum = $sha->hexdigest;
        }
        else {
            $filename = "";
            $size = 0;
            $checksum = "";
        }
        $t = $url;
        $t =~ s/"/""/g;

        #
        # Add file details to CSV
        #
        print $files_details_fh "$data_file_type,\"$t\",\"$mime_type\",\"$checksum\",$size,,,,\r\n";

        #
        # Process each member of the zip archive
        #
        if ( defined($zip) ) {
            @members = $zip->members();
            foreach $member (@members) {
                #
                # Get file name
                #
                $member_name = $member->fileName();
                
                #
                # If we are doing process monitoring, print out some resource
                # usage statistics
                #
                Print_Resource_Usage("$url:$member_name", "before Open_Data_Check",
                                     $document_count{$crawled_urls_tab} + 1);

                #
                # Get contents for this member in a file
                #
                print "Process zip member $member_name\n" if $debug;
                (undef, $filename) = tempfile("WPSS_TOOL_WP_XXXXXXXXXX",
                                              TMPDIR => 1,
                                              OPEN => 0);
                print "Extract member to $filename\n" if $debug;
                $member->extractToFileNamed($filename);

                #
                # Create a URL for the member of the ZIP
                #
                $member_url = "$url:$member_name";
                push(@all_urls, "$data_file_type $member_url");
                $document_count{$crawled_urls_tab}++;
                Validator_GUI_Start_URL($crawled_urls_tab, $member_url, "", 0,
                                        $document_count{$crawled_urls_tab});

                #
                # Compute SHA-1 checksum for this file
                #
                $sha = Digest::SHA->new("SHA-1");
                $sha->addfile($filename);
                $checksum = $sha->hexdigest;

                #
                # Perform technical checks on this file
                #
                @results = Open_Data_Check($member_url, $format,
                                           $open_data_check_profile,
                                           $data_file_type, $resp,
                                           $filename, \%open_data_dictionary,
                                           $checksum);
                Record_Open_Data_Check_Results($member_url, @results);
                
                #
                # Get file details
                #
                $size = -s $filename;
                $t = $member_url;
                $t =~ s/"/""/g;
                $h = Open_Data_Check_Get_Headings_List($member_url);
                $h =~ s/"/""/g;
                ($rows, $cols) = Open_Data_Check_Get_Row_Column_Counts($member_url);
                if ( $rows == -1 ) {
                    $rows = "";
                    $cols = "";
                }

                #
                # Perform content checks on this file
                #
                @results = Open_Data_Check_Content($member_url, $data_file_type);
                Record_Open_Data_Content_Check_Results($member_url, @results);

                #
                # Add file details to CSV
                #
                print $files_details_fh "$data_file_type,\"$t\",\"$mime_type\",\"$checksum\",,$size,$rows,$cols,\"$h\"\r\n";
                
                #
                # Remove temporary file
                #
                print "Remove ZIP member file $filename\n" if $debug;
                if ( ! unlink($filename) ) {
                    print "Error, failed to remove ZIP member file\n" if $debug;
                }

                #
                # If we are doing process monitoring, print out some resource
                # usage statistics
                #
                Print_Resource_Usage("$url:$member_name", "after",
                                     $document_count{$crawled_urls_tab});
            }
        }
    }
    else {
        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "before Open_Data_Check",
                             $document_count{$crawled_urls_tab});

        #
        # Treat URL as a single open data file
        #
        print "Single open data file\n" if $debug;
        if ( $resp_valid ) {
            $filename = $resp->header("WPSS-Content-File");
            $size = -s $filename;

            #
            # Compute SHA-1 checksum for this file
            #
            $sha = Digest::SHA->new("SHA-1");
            $sha->addfile($filename);
            $checksum = $sha->hexdigest;
        }
        else {
            $filename = "";
            $size = 0;
            $checksum = "";
        }
        @results = Open_Data_Check($url, $format, $open_data_check_profile,
                                   $data_file_type, $resp,
                                   $filename, \%open_data_dictionary,
                                   $checksum);
        Record_Open_Data_Check_Results($url, @results);

        #
        # Perform content checks on this file
        #
        @results = Open_Data_Check_Content($url, $data_file_type);
        Record_Open_Data_Content_Check_Results($url, @results);

        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "after",
                             $document_count{$crawled_urls_tab});

        #
        # Get file details
        #
        $t = $url;
        $t =~ s/"/""/g;
        $h = Open_Data_Check_Get_Headings_List($url);
        $h =~ s/"/""/g;
        ($rows, $cols) = Open_Data_Check_Get_Row_Column_Counts($url);
        if ( $rows == -1 ) {
            $rows = "";
            $cols = "";
        }

        #
        # Add file details to CSV
        #
        print $files_details_fh "$data_file_type,\"$t\",\"$mime_type\",\"$checksum\",$size,,$rows,$cols,\"$h\"\r\n";
    }
}

#***********************************************************************
#
# Name: Open_Data_Callback
#
# Parameters: dataset_urls - pointer to table of dataset URLs
#             report_options - report options hash table
#
# Description:
#
#   This function is a callback function used by the GUI package to
# process Open Data URLs.
#
#***********************************************************************
sub Open_Data_Callback {
    my ($dataset_urls, %report_options) = @_;

    my (@url_list, $i, $key, $value, $resp_url, $resp, $header, $content);
    my ($data_file_type, $item, $format, $url, $tab, @results, $filename);
    my ($language, $mime_type, $error, $t, $size, $checksum, $sha);
    my ($sec, $min, $hour, $mday, $mon, $year, $date, @data_url_list);
    my ($durl);

    #
    # Initialize tool global variables
    #
    print "Open_Data_Callback\n" if $debug;
    $report_fails_only = $report_options{"report_fails_only"};
    %open_data_error_url_count = ();
    %open_data_error_instance_count = ();
    %open_data_error_url_count = ();
    %open_data_dictionary = ();
    %document_count = ();
    %error_count = ();
    %fault_count = ();
    %is_valid_markup = ();
    %tqa_error_url_count = ();
    %tqa_error_instance_count = ();
    Crawler_Abort_Crawl(0);
    $shared_save_content = $report_options{"save_content"};

    #
    # Set user agent max size if it has not been specified.
    #
    $crawler_config_vars{"content_file"} = 1;
    if ( ! defined($crawler_config_vars{"user_agent_max_size"}) ) {
        $crawler_config_vars{"user_agent_max_size"} = 1000000000;
    }
    $crawler_config_vars{"save_content"} = $report_options{"save_content"};
    Crawler_Config(%crawler_config_vars);
    
    #
    # Clean up any temporary file from a possible previous analysis run
    #
    Remove_Temporary_Files();

    #
    # Create open data files details temporary file
    #
    ($files_details_fh, $shared_file_details_filename) =
       tempfile("WPSS_TOOL_WP_XXXXXXXXXX",
                SUFFIX => '.csv',
                TMPDIR => 1);
    if ( ! defined($files_details_fh) ) {
        print "Error: Failed to create temporary file in Open_Data_Callback\n";
        return;
    }
    binmode $files_details_fh, ":utf8";

    #
    # Add UTF-8 BOM and column headings
    #
    print $files_details_fh chr(0xFEFF);
    print $files_details_fh join(",", @open_data_file_details_fields) . "\r\n";

    #
    # Make sure we are authenticated with the firewall before we start.
    #
    if ( defined($firewall_check_url) ){
        Set_Crawler_HTTP_401_Callback(\&HTTP_401_Callback);
        print "Check firewall URL $firewall_check_url\n" if $debug;
        ($resp_url, $resp) = Crawler_Get_HTTP_Response($firewall_check_url, "");

        #
        # Clean up any possible temporary file
        #
        if ( defined($resp) && defined($resp->header("WPSS-Content-File")) ) {
            $filename = $resp->header("WPSS-Content-File");
            unlink($filename);
        }
    }

    #
    # Ignore robots.txt directives
    #
    Crawler_Robots_Handling(0);

    #
    # Get open data profile name
    #
    $open_data_check_profile = $report_options{$open_data_profile_label};

    #
    # Get markup validation profile name
    #
    $markup_validate_profile = $report_options{$markup_validate_profile_label};

    #
    # Get TQA Check profile name
    #
    $tqa_check_profile = $report_options{$tqa_profile_label};
    
    #
    # Get Link Check profile name
    #
    $link_check_profile = $report_options{$link_check_profile_label};

    #
    # Report header
    #
    Print_Results_Header("","");

    #
    # Is there a dataset description URL (i.e. the URL of
    # a data.gc.ca JSON object to describe the dataset) ?
    #
    if ( defined($$dataset_urls{"DESCRIPTION"}) ) {
        #
        # Get the open data file
        #
        $url = $$dataset_urls{"DESCRIPTION"};
        print "Process open data description url $url\n" if $debug;
        ($resp_url, $resp) = Crawler_Get_HTTP_Response($url, "");

        #
        # Uncompress the content, if needed
        #
        Crawler_Uncompress_Content_File($resp);
        push(@all_urls, "DESCRIPTION $url");
        
        #
        # Get the file details
        #
        if ( defined($resp) && $resp->is_success ) {
            $header = $resp->headers;
            $mime_type = $header->content_type;
            $filename = $resp->header("WPSS-Content-File");
            $size = -s $filename;
            $t = $url;
            $t =~ s/"/""/g;

            #
            # Compute SHA-1 checksum for this file
            #
            $sha = Digest::SHA->new("SHA-1");
            $sha->addfile($filename);
            $checksum = $sha->hexdigest;
        }
        else {
            #
            # Unknown mime-type
            #
            $mime_type = "";
            $filename = "";
            $size = 0;
            $checksum = "";
        }

        #
        # Add file details to CSV
        #
        print $files_details_fh "DESCRIPTION,\"$t\",\"$mime_type\",\"$checksum\",$size,,,,\r\n";

        #
        # Print URL
        #
        $document_count{$crawled_urls_tab}++;
        if ( defined($resp) && ($resp->is_success) ) {
            Validator_GUI_Start_URL($crawled_urls_tab, $url, "", 0,
                                    $document_count{$crawled_urls_tab});
        }
        else {
            #
            # Error getting open data URL
            #
            if ( defined($resp) ) {
                $error = String_Value("HTTP Error") . " " .
                                      $resp->status_line;
                if ( defined($resp->header("Client-Warning")) ) {
                    $error .= ", " . $resp->header("Client-Warning");
                }
            }
            else {
                $error = String_Value("Malformed URL");
            }
            Validator_GUI_Print_URL_Error($crawled_urls_tab, $url,
                                          $document_count{$crawled_urls_tab},
                                          $error);
        }

        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "before Open_Data_Check_Read_JSON_Description",
                             $document_count{$crawled_urls_tab});

        #
        # Extract the dataset URLs from the description
        #
        @results = Open_Data_Check_Read_JSON_Description($url,
                                                         $open_data_check_profile,
                                                         $resp, $filename,
                                                         \$dataset_urls);

        #
        # Record results
        #
        Record_Open_Data_Check_Results($url, @results);

        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        Print_Resource_Usage($url, "after",
                             $document_count{$crawled_urls_tab});

        #
        # Remove URL content file
        #
        if ( $filename ne "" ) {
            print "Remove content file $filename\n" if $debug;
            unlink($filename);
        }
    }

    #
    # Loop through the data file types
    #
    foreach $data_file_type (@open_data_file_types) {
        #
        # Get list of URLs for this file type
        #
        if ( defined($$dataset_urls{"$data_file_type"}) ) {
            print "Dataset URL type $data_file_type, url list = " .
                  $$dataset_urls{"$data_file_type"} . "\n" if $debug;
            @url_list = split(/\n+/, $$dataset_urls{"$data_file_type"});

            #
            # Process each URL in the list
            #
            foreach $item (@url_list) {
                #
                # Are we aborting the URL analysis ? Check crawler module flag
                # in case the abort was called from another thread
                # (i.e. the UI layer)
                #
                if ( Crawler_Abort_Crawl_Status() == 1 ) {
                    last;
                }

                #
                # The URL may include a format specifier (e.g. CSV)
                #
                ($format, $url) = split(/\t/, $item);
                if ( ! defined($url) ) {
                    $url = $item;
                    $format = "";
                }

                #
                # Ignore blank lines
                #
                $url =~ s/\r//g;
                $url =~ s/^\s+//g;
                $url =~ s/\s+$//g;
                if ( $url =~ /^$/ ) {
                    next;
                }

                #
                # Get the open data file
                #
                print "Process open data url $url\n" if $debug;
                ($resp_url, $resp) = Crawler_Get_HTTP_Response($url, "");
                
                #
                # Did we get the page ?
                #
                $document_count{$crawled_urls_tab}++;
                if ( defined($resp) && ($resp->is_success) ) {
                    #
                    # Get the uncompressed response content
                    #
                    Crawler_Uncompress_Content_File($resp);

                    #
                    # Print URL
                    #
                    Validator_GUI_Start_URL($crawled_urls_tab, $url, "", 0,
                                            $document_count{$crawled_urls_tab});
                }
                else {
                    #
                    # Error getting open data URL
                    #
                    if ( defined($resp) ) {
                        $error = String_Value("HTTP Error") . " " .
                                              $resp->status_line;
                        if ( defined($resp->header("Client-Warning")) ) {
                            $error .= ", " . $resp->header("Client-Warning");
                        }
                    }
                    else {
                        $error = String_Value("Malformed URL");
                    }
                    Validator_GUI_Print_URL_Error($crawled_urls_tab, $url,
                                                  $document_count{$crawled_urls_tab},
                                                  $error);
                }

                #
                # Get mime-type for content
                #
                if ( defined($resp) && $resp->is_success ) {
                    $header = $resp->headers;
                    $mime_type = $header->content_type;
                }
                else {
                    $mime_type = "";
                }

                #
                # Check mime-type to see if it is an HTML page or an
                # Open Data document
                #
                if ( $mime_type =~ /text\/html/ ) {
                    #
                    # Get the content from the content file
                    #
                    $content = Crawler_Read_Content_File($resp);
                    
                    #
                    # Setup content saving option
                    #
                    Setup_Content_Saving($shared_save_content, $url);

                    #
                    # Save content in a local file
                    #
                    Save_Content_To_File($url, $mime_type, \$content, "", "");

                    #
                    # Get document language
                    #
                    $language = HTML_Document_Language($url, \$content);

                    #
                    # Perform mark-up validation
                    #
                    print "Add to all URLs list HTML $url\n" if $debug;
                    push(@all_urls, "HTML $url");
                    Perform_Markup_Validation($url, $mime_type, $resp, \$content);

                    #
                    # Perform Link check
                    #
                    Perform_Link_Check($url, $mime_type, $resp, \$content,
                                       $language, \$content);

                    #
                    # Perform TQA check
                    #
                    Perform_TQA_Check($url, \$content, $language, $mime_type,
                                      $resp, $logged_in);

                    #
                    # Get file details
                    #
                    $filename = $resp->header("WPSS-Content-File");
                    $size = -s $filename;
                    $t = $url;
                    $t =~ s/"/""/g;

                    #
                    # Compute SHA-1 checksum for this file
                    #
                    $sha = Digest::SHA->new("SHA-1");
                    $sha->addfile($filename);
                    $checksum = $sha->hexdigest;

                    #
                    # Add file details to CSV
                    #
                    print $files_details_fh "$data_file_type,\"$t\",\"$mime_type\",\"$checksum\",$size,,,,\r\n";
                }
                else {
                    #
                    # Perform Open Data checks.
                    #
                    print "Add to all URLs list $data_file_type $url\n" if $debug;
                    push(@all_urls, "$data_file_type $url");
                    Perform_Open_Data_Check($url, $format, $data_file_type,
                                            $resp);
                }

                #
                # Remove the temporary content file if we have one
                #
                if ( defined($resp) && $resp->is_success ) {
                    #
                    # Extract the content file name from HTTP::Response object
                    #
                    $filename = $resp->header("WPSS-Content-File");

                    #
                    # Remove URL content file
                    #
                    if ( defined($filename) && ($filename ne "") ) {
                        print "Remove content file $filename\n" if $debug;
                        unlink($filename);
                    }
                }
            }
        }
    }

    #
    # Was the crawl aborted ?
    #
    if ( Crawler_Abort_Crawl_Status() == 1 ) {
        #
        # Add a note to all tabs indicating that analysis was aborted.
        #
        foreach $tab (@active_results_tabs) {
            if ( defined($tab) ) {
                Validator_GUI_Update_Results($tab,
                                             String_Value("Analysis Aborted"),
                                             0);
            }
        }
    }
    else {
        #
        # Do we have any data files?
        #
        if ( defined($$dataset_urls{"DATA"}) ) {
            #
            # Check dataset consistency (e.g. matching English & French files).
            # Get URL list from all_urls as some data files may be ZIP files
            # and have member files.
            #
            foreach $url (@all_urls) {
                if ( $url =~ /^DATA / ) {
                    $durl = $url;
                    $durl =~ s/^DATA //;
                    push(@data_url_list, $durl);
                }
            }
            @results = Open_Data_Check_Dataset_Data_Files($open_data_check_profile,
                                                          \@data_url_list,
                                                          \%open_data_dictionary);

            #
            # Record results
            #
            Record_Open_Data_Check_Results("", @results);
            
            #
            # Get the content check results
            #
            @results = Open_Data_Check_Dataset_Data_Files_Content();

            #
            # Record results
            #
            Record_Open_Data_Content_Check_Results("", @results);
        }
    }

    #
    # Open data is complete, print sorted list of URLs in URLs tab.
    #
    $i = 1;
    foreach $url (sort(@all_urls)) {
        Validator_GUI_Update_Results($doc_list_tab, "$i:  $url");
        $i++;
    }

    #
    # Analysis complete, print report footer
    #
    Print_Results_Footer(0, 0);

    #
    # Close the open data files details file
    #
    close($files_details_fh);
}

#***********************************************************************
#
# Name: Setup_HTML_Tool_GUI
#
# Parameters: none
#
# Description:
#
#   This function sets up the tool for HTML checking.
#
#***********************************************************************
sub Setup_HTML_Tool_GUI {

    my (%report_options_labels, %report_options_values_languages);
    my (%robots_languages, %status_401_languages, $value, @values);

    #
    # Get report option labels
    #
    $link_check_profile_label = String_Value("Link Check Profile");
    $testcase_profile_group_label = String_Value("Testcase Profile Groups");
    $metadata_profile_label = String_Value("Metadata Profile");
    $pdf_property_profile_label = String_Value("PDF Property Profile");
    $tqa_profile_label = String_Value("ACC Testcase Profile");
    $clf_profile_label = String_Value("CLF Testcase Profile");
    $wa_profile_label = String_Value("Web Analytics Testcase Profile");
    $interop_profile_label = String_Value("Interop Testcase Profile");
    $mobile_profile_label = String_Value("Mobile Testcase Profile");
    $markup_validate_profile_label = String_Value("Markup Validation Profile");
    $dept_check_profile_label = String_Value("Department Check Testcase Profile");
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
                       $wa_profile_label, \@wa_check_profiles,
                       $interop_profile_label, \@interop_check_profiles,
                       $dept_check_profile_label, \@dept_check_profiles,
                       $doc_profile_label, \@doc_features_profiles,
                       $robots_label, \@robots_options,
                       $status_401_label, \@status_401_options,
                       $mobile_profile_label, \@mobile_check_profiles,
                       $markup_validate_profile_label, \@markup_validate_profiles,);
    %report_options_labels = ("clf_profile", $clf_profile_label,
                              "dept_profile", $dept_check_profile_label,
                              "group_profile", $testcase_profile_group_label,
                              "html_profile", $doc_profile_label,
                              "interop_profile", $interop_profile_label,
                              "link_profile", $link_check_profile_label,
                              "metadata_profile", $metadata_profile_label,
                              "pdf_profile", $pdf_property_profile_label,
                              "robots_handling", $robots_label,
                              "tqa_profile", $tqa_profile_label,
                              "wa_profile", $wa_profile_label,
                              "401_handling", $status_401_label,
                              "mobile_profile", $mobile_profile_label,
                              "markup_validate_profile", $markup_validate_profile_label);

    #
    # Get hash table of testcase profile option and all the
    # various language values.
    #
    @values = All_String_Values("Ignore robots.txt");
    foreach $value (@values) {
        $robots_languages{$value} = String_Value("Ignore robots.txt");
    }
    @values = All_String_Values("Respect robots.txt");
    foreach $value (@values) {
        $robots_languages{$value} = String_Value("Respect robots.txt");
    }
    @values = All_String_Values("Ignore");
    foreach $value (@values) {
        $status_401_languages{$value} = String_Value("Ignore");
    }
    @values = All_String_Values("Prompt for credentials");
    foreach $value (@values) {
        $status_401_languages{$value} = String_Value("Prompt for credentials");
    }

    %report_options_values_languages = (
                    "clf_profile", \%clf_check_profiles_languages,
                    "dept_profile", \%dept_check_profiles_languages,
                    "group_profile", \%testcase_profile_groups_profiles_languages,
                    "html_profile", \%clf_check_profiles_languages,
                    "interop_profile", \%interop_check_profiles_languages,
                    "link_profile", \%link_check_profiles_languages,
                    "metadata_profile", \%metadata_profiles_languages,
                    "pdf_profile", \%pdf_property_profiles_languages,
                    "robots_handling", \%robots_languages,
                    "tqa_profile", \%tqa_check_profiles_languages,
                    "wa_profile", \%wa_check_profiles_languages,
                    "401_handling", \%status_401_languages,
                    "mobile_profile", \%mobile_check_profiles_languages,
                    "markup_validate_profile", \%markup_validate_profiles_languages);

    #
    # Setup the validator GUI configuration options
    #
    Validator_GUI_Report_Option_Labels(\%report_options_labels,
                                       \%report_options_values_languages);
    
    #
    # Setup the validator GUI configuration testcase profile groups
    #
    Validator_GUI_Report_Option_Testcase_Groups("group_profile",
                                                $testcase_profile_group_label,
                                                \@testcase_profile_groups,
                                                \%testcase_profile_group_map);
    
    #
    # Get label for the various result tabs and the file suffix
    # when saving results
    #
    $crawled_urls_tab = String_Value("Crawled URLs");
    $results_file_suffixes{$crawled_urls_tab} = "crawl";
    $validation_tab = String_Value("Validation");
    $results_file_suffixes{$validation_tab} = "val";
    $link_tab = String_Value("Link");
    $results_file_suffixes{$link_tab} = "link";
    $metadata_tab = String_Value("Metadata");
    $results_file_suffixes{$metadata_tab} = "meta";
    $acc_tab = String_Value("ACC");
    $results_file_suffixes{$acc_tab} = "acc";
    $clf_tab = String_Value("CLF");
    $results_file_suffixes{$clf_tab} = "clf";
    $interop_tab = String_Value("INT");
    $results_file_suffixes{$interop_tab} = "int";
    $dept_tab = String_Value("Department");
    $results_file_suffixes{$dept_tab} = "dept";
    $doc_features_tab = String_Value("Document Features");
    $results_file_suffixes{$doc_features_tab} = "feat";
    $doc_list_tab = String_Value("Document List");
    $results_file_suffixes{$doc_list_tab} = "urls";
    $mobile_tab  = String_Value("Mobile");
    $results_file_suffixes{$mobile_tab} = "mob";
    @active_results_tabs = ($crawled_urls_tab, $validation_tab, $link_tab,
                            $metadata_tab, $acc_tab, $content_tab, $clf_tab,
                            $interop_tab, $dept_tab, $doc_features_tab,
                            $doc_list_tab, $mobile_tab);

    #
    # Set results file suffixes and other configuration items
    #
    Validator_GUI_Set_Results_File_Suffixes(%results_file_suffixes);
    Validator_GUI_Config(%gui_config);
    
    #
    # Setup the validator GUI
    #
    Validator_GUI_Setup($lang, \&Direct_HTML_Input_Callback,
                        \&Perform_Site_Crawl, \&URL_List_Callback,
                        %report_options);
    Validator_GUI_Runtime_Error_Callback(\&Runtime_Error_Callback);

    #
    # Add result tabs
    #
    Validator_GUI_Add_Results_Tab($crawled_urls_tab);
    Validator_GUI_Add_Results_Tab($validation_tab);
    Validator_GUI_Add_Results_Tab($link_tab);
    Validator_GUI_Add_Results_Tab($metadata_tab);
    Validator_GUI_Add_Results_Tab($acc_tab);
    Validator_GUI_Add_Results_Tab($clf_tab);
    Validator_GUI_Add_Results_Tab($interop_tab);
    Validator_GUI_Add_Results_Tab($dept_tab);
    Validator_GUI_Add_Results_Tab($mobile_tab);
    Validator_GUI_Add_Results_Tab($doc_features_tab);
    Validator_GUI_Add_Results_Tab($doc_list_tab);

    #
    # Set Results Save callback function
    #
    Validator_GUI_Set_Results_Save_Callback(\&Results_Save_Callback);
}

#***********************************************************************
#
# Name: Open_Data_Runtime_Error_Callback
#
# Parameters: message - runtime error message
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when the validator engine has a runtime error and
# aborts.  The result tabs are updated with an error message.
#
#***********************************************************************
sub Open_Data_Runtime_Error_Callback {
    my ($message) = @_;

    my ($tab);

    #
    # Add a note to all tabs indicating that analysis failed due
    # runtime error.
    #
    foreach $tab (@active_results_tabs) {
        if ( defined($tab) ) {
            Validator_GUI_Update_Results($tab, "", 0);
            Validator_GUI_Update_Results($tab,
                                         String_Value("Runtime Error Analysis Aborted"),
                                         0);
            Validator_GUI_Update_Results($tab, $message, 0);
        }
    }

    #
    # Site analysis complete, print report footer
    #
    Print_Results_Footer(0, 0);
}

#***********************************************************************
#
# Name: Open_Data_Results_Save_Callback
#
# Parameters: filename - directory and filename prefix
#
# Description:
#
#   This function is a callback function used by the validator package.
# It is called when the user wants to save the results tab content
# in files.  This function saves the results that don't appear
# in a results tab (e.g. file inventory CSV).
#
#***********************************************************************
sub Open_Data_Results_Save_Callback {
    my ($filename) = @_;

    my ($save_filename);

    #
    # Copy the open data files details CSV to the results directory.
    #
    print "Open_Data_Results_Save_Callback, filename = $filename\n" if $debug;
    $save_filename = $filename . "_file_inventory.csv";
    unlink($save_filename);
    print "Copy $shared_file_details_filename, $save_filename\n" if $debug;
    if ( -f $shared_file_details_filename ) {
        copy($shared_file_details_filename, $save_filename);
    }
    unlink($shared_file_details_filename);
    
    #
    # Save any saved web page content
    #
    Finish_Content_Saving($filename);
}

#***********************************************************************
#
# Name: Setup_Open_Data_Tool_GUI
#
# Parameters: none
#
# Description:
#
#   This function sets up the tool for Open Data checking.
#
#***********************************************************************
sub Setup_Open_Data_Tool_GUI {

    my (%report_options_labels, %report_options_labels_languages);
    my (%report_options_values_languages);
    
    #
    # Get report option labels
    #
    $testcase_profile_group_label = String_Value("Testcase Profile Groups");
    $open_data_profile_label = String_Value("Open Data Testcase Profile");
    $tqa_profile_label = String_Value("ACC Testcase Profile");
    $markup_validate_profile_label = String_Value("Markup Validation Profile");
    $link_check_profile_label = String_Value("Link Check Profile");
    $metadata_profile_label = String_Value("Metadata Profile");
    $dept_check_profile_label = String_Value("Department Check Testcase Profile");

    #
    # Set testcase profile options
    #
    %report_options = ($open_data_profile_label, \@open_data_check_profiles,
                       $tqa_profile_label,       \@tqa_check_profiles,
                       $markup_validate_profile_label, \@markup_validate_profiles,
                       $link_check_profile_label, \@link_check_profiles,
                       $metadata_profile_label, \@metadata_profiles,
                       $dept_check_profile_label, \@dept_check_profiles,
                       );

    #
    # Set labels for testcase profile options.
    #
    %report_options_labels = ("dept_profile", $dept_check_profile_label,
                              "group_profile", $testcase_profile_group_label,
                              "link_profile", $link_check_profile_label,
                              "markup_validate_profile", $markup_validate_profile_label,
                              "metadata_profile", $metadata_profile_label,
                              "open_data_profile", $open_data_profile_label,
                              "tqa_profile", $tqa_profile_label,
                              );

    %report_options_values_languages = (
                    "group_profile", \%od_testcase_profile_groups_profiles_languages,
                    "open_data_profile", \%open_data_check_profiles_languages,
                    "tqa_profile", \%tqa_check_profiles_languages,
                    "link_profile", \%link_check_profiles_languages,
                    "markup_validate_profile", \%markup_validate_profiles_languages,
                    "metadata_profile", \%metadata_profiles_languages,
                    "dept_profile", \%dept_check_profiles_languages,
                    );

    #
    # Setup the validator GUI configuration options
    #
    Validator_GUI_Report_Option_Labels(\%report_options_labels,
                                       \%report_options_values_languages);

    #
    # Get label for the various result tabs and the file suffix when
    # saving results
    #
    $crawled_urls_tab = String_Value("Crawled URLs");
    $results_file_suffixes{$crawled_urls_tab} = "crawl";
    $open_data_tab = String_Value("Open Data");
    $results_file_suffixes{$open_data_tab} = "od";
    $validation_tab = String_Value("Validation");
    $results_file_suffixes{$validation_tab} = "val";
    $link_tab = String_Value("Link");
    $results_file_suffixes{$link_tab} = "link";
    $acc_tab = String_Value("ACC");
    $results_file_suffixes{$acc_tab} = "acc";
    $content_tab = String_Value("Content");
    $results_file_suffixes{$content_tab} = "cont";
    $metadata_tab = String_Value("Metadata");
    $results_file_suffixes{$metadata_tab} = "meta";
    $dept_tab = String_Value("Department");
    $results_file_suffixes{$dept_tab} = "dept";
    $doc_list_tab = String_Value("Document List");
    $results_file_suffixes{$doc_list_tab} = "urls";
    @active_results_tabs = ($crawled_urls_tab, $open_data_tab, $validation_tab,
                            $link_tab, $acc_tab, $content_tab, $metadata_tab,
                            $dept_tab, $doc_list_tab);

    #
    # Set results file suffixes
    #
    Validator_GUI_Set_Results_File_Suffixes(%results_file_suffixes);

    #
    # Setup the validator GUI configuration testcase profile groups
    #
    Validator_GUI_Report_Option_Testcase_Groups("group_profile",
                                                $testcase_profile_group_label,
                                                \@od_testcase_profile_groups,
                                                \%od_testcase_profile_group_map);

    #
    # Setup the validator GUI for Open Data
    #
    Validator_GUI_Open_Data_Setup($lang, \&Open_Data_Callback,
                                  %report_options);
    Validator_GUI_Runtime_Error_Callback(\&Open_Data_Runtime_Error_Callback);

    #
    # Add result tabs
    #
    Validator_GUI_Add_Results_Tab($crawled_urls_tab);
    Validator_GUI_Add_Results_Tab($open_data_tab);
    Validator_GUI_Add_Results_Tab($validation_tab);
    Validator_GUI_Add_Results_Tab($link_tab);
    Validator_GUI_Add_Results_Tab($acc_tab);
    Validator_GUI_Add_Results_Tab($content_tab);
    Validator_GUI_Add_Results_Tab($metadata_tab);
    Validator_GUI_Add_Results_Tab($dept_tab);
    Validator_GUI_Add_Results_Tab($doc_list_tab);

    #
    # Set Results Save callback function
    #
    Validator_GUI_Set_Results_Save_Callback(\&Open_Data_Results_Save_Callback);
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
    elsif ( $ARGV[0] eq "-debug" ) {
        $debug = 1;
        $command_line_debug = 1;
    }
    elsif ( $ARGV[0] eq "-disable_generated_markup" ) {
        $cmnd_line_disable_generated_markup = 1;
    }
    elsif ( $ARGV[0] eq "-eng" ) {
        $lang = "eng";
    }
    elsif ( $ARGV[0] eq "-fra" ) {
        $lang = "fra";
    }
    elsif ( $ARGV[0] eq "-monitor" ) {
        $monitoring = 1;
    }
    elsif ( $ARGV[0] eq "-no_login" ) {
        $no_login_mode = 1;
    }
    elsif ( $ARGV[0] eq "-open_data" ) {
        $open_data_mode = 1;
    }
    elsif ( $ARGV[0] eq "-report_passes_only" ) {
        $report_passes_only = 1;
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
chdir($program_dir);

#
# Perform program initialization
#
Initialize();

#
# Are we setting up for Open Data mode ?
#
if ( $open_data_mode ) {
    Setup_Open_Data_Tool_GUI();
}
#
# Setup for HTML testing
#
else {
    Setup_HTML_Tool_GUI();
}

#
# Start the GUI
#
eval { Validator_GUI_Start(@ui_args); 1 };

#
# Clean up any temporary files
#
Remove_Temporary_Files();

print "Exit WPSS Tool\n" . $@ . "\n" if $debug;
exit(0);
