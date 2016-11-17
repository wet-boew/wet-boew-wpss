// ************************************************************
//
// Name: page_markup.js
//
// $Revision: 90 $
// $URL: svn://10.36.20.203/Crawler/Tools/page_markup.js $
// $Date: 2016-11-15 09:02:04 -0500 (Tue, 15 Nov 2016) $
//
// Synopsis: phantomjs page_markup.js <url> [ -debug ]
//
// Where: url - the URL of the page to open
//        -debug - an optional debugging flag
//
// Description:
//
//    This program opens the supplied URL and any referenced supporting
// files (e.g. CSS, JavaScript, images).  It then executes any JavaScript
// that should be run on page load.  Finally it prints the HTML markup
// of the page to stdout.  This program must be run by PhantomJS.
//
// Terms and Conditions of Use
//
// Unless otherwise noted, this computer program source code
// is covered under Crown Copyright, Government of Canada, and is
// distributed under the MIT License.
//
// MIT License
//
// Copyright (c) 2015 Government of Canada
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// ************************************************************

var program_name = 'page_markup.js';
var system = require('system');
var debug = 0;
var generate_page_image = 0;
var page = require('webpage').create();
    page.settings.XSSAuditingEnabled = 'true';
var resourceWait = 500,
    renderWait = 500,
    count = 0,
    maxRenderWait = 2000,
    forcedRenderTimeout,
    renderTimeout,
    t,
    start_time,
    arg,
    arg_count,
    page_image_file_name;

// Set page viewport size to ensure we get a full web page and not
// a smaller (e.g. mobile) page presentation.
page.viewportSize = {
  width: 1280,
  height: 847
};

// Check for program arguments
if (system.args.length === 1) {
    console.log('Missing URL argument!');
    phantom.exit();
} else {
    // 2nd argument is the URL to get
    var url = system.args[1];
}

// Check for optional arguments
if (system.args.length > 2) {
    for (arg_count = 2; arg_count < system.args.length; arg_count++) {
        // Check argument name
        arg = system.args[arg_count];
        
        // Do we generate debug messages ?
        if ( arg === '-debug' ) {
            debug = 1;
        }
        // Do we generate a page image ?
        else if ( arg === '-page_image' ) {
            // Is there a image file name argument ?
            if ( system.args.length > arg_count ) {
                generate_page_image = 1;
                arg_count++;
                page_image_file_name = system.args[arg_count];
            }
            else {
                console.log("Error: Missing image file name");
                phantom.exit();
            }
        }
    }
}

// Make sure console.error messages go to the system stderr output stream.
console.error = function () {
    require("system").stderr.write(Array.prototype.join.call(arguments, ' ') + '\n');
};


// ************************************************************
//
// Name: doRender
//
// Parameters: url - URL to open
//             function - callback function to be called once
//               the page loads
//
// Description:
//
//    This function opens the supplied URL and evaluates the
//  page to execute page load JavaScript.  Once loaded, the
// markup of the page is printed.
//
// ************************************************************
function doRender() {
    // Get current time
    t = new Date();
    console.log(program_name + ': page ' + t.toLocaleTimeString());

    if ( debug === 1 ) {
        console.error('In doRender at ' + t.toLocaleTimeString());
    }

    // Cancel any possible timers
    clearTimeout(renderTimeout);
    clearTimeout(forcedRenderTimeout);

    // Print marker for the start of the HTML mark-up
    console.log(program_name + ': ===== PAGE MARKUP BEGINS =====');
    
    // Eliminate <noscript> content.  PhantomJS converts angle
    // brackets to &lt; and &gt;, so the content must be removed
    // to avoid validation errors.
    var buffer = page.content;
    buffer = buffer.replace(/<\s*noscript\s*>([^<]+)<\s*\/\s*noscript\s*>/img, "");
    console.log(buffer.toString('utf8'));
    console.log('');

    // Print marker for the end of the HTML mark-up
    console.log(program_name + ': ===== PAGE MARKUP ENDS =====');

    // Do we want a rendered image of this page ?
    if ( generate_page_image === 1 ) {
        page.render(page_image_file_name);
    }
    
    if ( debug === 1 ) {
        t = new Date();
        console.error('Exit program at ' + t.toLocaleTimeString());
    }
    phantom.exit();
}

// ************************************************************
//
// Name: page.open
//
// Parameters: url - URL to open
//             function - callback function to be called once
//               the page loads
//
// Description:
//
//    This function opens the supplied URL and evaluates the
//  page to execute page load JavaScript.  Once loaded, the
// markup of the page is printed.
//
// ************************************************************
page.open(url, function (status) {

    if ( debug === 1 ) {
        t = new Date();
        console.error('page.open ' + t.toLocaleTimeString() +
                    ' for url ' + url);
    }

    // Was the open successful ?
    if (status !== "success") {
        console.log('Unable to load url ' + status);
        phantom.exit();
    } else {
        // Set a timeout to allow for JavaScript to run.
        // The timeout is adjusted as resources (e.g. CSS, JavaScript)
        // files are loaded by the page.
        forcedRenderTimeout = setTimeout(doRender, maxRenderWait);
    }
});

// ************************************************************
//
// Name: page.onResourceError
//
// Parameters: resourceError - metadata object for error details
//
// Description:
//
//    This handler is called when there is an error loading a
// resource (e.g. main page, CSS, JavaScript).
//
// ************************************************************
page.onResourceError = function(resourceError) {

    // Get current time
    t = new Date();
    
    // Print error message
    if ( debug === 1 ) {
        console.error('Unable to load resource # ' + count + ' id: ' + resourceError.id + ' URL:' + resourceError.url + ' at ' + t.toLocaleTimeString());
        console.error('Error code: ' + resourceError.errorCode + '. Description: ' + resourceError.errorString);
    }

    // Is the resource the URL of the main page ?
    if ( url === resourceError.url ) {
        // Error loading main page, print error message and exit
        console.error('Unable to load page ' + resourceError.url + ' at ' + t.toLocaleTimeString());
        console.error('Error code: ' + resourceError.errorCode + '. Description: ' + resourceError.errorString);
        phantom.exit();
    }
};

// ************************************************************
//
// Name: page.onError
//
// Parameters: msg - error message
//             trace - traceback stack
//
// Description:
//
//    This handler is called when there is an error executing
// JavaScript.  It prints the error message along with the stack
// traceback.
//
// ************************************************************
page.onError = function(msg, trace) {
    var msgStack = ['ERROR: ' + msg];

    // If there is a traceback stack, include each item in the message stack
    if (trace && trace.length) {
        msgStack.push('TRACE:');
        trace.forEach(function(t) {
          msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function +'")' : ''));
        });
    }

    // Print error message and traceback
    t = new Date();
    console.error('Error at ' + t.toLocaleTimeString() + '\n' + msgStack.join('\n'));
};

// ************************************************************
//
// Name: page.onResourceRequested
//
// Parameters: requestData - metadata object for request
//             networkRequest - object for request
//
// Description:
//
//    This handler is called when there is a request to load
// a resource (e.g. CSS, JavaScript, image, etc).  It increments
// the count of outstanding requests and clears any timer.
//
// ************************************************************
page.onResourceRequested = function(requestData, networkRequest) {

    // Increment resource count and clear rendering timer.
    count += 1;
    clearTimeout(renderTimeout);

    // Print request details
    if ( debug === 1 ) {
        t = new Date();
        console.error('Resource Request #' + count + ' id: ' + requestData.id +
                      ' url: ' + requestData.url + ' at ' + t.toLocaleTimeString());
    }
};

// ************************************************************
//
// Name: page.onResourceReceived
//
// Parameters: response - metadata object for response
//
// Description:
//
//    This handler is called when there a resource
// (e.g. CSS, JavaScript, image, etc) is received.  It decrements
// the count of outstanding requests.  If the count reaches 0,
// it sets a timer to allow any JavaScript to execute on the
// page.
//
// ************************************************************
page.onResourceReceived = function(response) {

    // Is the response stage "end" (all content received) ?
    if (!response.stage || response.stage === 'end') {
        // Decrement outstanding resource count
        count -= 1;

        // Print response details
        if ( debug === 1 ) {
            t = new Date();
            console.error('Response Received #' + count +
                          ' id: ' + response.id + ' URL:' + response.url +
                          ' status: ' + response.status + ' at ' + t.toLocaleTimeString());
        }

        // If the count is 0, set a timeout for JavaScript to execute
        // and to render the page.
        if (count === 0) {
            if ( debug === 1 ) {
                t = new Date();
                console.error('Resource count is 0, start rendering timer at ' + t.toLocaleTimeString());
            }
            renderTimeout = setTimeout(doRender, renderWait);
        }
    }
};

// ************************************************************
//
// Name: phantom.onError
//
// Parameters: msg - error message
//             trace - traceback stack
//
// Description:
//
//    This callback is invoked when there is a JavaScript execution
// error not caught by a page.onError handler. This is the closest it
// gets to having a global error handler in PhantomJS, and so it is
// a best practice to set this onError handler up in order to catch
// any unexpected problems. The arguments passed to the callback are
// the error message and the stack trace [as an Array].
//
// ************************************************************
phantom.onError = function(msg, trace) {
  var msgStack = ['PHANTOM ERROR: ' + msg];
  if (trace && trace.length) {
    msgStack.push('TRACE:');
    trace.forEach(function(t) {
      msgStack.push(' -> ' + (t.file || t.sourceURL) + ': ' + t.line + (t.function ? ' (in function ' + t.function +')' : ''));
    });
  }
  console.error(msgStack.join('\n'));
  if ( debug === 1 ) {
      t = new Date();
      console.error('Phantom onError at ' + t.toLocaleTimeString());
  }
  phantom.exit(1);
};


