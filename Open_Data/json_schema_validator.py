#!/usr/bin/python
#***********************************************************************
#
# Name:   json_schema_validator.py
#
# $Revision: 1600 $
# $URL: svn://10.36.148.185/WPSS_Tool/Open_Data/Tools/json_schema_validator.py $
# $Date: 2019-11-25 13:45:44 -0500 (Mon, 25 Nov 2019) $
#
# Synopsis: json_schema_validator.py <schema> <data> [ <max errors> ]
#
# Where: <schema> is the path to the JSON schema file
#        <data> is the path to the JSON data file
#        <max errors> an optional parameter to indicate the maximum number
#          of errors to report. The default is to report all errors.
#
# Description:
#
#   This program validates the JSON data file against the specified schema.
#
# This program uses the jsonschema python module to perform the actual
# validation.
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2016 Government of Canada
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

import json
import jsonschema
import pprint
import sys

#
# Check for command line arguments
#
if len(sys.argv) < 3: 
    #
    # Missing command line arguments
    #
    print 'Error, missing command line arguments'
    print 'Usage: json_schema_validator.py <schema> <data> [ <max errors> ]'
    print ''
    print ' Where: <schema> is the path to the JSON schema file'
    print '        <data> is the path to the JSON data file'
    print '        <max errors> an optional parameter to indicate the maximum number'
    print '        of errors to report. The default is to report all errors.'
    quit()
    
#
# Get the file names
#
schema_file = sys.argv[1]
data_file = sys.argv[2]

#
# Do we have a maximum number or errors argument?
#
max_errors = 0
if len(sys.argv) > 3:
    max_errors = int(sys.argv[3])

#
# Read the schema file
#
schema = open(schema_file).read()

#
# Read the JSON data file
#
data = open(data_file).read()
json_data = json.loads(data)

#
# Create a validator object from the schema
#
v = jsonschema.Draft4Validator(json.loads(schema));

#
# Try to validate the data against the schema
#
error_no = 0
for e in v.iter_errors(json_data):
    #
    # Validation error, print error message, the
    # path in the schema, the schema details for the
    # node that failed and the path in the data file.
    #
    
    #
    # Do we have a maximum number of errors we want to report?
    #
    if max_errors > 0 and error_no == max_errors:
        print 'Too many errors detected, aborting validator'
        sys.exit(1)
    
    #
    # Error message
    #
    error_no += 1
    print 'Validation Error #',error_no,': ',
    print e.message
    print '===================================================================='

    #
    # The path in the schema to the item
    #
    print 'Schema path: ',
    l = list(e.schema_path)[:-1]
    sep = ""
    for i in l:
        print "%s \"%s\"" % (sep,i),
        sep = ","
    print
    
    #
    # Schema item details
    #
    print 'Schema: ',
    json_string = json.dumps(e.schema, indent=4)
    print json_string[:1000]
    
    #
    # The path in the JSON data file to the error
    #
    print 'JSON data path: ',
    l = e.path
    sep = ""
    for i in l:
        print "%s \"%s\"" % (sep,i),
        sep = ","
    print
    
    #
    # The context for the data items, the container
    # of the container of the error
    #
    value = json_data
    lvalue = value
    llvalue = lvalue
    for i in l:
        print "%s \"%s\"" % (sep,i),
        sep = ","
        llvalue = lvalue
        lvalue = value
        value = value[i]
    print
    json_string = json.dumps(llvalue, indent=4)
    print 'JSON content: '
    print json_string[:1000]
    print

#
# Did we get any errors?
#
if error_no == 0:
    print 'Validation Passed'

