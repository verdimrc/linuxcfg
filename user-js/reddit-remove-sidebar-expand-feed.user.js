// ==UserScript==
// @name         Reddit - Remove Sidebar & Expand Feed
// @namespace    verdimrc
// @version      1.0
// @description  Remove sidebars and expand feed to full width
// @author       verdimrc
// @match        *://www.reddit.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

// Genealogy (chronological order):
// - The ancestor is https://www.tweeks.io/t/e1daa0c5edd441dca5a150c8
//   @namespace web.nextbyte.ai
//   @author NextByte
//   => This remove rhs
// - Remove lhs (with helps of Gemini). But, either there's is blank lhs,
//   or main centered but not full width
// - Make main takes the full width. Via Perplexity: many rounds of "search"
//   mode led to nowhere; then switch to "deep research" with one attempt
//   generated the correct script.
// - Another round with Perplexity (deep research mode) to simplify the script.

(function() {
    'use strict';

    const style = document.createElement('style');
    style.textContent = `
        /* Hide both sidebars */
        #right-sidebar-container,
        #left-sidebar-container {
            display: none !important;
        }

        /* Collapse the 2-column grid to 1 column */
        .grid-container {
            grid-template: none !important;
            grid-template-columns: 1fr !important;
        }

        /* Release main content from its named grid area (was locked to column 2) */
        #main-content {
            grid-area: auto !important;
            grid-column: 1 / -1 !important;
        }
    `;

    const attach = () => {
        if (!document.head) return false;
        document.head.appendChild(style);
        return true;
    };

    if (!attach()) {
        const obs = new MutationObserver(() => { if (attach()) obs.disconnect(); });
        obs.observe(document.documentElement, { childList: true, subtree: true });
    }

})();
