// ==UserScript==
// @name         Unhijack Keys
// @namespace    verdimrc
// @version      1.0
// @description  Prevent this website to hijack navigational keys
// @author       Gemini
// @match        *://*.detik.com/*
// @match        *://*.kompas.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

/** First version: synthesized by Gemini from
 * https://stackoverflow.com/questions/8916620/disable-arrow-key-scrolling-in-users-browser
 */
/*
(function() {
    'use strict';

    const hijackKeys = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'];

    window.addEventListener('keydown', function(event) {
        if (hijackKeys.includes(event.code)) {
            // Stop the website's JavaScript from intercepting the key
            event.stopPropagation();
        }
    }, true); // The 'true' uses the capture phase, breaking site-level handlers
})();
*/

// HAHA: Let's block all keys instead.
(function() {
    'use strict';

    window.addEventListener('keydown', function(event) {
        // Allow standard browser shortcuts (Ctrl, Alt, Meta/Cmd) to pass through
        if (event.ctrlKey || event.altKey || event.metaKey) {
            return;
        }

        // Stop the website's JavaScript from intercepting all other keys
        event.stopPropagation();
    }, true); // The 'true' uses the capture phase, catching events before the site does
})();
