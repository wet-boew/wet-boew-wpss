#!/usr/bin/python
#***********************************************************************
#
# Name:   feedvalidator.py
#
# $Revision: 1629 $
# $URL: svn://10.36.148.185/WPSS_Tool/Feed_Validate/Tools/feedvalidator.py $
# $Date: 2019-12-10 11:36:03 -0500 (Tue, 10 Dec 2019) $
#
# Synopsis: feedvalidator.py <url>
#
# Description:
#
#   This program validates the web feed at the specified URL.
#
# This program is based on the demo.py program provided with the 
# feedvalidator source distribution.
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


"""$Id$"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 1629 $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

import feedvalidator
import sys
import os
import urllib
import urllib2
import urlparse

if __name__ == '__main__':
  # arg 1 is URL to validate
  link = sys.argv[1:] and sys.argv[1] or 'http://www.intertwingly.net/blog/index.atom'
  link = urlparse.urljoin('file:' + urllib.pathname2url(os.getcwd()) + '/', link)
  try:
    link = link.decode('utf-8').encode('idna')
  except:
    pass
  # print 'Validating %s' % link

  curdir = os.path.abspath(os.path.dirname(sys.argv[0]))
  basedir = urlparse.urljoin('file:' + curdir, ".")

  try:
    if link.startswith(basedir):
      events = feedvalidator.validateStream(urllib.urlopen(link), firstOccurrenceOnly=1,base=link.replace(basedir,"http://www.feedvalidator.org/"))['loggedEvents']
    else:
      events = feedvalidator.validateURL(link, firstOccurrenceOnly=1)['loggedEvents']
  except feedvalidator.logging.ValidationFailure, vf:
    events = [vf.event]

  # (optional) arg 2 is compatibility level
  # "A" is most basic level
  # "AA" mimics online validator
  # "AAA" is experimental; these rules WILL change or disappear in future versions
  from feedvalidator import compatibility
  filter = sys.argv[2:] and sys.argv[2] or "AA"
  filterFunc = getattr(compatibility, filter)
  events = filterFunc(events)

  from feedvalidator.formatter.text_plain import Formatter
  output = Formatter(events)
  if output:
      print "\n".join(output)
      print "\nValidation failed"
      sys.exit(1)
  else:
      print "No errors or warnings"
