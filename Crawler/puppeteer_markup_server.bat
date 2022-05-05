@REM ----------------------------------------------------------------------------
@REM
@REM Name: puppeteer_markup_server.bat
@REM
@REM $Revision: 1236 $
@REM $URL: svn://10.36.148.185/WPSS_Tool/Crawler/Tools/puppeteer_markup_server.bat $
@REM $Date: 2019-03-29 13:11:46 -0400 (Fri, 29 Mar 2019) $
@REM
@REM Synopsis: puppeteer_markup_server.bat <port> <chrome_path>
@REM                                       <user_data_directory>
@REM                                       -debug
@REM
@REM Where: port - the port number to use for communications
@REM        chrome_path - path to the Chrome browser
@REM        user_data_directory - user data directory
@REM        -debug - optional debugging flag
@REM
@REM Description:
@REM
@REM    This program starts a node program to run a puppeteer headless
@REM browser instance. This program requires NodeJS and the puppeteer-core
@REM module.
@REM
@REM Terms and Conditions of Use
@REM
@REM Unless otherwise noted, this computer program source code
@REM is covered under Crown Copyright, Government of Canada, and is
@REM distributed under the MIT License.
@REM
@REM MIT License
@REM
@REM Copyright (c) 2019 Government of Canada
@REM
@REM Permission is hereby granted, free of charge, to any person obtaining a
@REM copy of this software and associated documentation files (the "Software"),
@REM to deal in the Software without restriction, including without limitation
@REM the rights to use, copy, modify, merge, publish, distribute, sublicense,
@REM and/or sell copies of the Software, and to permit persons to whom the
@REM Software is furnished to do so, subject to the following conditions:
@REM
@REM The above copyright notice and this permission notice shall be included
@REM in all copies or substantial portions of the Software.
@REM
@REM THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
@REM OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
@REM FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
@REM THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
@REM OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
@REM ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
@REM OTHER DEALINGS IN THE SOFTWARE.
@REM
@REM ----------------------------------------------------------------------------

@echo off

@REM Check program arguments

@REM Set the NODE_PATH environment variable
set NODE_PATH=%AppData%\npm\node_modules

@REM Run the puppeteer server in node
node .\lib\puppeteer_markup_server.js %1 %2 %3 %4 >> puppeteer_stdout.txt 2>> puppeteer_stderr.txt

exit

