#***********************************************************************
#
# Name: image_details.pm
#
# $Revision: 5629 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/image_details.pm $
# $Date: 2011-12-09 17:27:01 -0500 (Fri, 09 Dec 2011) $
#
# Description
#
#   This file contains routines to handle image files.  The routines
# provide access to image properties.
#
# Public functions:
#     Image_Details
#     Image_Details_Debug
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

package image_details;

use strict;
use warnings;
use File::Basename;
use Image::Info qw(image_info dim image_type);

#
# Use WPSS_Tool program modules
#
use crawler;
use css_check;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Image_Details
                  Image_Details_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************
my ($debug) = 0;
my (%image_details_table, %image_details_table_hits);
my ($image_details_table_count) = 0;
my ($max_image_details_table_count) =   10000;
my ($clean_image_details_table_count) =  7500;

#********************************************************
#
# Name: Image_Details_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Image_Details_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: Clean_Image_Details_Cache
#
# Parameters: none
#
# Description:
#
#   This function cleans the image details cache.  It
# removes entries from the image_details_table hash table
# until the number of entries drops to an acceptable level.
# Entries are removed based on the number of hits, lower
# hit entries are removed first.
#
#********************************************************
sub Clean_Image_Details_Cache {

    my ($hit_count) = 1;
    my ($url, $hits);

    #
    # Loop until the table size drops to the clean level
    #
    print "Clean_Image_Details_Cache, uncleaned count = $image_details_table_count\n" if $debug;
    while ( $image_details_table_count > $clean_image_details_table_count ) {
        while ( ($url, $hits) = each %image_details_table_hits ) {
            if ( $hits == $hit_count ) {
                #
                # Remove entry from both details and hit count tables
                #
                delete $image_details_table_hits{$url};
                delete $image_details_table{$url};
            }
        }

        #
        # Increment hit counter to get next higher hit count entries
        # for removal.
        #
        $hit_count++;
        $image_details_table_count = keys(%image_details_table_hits);
    }
    print "Clean_Image_Details_Cache, cleaned count = $image_details_table_count\n" if $debug;
}

#********************************************************
#
# Name: Most_Frames_Per_Second
#
# Parameters: image_details - hash table of image details
#
# Description:
#
#   This function computes the most frames that can be displayed in
# any 1 second time span.
#
#********************************************************
sub Most_Frames_Per_Second {
    my (%image_details) = @_;

    my ($loops, $image_display_time, $frame_delays_addr, @frame_delays);
    my ($most_frames_per_sec, $frames_per_sec, $frame_count, $animation_time);
    my ($display_time, $i, $first_frame_in_set);

    #
    # Check to see if the animation time is greater than 1 second
    #
    if ( $image_details{"animation_time"} > 1.0 ) {
        #
        # Have to comupte most frames per second from frame delays.
        # If the loop count is 1, use a single pass through the
        # frame delays.
        # If the loop count is greater than 1, we need at least 2 passes.
        # We may need more if the image display time (time to display
        # 1 pass through all image frames) is les than 1 second.
        #
        print "Greater than 1 second animation time\n" if $debug;
        if ( $image_details{"loops"} == 1 ) {
            #
            # No frame looping, use 1 pass through frames.
            #
            $frame_delays_addr = $image_details{"frame_delays"};
            @frame_delays = @$frame_delays_addr;
            print "Use 1 pass through frames\n" if $debug;
        }
        elsif ( $image_details{"image_display_time"} >= 1.0 ) {
            #
            # Frame looping and image display time >= 1.0 seconds.
            # Use 2 passes through frames.
            #
            $frame_delays_addr = $image_details{"frame_delays"};
            @frame_delays = (@$frame_delays_addr, @$frame_delays_addr);
            print "Image display time >= 1.0 (" . 
                  $image_details{"image_display_time"} . 
                  ") use 2 passes through frames\n" if $debug;
        }
        else {
            #
            # Frame looping and image display time < 1.0 seconds.
            # Need more than 2 passes through frames to get 2 seconds worth.
            #
            $image_display_time = $image_details{"image_display_time"};

            #
            # Determine the number of times we have to go through the
            # frames to get 2 or more seconds.  Adding 2 to the number
            # of loops in 2 seconds ensures we have atleast 2 passes through
            # the frames.
            #
            $loops = int(2.0 / $image_display_time);

            #
            # If the number of loops is less than 2 (e.g. image_display_time
            # is greater than 1 second) force 2 loops through the frames.
            #
            if ( $loops < 2 ) {
                $loops = 2;
            }
            elsif ( $loops > $image_details{"loops"} ) {
                #
                # Don't want to exceed the number of loops in the image
                #
                $loops = $image_details{"loops"};
            }

            #
            # Get list of frame delays.
            #
            $frame_delays_addr = $image_details{"frame_delays"};
            print "Image display time >= 1.0 ($image_display_time)" . 
                  ") use $loops passes through frames\n" if $debug;
            while ( $loops > 0 ) {
                push(@frame_delays, @$frame_delays_addr);
                $loops--;
            }
        }

        #
        # Go through list of frame delays and count number of frames
        # in a 1 second interval.
        #
        $most_frames_per_sec = 1;
        $frames_per_sec = 1;
        $frame_count = @frame_delays;
        $display_time = $frame_delays[0];
        $first_frame_in_set = 0;
        for ( $i=1; $i < $frame_count; $i++ ) {
            #
            # If we add this frame to the frame set, do we go beyond
            # 1 second display time ?
            #
            print "Frame # $i, frame_delay = " . $frame_delays[$i] . "\n" if $debug;
            while ( ($display_time + $frame_delays[$i]) > 1.0 ) {
                #
                # Remove frames from the back of the list to get
                # under 1 second display time.
                #
                print "Display time + frame_delay > 1.0, remove frame $first_frame_in_set\n" if $debug;
                $display_time -= $frame_delays[$first_frame_in_set];
                $first_frame_in_set++;
                $frames_per_sec--;
            }

            #
            # Add the current frame to the display time.
            #
            $display_time += $frame_delays[$i];
            $frames_per_sec++;

            #
            # Do we have a new most number of frames in 1 second ?
            #
            if ( $frames_per_sec > $most_frames_per_sec ) {
                $most_frames_per_sec = $frames_per_sec;
                print "Most frames per second = $most_frames_per_sec, display time = $display_time\n" if $debug;
            }
        }
    }
    else {
        #
        # Less than 1 second animation, most frames per second is
        # simply the number of frames in the image times the number of
        # loops over the frames.
        #
        print "Less than or equal to 1 second animation time\n" if $debug;
        $most_frames_per_sec = $image_details{"frames"} *
                               $image_details{"loops"};
    }

    #
    # Return the most number of frames displayed
    #
    print "Most_Frames_Per_Second $most_frames_per_sec\n" if $debug;
    return($most_frames_per_sec);
}

#********************************************************
#
# Name: Get_Image_Details
#
# Parameters: url - URL for image file
#             content - image content
#
# Description:
#
#   This function returns a number of image details, specifically
# those related to accessibility (e.g. flickering).  Details 
# returned in the hash table are:
#   animated - whether or not the image is animated
#   animation_time - time image is animated for (1 sec. for non-animated
#     images).
#   file_media_type - image type, e.g. gif
#   frame_delays - array of frame delay values
#   frames - number of frames in the image
#   frames_per_second - number of frames displayed per second
#   height - image height
#   image_display_time - time required to display 1 pass through
#     all image frames.
#   image_size - image size (i.e. width * height)
#   loops - number of times image loops through frames
#   most_frames_per_sec - the most number of frames displayed in any 1
#     second time span.
#   width - image width
#
#********************************************************
sub Get_Image_Details {
    my ($url, $content) = @_;

    my ($error, %image_details, @info, $info_item, $frame_count, $details);
    my ($image_display_time, $loops, $frames_per_secord, $width, $height);
    my (@frame_delays);

    #
    # Get the image info
    #
    print "Get_Image_Details for URL $url\n" if $debug;
    @info = image_info(\$content);
    $info_item = $info[0];

    #
    # Get image file type
    #
    if ( defined($info_item->{file_media_type}) ) {
        $image_details{"file_media_type"} = $info_item->{file_media_type};
    }
    else {
        $image_details{"file_media_type"} = "unknown";
    }

    #
    # Get height and width then compute image size.
    #
    if ( defined($info_item->{width}) ) {
        $width = $info_item->{width};
    }
    else {
        $width = 0;
    }
    if ( defined($info_item->{height}) ) {
        $height = $info_item->{height};
    }
    else {
        $height = 0;
    }
    $image_details{"width"} = $width;
    $image_details{"height"} = $height;
    $image_details{"image_size"} = $width * $height;

    #
    # Get the number of frames in the image file
    #
    $frame_count = @info;
    $image_details{"frames"} = $frame_count;

    #
    # If there is more than 1 frame, the image is animated
    #
    if ( $frame_count > 1 ) {
        $image_details{"animated"} = 1;
    }
    else {
        $image_details{"animated"} = 0;
    }

    #
    # Does the image loop ?
    #
    if ( defined($info_item->{GIF_Loop}) ) {
        #
        # Have GIF_Loop, is it a number or a string ?
        #
        $loops = $info_item->{GIF_Loop};
        if ( $loops =~ /forever/i ) {
            #
            # Infinite number of loops, set to a large number as
            # we have to do math with it later.
            #
            $loops = 9999;
        }
    }
    else {
        #
        # No GIF_Loop value, frames only loop once.
        #
        $loops = 1;
    }

    #
    # Save the frame loop count.
    #
    $image_details{"loops"} = $loops;

    #
    # Get the frame delay time for each frame (if there is more than 1)
    #
    $image_display_time = 0;
    for $info_item (@info) {
        if ( defined($info_item->{Delay}) ) {
            $image_display_time += $info_item->{Delay};
            push(@frame_delays, $info_item->{Delay});
        }
    }

    #
    # If we don't have any frames, set image display time to 1
    # as we need a valid number when computing the number of
    # frames displayed per second.
    #
    if ( $image_display_time == 0 ) {
        $image_display_time = 1;
        push(@frame_delays, 1);
    }
    $image_details{"image_display_time"} = $image_display_time;
    $image_details{"frame_delays"} = \@frame_delays;

    #
    # Compute the average number of frames displayed per second.
    #
    $frames_per_secord = 1.0 / $image_display_time;
    $image_details{"frames_per_second"} = $frames_per_secord;

    #
    # Compute animation time, this is the product of the time to
    # display all frames multiplied by the number of times the image
    # loops over the frames.
    #
    $image_details{"animation_time"} = $image_details{"loops"}
                                       * $image_details{"image_display_time"};

    #
    # Compute the most number of frames that may be displayed in any 1
    # 1 second time span
    #
    $image_details{"most_frames_per_sec"} = Most_Frames_Per_Second(
                                              %image_details);

    #
    # Return hash table of image details
    #
    return(%image_details);
}

#********************************************************
#
# Name: Image_Details
#
# Parameters: url - URL for image file
#
# Description:
#
#   This function returns a number of image details, specifically
# those related to accessibility (e.g. flickering).  Details 
# returned in the hash table are:
#   animated - whether or not the image is animated
#   animation_time - time image is animated for (1 sec. for non-animated
#     images).
#   file_media_type - image type, e.g. gif
#   frame_delays - array of frame delay values
#   frames - number of frames in the image
#   frames_per_second - average number of frames displayed per second
#   height - image height
#   image_display_time - time required to display 1 pass through
#     all image frames.
#   image_size - image size (i.e. width * height)
#   loops - number of times image loops through frames
#   most_frames_per_sec - the most number of frames displayed in any 1
#     second time span.
#   width - image width
#
#********************************************************
sub Image_Details {
    my ($url) = @_;

    my ($resp, $mime_type, $header);
    my (%image_details) = ();
    my ($details) = \%image_details;

    #
    # Do we have a valid image URL (i.e. leading http or https) ?
    #
    print "Image_Details for URL $url\n" if $debug;
    if ( ! ($url =~ /^http[s]?:/) ) {
        #
        # Not an absolute URL
        #
        return(%$details);
    }

    #
    # Have we seen this image before ? If so return the cached
    # image details.
    #
    if ( defined($image_details_table{$url}) ) {
        #
        # Increment hit count for this URL
        #
        $image_details_table_hits{$url}++;

        #
        # Return hash table of image details.
        #
        $details = $image_details_table{$url};
    }
    else {
        #
        # Have to get image file
        #
        ($url, $resp) = Crawler_Get_HTTP_Response($url, "");

        #
        # Did we get the URL ?
        #
        if ( $resp->is_success ) {
            #
            # Does this look like an image ?
            #
            $header = $resp->headers;
            $mime_type = $header->content_type;
            if ( $mime_type =~ /image\// ) {

                #
                # Get image details
                #
                %image_details = Get_Image_Details($url, $resp->content);

                #
                # Save image details in a cache in case we need them again
                #
                if ( $image_details_table_count >= 
                     $max_image_details_table_count ) {
                    Clean_Image_Details_Cache();
                }
                $image_details_table_hits{$url} = 1;
                $image_details_table{$url} = \%image_details;
                $image_details_table_count++;
                $details = \%image_details;
            }
            else {
                #
                # Not of type image, ignore it.
                #
                print "Ignore non-image mime-type $mime_type\n" if $debug;
            }
        }
        else {
            #
            # Error retriving URL
            #
            print "Failed to retrieve URL $url\n" if $debug;
        }
    }

    #
    # Return hash table of image details
    #
    return(%$details);
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;
