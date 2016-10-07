#***********************************************************************
#
# Name: Perform_EPUB_Check
#
# Parameters: url - EPUB URL
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function checks EPUB documents.
#
#***********************************************************************
sub Perform_EPUB_Check {
    my ($url, $resp, $content) = @_;

    my ($zip, @members, $member_name, $header, $mime_type);
    my (@results, $member_url, $member, $filename, $local_epub_file);
    my ($result_object);

    #
    # Perform checks on an EPUB document
    #
    print "Perform_EPUB_Check\n" if $debug;

    #
    # If we are doing process monitoring, print out some resource
    # usage statistics
    #
    if ( $monitoring ) {
        Print_Resource_Usage($url, "before",
                             $document_count{$crawled_urls_tab});
    }

    #
    # Validate the epub file.  This will also give us a Archive::ZIP
    # object to get at the EPUB file contents.
    #
    ($zip, $local_epub_file, @results) = EPUB_Validate_Content($url,
                                                     $markup_validate_profile,
                                                     $content);

     #
     # Did validation fail ?
     #
     if ( defined(@results) ) {
        #
        # Increment document & error counters
        #
        Increment_Counts_and_Print_URL($validation_tab, $url, 1);

        #
        # Print results of each validation if it failed
        #
        foreach $result_object (@results) {
            if ( $result_object->status != 0 ) {
                Validator_GUI_Print_TQA_Result($validation_tab, $result_object);
            }
        }
    }

    #
    # If we are doing process monitoring, print out some resource
    # usage statistics
    #
    if ( $monitoring ) {
        Print_Resource_Usage($url, "after",
                             $document_count{$crawled_urls_tab});
    }

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
                if ( $monitoring ) {
                    Print_Resource_Usage("$url:$member_name", "before",
                                         $document_count{$crawled_urls_tab} + 1);
                }

                #
                # Get contents for this member in a file
                #
                print "Process zip member $member_name\n" if $debug;
                (undef, $filename) = tempfile("WPSS_TOOL_XXXXXXXXXX", OPEN => 0);
                print "Extract member to $filename\n" if $debug;
                $member->extractToFileNamed($filename);

                #
                # Create and a URL for the member of the ZIP
                #
                $member_url = "$url:$member_name";
                push(@all_urls, "DATA $member_url");
                $document_count{$crawled_urls_tab}++;
                Validator_GUI_Start_URL($crawled_urls_tab, $member_url, "", 0,
                                        $document_count{$crawled_urls_tab});

                #
                # Perform checks on this content
                #
                @results = EPUB_Check($member_url, $format,
                                           $open_data_check_profile,
                                           $data_file_type, $resp,
                                           $filename, \%open_data_dictionary);
                Record_EPUB_Check_Results($member_url, @results);

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
                if ( $monitoring ) {
                    Print_Resource_Usage("$url:$member_name", "after",
                                         $document_count{$crawled_urls_tab});
                }
            }
        }
    }
    else {
        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        if ( $monitoring ) {
            Print_Resource_Usage($url, "after",
                                 $document_count{$crawled_urls_tab});
        }

        #
        # Treat URL as a single open data file
        #
        print "Single open data file\n" if $debug;
        $filename = $resp->header("WPSS-Content-File");
        @results = EPUB_Check($url, $format, $open_data_check_profile,
                                   $data_file_type, $resp,
                                   $filename, \%open_data_dictionary);
        Record_EPUB_Check_Results($url, @results);

        #
        # If we are doing process monitoring, print out some resource
        # usage statistics
        #
        if ( $monitoring ) {
            Print_Resource_Usage($url, "after",
                                 $document_count{$crawled_urls_tab});
        }
    }

    #
    # Remove URL content file
    #
    $filename = $resp->header("WPSS-Content-File");
    print "Remove content file $filename\n" if $debug;
    if ( ! unlink($filename) ) {
        print "Error, failed to remove URL content file $filename\n" if $debug;
    }
}


