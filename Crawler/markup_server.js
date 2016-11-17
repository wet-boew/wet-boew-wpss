// ************************************************************
//
// Name: markup_server.js
//
// $Revision: 92 $
// $URL: svn://10.36.20.203/Crawler/Tools/markup_server.js $
// $Date: 2016-11-15 09:05:40 -0500 (Tue, 15 Nov 2016) $
//
// Synopsis: phantomjs markup_server.js <port> -debug
//
// Where: port - the port number to use for communications
//        -debug - an optional debugging flag
//
// Description:
//
//    This program starts a web service that listens for actions.  The actions
// are:
//    GET - get a web page
//    EXIT - exit the web service.
//  This program must be run by PhantomJS.
//
// Terms and Conditions of Use
//
// Unless otherwise noted, this computer program source code
// is covered under Crown Copyright, Government of Canada, and is
// distributed under the MIT License.
//
// MIT License
//
// Copyright (c) 2016 Government of Canada
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
var program_name = 'markup_server.js';
var system = require('system');
var page = require('webpage').create();
var debug = 0;
var generate_page_image = 0;
var resourceWait = 500,
    renderWait = 500,
    count = 0,
    maxRenderWait = 2000,
    forcedRenderTimeout,
    renderTimeout,
    get_pageTimeout,
    t,
    start_time, now,
    arg,
    arg_count,
    page_image_file_name;
var port, server, service, url, buffer;
var page_status, page_content;
var element_text, child_element;
var get_computed_styles = 1;
var idle_timeout = 50000,
    idle_timer,
    received_request = 0,
    rendering_done = 0;

// ************************************************************
//
// Name: get_page
//
// Parameters: status - page.open status
//             _callback - callback function that is invoked when
//                         the web page is loaded.
//
// Description:
//
//    This function opens the supplied URL and evaluates the
// page to execute page load JavaScript.  Once loaded, the
// markup of the page is printed.
//
// ************************************************************
function get_page(status, _callback) {
    if (debug === 1) {
        console.log('get_page ' + url);
    }

    // Print load time information
    if (debug === 1) {
        t = new Date();
        console.out('get_page, at ' + t.toLocaleTimeString() + ' for url ' + url);
    }

    // Was the open successful ?
    if (status !== "success") {
        if (debug === 1) {
            console.log('Failed to load URL in get_page ' + url);
            console.log('Status = ' + status);
        }
        return;
    } else {
        // Set a timeout to allow for JavaScript to run.
        // The timeout is adjusted as resources (e.g. CSS, JavaScript)
        // files are loaded by the page.
        forcedRenderTimeout = setTimeout(doRender, maxRenderWait);
    }

    if (debug === 1) {
        t = new Date();
        console.out('In get_page at ' + t.toLocaleTimeString() +
            ' rendering_done = ' + rendering_done);
    }

    if (rendering_done === 1) { // Page has been rendered
        if (debug === 1) {
            t = new Date();
            console.out('get_page, invoke callback function at ' + t.toLocaleTimeString() + ' for url ' + url);
        }

        // Save page content and call the callback function
        page_content = page.content;
        _callback();

    } else {
        if (debug === 1) {
            t = new Date();
            console.out('Reset get_page at ' + t.toLocaleTimeString());
        }
        setTimeout(function() {
            get_page(status, _callback);
        }, 250);
    }
}

// ************************************************************
//
// Name: getParameterByName
//
// Parameters: name - name of query string variable
//             url - URL string to parse
//
// Description:
//
//    This function reads the query string of a URL and locates
// the first instance of the named variable.  It returns the
// value of that variable.
//
// ************************************************************
function getParameterByName(name, url) {
    if (debug === 1) {
        console.out('getParameterByName ' + name);
    }
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
        results = regex.exec(url);
    if (!results) return '';
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, " "));
}

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
// page to execute page load JavaScript.  Once loaded, the
// markup of the page is printed.
//
// ************************************************************
function doRender() {

    // Has rendering already been done?
    if ( rendering_done === 1 ) {
        if (debug === 1) {
            t = new Date();
            console.out('In doRender, page already rendered at ' + t.toLocaleTimeString());
        }
        return;
    }

    // Get the elapsed time for loading the page
    if (debug === 1) {
        t = new Date();
        console.out('In doRender at ' + t.toLocaleTimeString());
    }

    // Cancel any possible timers
    clearTimeout(renderTimeout);
    clearTimeout(forcedRenderTimeout);
    page_content = page.content;
    if (debug === 1) {
        console.log(': ===== PAGE MARKUP BEGINS =====');
        console.log(page_content.toString('utf8'));
        console.log('');
        console.log(': ===== PAGE MARKUP ENDS =====');


    }
    // Do we want a rendered image of this page ?
    if (generate_page_image === 1) {
        if (debug === 1) {
            t = new Date();
            console.log('Render page into an image file at ' + t.toLocaleTimeString());
        }
        page.render(page_image_file_name);
    }

    // Set rendering done flag
    rendering_done = 1;
    clearTimeout(get_pageTimeout);
}

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
            msgStack.push(' -> ' + (t.file || t.sourceURL) + ': ' + t.line + (t.function ? ' (in function ' + t.function+')' : ''));
        });
    }

    // Pint out error message, stack trace and exit the program
    console.out(msgStack.join('\n'));
    phantom.exit(1);
};

// ************************************************************
//
// Name: Idle_Exit
//
// Parameters: none
//
// Description:
//
//    This function is the idle timeout callback.  It exits the
// program if the request received flag has not been set.
//
// ************************************************************
function Idle_Exit() {

    // Get the elapsed time for loading the page
    if (received_request === 0) {
        console.log('Idle timeout, exiting program');
        clearInterval(idle_timer);
        phantom.exit();
    } else {
        // Clear the received_request flag.
        if (debug === 1) {
            console.log('Reset idle timer, clear received_request flag');
        }
        received_request = 0;
    }
}

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

    // Print error message
    if (debug === 1) {
        t = new Date();
        console.out('Unable to load resource # ' + count + ' id: ' + resourceError.id + ' URL:' + resourceError.url);
        console.out('Error code: ' + resourceError.errorCode + '. Description: ' + resourceError.errorString);
        console.out('at ' + t.toLocaleTimeString());
    }

    // Is the resource the URL of the main page ?
    if (url === resourceError.url) {
        // Error loading main page, set page status to fail
        page_status = "fail";
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
            msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function+'")' : ''));
        });
    }

    // Print error message and traceback
    console.out(msgStack.join('\n'));
    phantom.exit(1);
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

    // Print request load time details
    if (debug === 1) {
        t = new Date();
        console.out('Resource Request #' + count +
            ' id: ' + requestData.id + ' at ' + t.toLocaleTimeString() +
            ' url: ' + requestData.url);
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

        // Print response load time details
        if (debug === 1) {
            t = new Date();
            console.out('Response Received #' + count +
                ' id: ' + response.id +
                ' status: ' + response.status + ' at ' + t.toLocaleTimeString() +
                ' url: ' + response.url);
        }

        // If the count is 0, set a timeout for JavaScript to execute
        // and to render the page.
        if (count <= 0) {
            if (debug === 1) {
                t = new Date();
                console.out('Resource count is 0, start rendering timer at ' +
                    t.toLocaleTimeString());
            }
            renderTimeout = setTimeout(doRender, renderWait);
        }
    }
};

// ************************************************************
//
// Mainline
//
// ************************************************************

// Check for program arguments
if (system.args.length === 1) {
    console.log('Missing port number argument!');
    console.log('Usage: markup_server.js <portnumber>');
    phantom.exit();
} else {
    // 2nd argument is the port number
    port = system.args[1];
}

// Check for optional arguments
if (system.args.length > 2) {
    for (arg_count = 2; arg_count < system.args.length; arg_count++) {
        // Check argument name
        arg = system.args[arg_count];

        // Do we generate debug messages ?
        if (arg === '-debug') {
            debug = 1;
        }
    }
}

// Get the start time
start_time = Date.now();

// Make sure console.out messages go to the system stderr output stream.
console.out = function() {
    require("system").stderr.write(Array.prototype.join.call(arguments, ' ') + '\n');
};

//
// Setup an idle timer to exit the program if there is no activity
//
if (debug === 1) {
    console.log('Set initial idle timer');
}
idle_timer = setInterval(Idle_Exit, idle_timeout);

//
// Create a web service that listens for requests
//
server = require('webserver').create();

// ************************************************************
//
// Start the server to listen for requests on the specified port.
// The request may be a
//  GET - get a web page and return it's markup
//  EXIT - exit the server
//
// ************************************************************
service = server.listen(port, function(request, response) {
    var parser = document.createElement('a');

    // Attempt to allow cross site scripting.
    // This does not appear to work in all cases.
    page.settings.XSSAuditingEnabled = 'false';
    page.settings.webSecurityEnabled = 'false';
    page.settings.localToRemoteUrlAccessEnabled = 'true';

    // Set page viewport size to ensure we get a full web page and not
    // a smaller (e.g. mobile) page presentation.
    page.viewportSize = {
        width: 1280,
        height: 847
    };

    // Get the full request
    parser.href = "http://127.0.0.1:" + port + request.url;
    received_request = 1;
    if (debug === 1) {
        console.log('server, href = ' + parser.href);
    }

    // Are we exiting the server?
    if (parser.pathname === '/EXIT') {
        phantom.exit();
    }

    // Are we requesting the favicon.ico? (i.e. we are called from a browser)
    if (parser.pathname === '/favicon.ico') {
        if (debug === 1) {
            console.log("Ignore favicon.ico request");
        }
        return;
    }

    // Are we getting a web page
    if (parser.pathname === '/GET') {
        // Get the query string, it contains the URL to get.
        url = parser.search;

        // Look for a url, page_image and get_computed_styles variable in the query string
        url = getParameterByName('url', parser.href);
        page_image_file_name = getParameterByName('page_image', parser.href);
        get_computed_styles = getParameterByName('get_computed_styles', parser.href);
        if (debug === 1) {
            console.log('Get url = ' + url + ' get_computed_styles ' +
                get_computed_styles + ' page_image = ' + page_image_file_name);
        }

        // Did we find a URL parameter?
        if (url === '') {
            console.log('Missing URL parameter ' + parser.href);
            return;
        }

        // Did we get a page_image parameter?
        if (page_image_file_name != '') {
            generate_page_image = 1;
        } else {
            generate_page_image = 0;
        }

        // Did we get a get_computed_styles parameter?
        if (get_computed_styles === '1') {
            get_computed_styles = 1;
        } else {
            get_computed_styles = 0;
        }
    } else {
        // Invalid request
        console.log('Invalid request received ' + parser.pathname);
        phantom.exit();
    }

    // Server is up and running
    if (debug === 1) {
        now = new Date();
        console.log('server.listen at ' + now + ' page.open ' + url);
    }
    page.onConsoleMessage = function(msg) {
        console.log(msg);
    }

    // Open the URL provided in the url paramter of the request
    page_status = "success";
    rendering_done = 0;
    page.open(url, function(status) {
        // Set a timeout to allow for JavaScript to run.
        // The timeout is adjusted as resources (e.g. CSS, JavaScript)
        // files are loaded by the page.
        if (debug === 1) {
            t = new Date();
            console.out('Before get_page at ' + t.toLocaleTimeString());
        }
        get_page(status, function() {
            // Do we get computed styles ?
            if (get_computed_styles === 1) {
                if (debug === 1) {
                    t = new Date();
                    console.out('Get computed styles at ' + t.toLocaleTimeString());
                }
                var output = page.evaluate(function() {
                    var style_attributes, output, elements, el, i, j, k, l, len;
                    var propertyName, ref1, ref2, rule, ruleList, rules, style;
                    var pl;
                    output = {
                        url: location,
                        elements: []
                    };

                    // Get all elements in the markup
                    elements = document.getElementsByTagName("*");

                    // Loop through the elements to find those
                    // that have text.  Get the computed styles for the text.
                    for (j = 0, len = elements.length; j < len; j++) {
                        el = elements[j];

                        // Get parent element
                        pl = el.parentNode;

                        // Ignore elements that don't contain text that is displayed
                        // in the web browser.
                        if ((el.nodeName === "BASE") ||
                            (el.nodeName === "HEAD") ||
                            (el.nodeName === "HTML") ||
                            (el.nodeName === "LINK") ||
                            (el.nodeName === "META") ||
                            (el.nodeName === "NOSCRIPT") ||
                            (el.nodeName === "SCRIPT") ||
                            (el.nodeName === "STYLE") ||
                            (el.nodeName === "TITLE")) {
                            continue;
                        }

                        // Get the text from this element.  Exclude text from child elements.
                        element_text = el.textContent;
                        for (i = 0; i < el.childNodes.length; i++) {
                            child_element = el.childNodes[i];

                            // If this child node is not a #text node, we remove it's text from the element text.
                            if (child_element.nodeName !== "#text") {
                                element_text = element_text.replace(child_element.textContent, '');
                            }
                        }

                        // Remove leading whitespace
                        element_text = someText = element_text.replace(/[\r|\n|\s]*$/, "");

                        // Get the computed styles for this element
                        style = window.getComputedStyle(el, null);

                        // Get the computed style attributes
                        style_attributes = {};
                        for (i = 0; i < style.length; i++) {
                            propertyName = style.item(i);
                            style_attributes[propertyName] = style.getPropertyValue(propertyName);
                        }

                        // Save the element and styling details
                        output.elements.push({
                            id: el.id,
                            className: el.className,
                            tagName: el.tagName,
                            childNodes: el.childNodes.length,
                            innerHTML: el.innerHTML,
                            element_text: element_text,
                            offsetHeight: el.offsetHeight,
                            offsetWidth: el.offsetWidth,
                            offsetTop: el.offsetTop,
                            offsetLeft: el.offsetLeft,
                            computedStyle: style_attributes,
                            parentTagName: pl.tagName,
                        });
                    }

                    // Return the computed styles of any element containing
                    // text.
                    return output;
                });
            }

            // Set HTTP response code to 200 OK and set content type to
            // plain text (so the user agent doesn't interpret the HTML
            // markup).
            if (debug === 1) {
                t = new Date();
                console.out('Create HTTP response at ' + t.toLocaleTimeString());
            }
            response.statusCode = 200;
            response.headers = {
                'Cache': 'no-cache',
                'Content-Type': 'text/plain; charset=UTF-8',
            };

            // Did we get the page ?
            if (page_status === "success") {
                // Print marker for the start of the HTML mark-up
                response.write('===== PAGE MARKUP BEGINS =====\n');

                // Eliminate <noscript> content.  PhantomJS converts angle
                // brackets to &lt; and &gt;, so the content must be removed
                // to avoid validation errors.
                buffer = page.content;
                buffer = buffer.replace(/<\s*noscript\s*>([^<]+)<\s*\/\s*noscript\s*>/img, "");
                response.write(buffer.toString('utf8'));
                response.write('\n');

                // Print marker for the end of the HTML mark-up
                response.write('===== PAGE MARKUP ENDS =====\n');

                // Do we print out the computed style information
                if (get_computed_styles === 1) {
                    // Print marker for the start of the computed styles
                    response.write('===== COMPUTED STYLES BEGINS =====\n');

                    // Print the computed style information as a JSON string
                    response.write(JSON.stringify(output, null, 4));
                    response.write('\n');

                    // Print marker for the end of the HTML mark-up
                    response.write('===== COMPUTED STYLES ENDS =====\n');
                }
            } else {
                if (debug === 1) {
                    console.log('Failed to get page, status = ' + page_status);
                }

                // Create response page to indicate we did not find the
                // requested URL
                response.write('<html>');
                response.write('<head>');
                response.write('<title>404 Not Found</title>');
                response.write('</head>');
                response.write('<body>');
                response.write('<p>URL not found ' + url + '</p>');
                response.write('</body>');
                response.write('</html>');
                response.statusCode = 404;
            }

            // Close the response to send it back to the caller
            if (debug === 1) {
                t = new Date();
                console.log('Close response at ' + t.toLocaleTimeString());
            }
            response.close();
        });
    });

});

// Did the service get created ?
if (service) {
    if (debug === 1) {
        t = new Date();
        console.log('Web server running on port ' + port + ' at ' + t.toLocaleTimeString());
    }
} else {
    console.log('Error: Could not create web server listening on port ' + port);
    phantom.exit();
}
