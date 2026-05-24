// ==UserScript==
// @name         Reddit - Remove Sidebar & Expand Feed
// @namespace    web.nextbyte.ai
// @version      1.0
// @description  Remove the right sidebar/footer and expand the feed to fill the space
// @author       NextByte
// @match        *://www.reddit.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

// HAHA: https://www.tweeks.io/t/e1daa0c5edd441dca5a150c8
// => scroll down and click "[view source"].
// This file is a snapshot downloaded on 23-May-2026.

(function() {
    'use strict';

    console.log('Reddit sidebar remover loaded');

    // Function to remove sidebar and expand feed
    function removeSidebarAndExpand() {
        // Remove right sidebar
        const rightSidebar = document.getElementById('right-sidebar-container');
        if (rightSidebar) {
            rightSidebar.style.display = 'none';
            console.log('Right sidebar removed');
        }

        // Expand the main container to use full width
        const mainContainer = document.querySelector('.main-container');
        if (mainContainer) {
            // Override the grid columns to use full width
            mainContainer.style.gridTemplateColumns = '1fr';
            mainContainer.style.maxWidth = '100%';
            console.log('Main container expanded');
        }

        // Expand the main content area
        const mainContent = document.getElementById('main-content');
        if (mainContent) {
            mainContent.style.maxWidth = '100%';
            mainContent.style.width = '100%';
        }

        // Remove any footer elements that might be in the sidebar
        const footerElements = document.querySelectorAll('footer, [class*="footer"]');
        footerElements.forEach(footer => {
            if (footer.closest('#right-sidebar-container')) {
                footer.style.display = 'none';
            }
        });
    }

    // Run immediately if DOM is already loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', removeSidebarAndExpand);
    } else {
        removeSidebarAndExpand();
    }

    // Use MutationObserver to handle dynamic content loading (Reddit is a SPA)
    const observer = new MutationObserver((mutations) => {
        removeSidebarAndExpand();
    });

    // Start observing when body is available
    const startObserving = () => {
        if (document.body) {
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        } else {
            setTimeout(startObserving, 100);
        }
    };

    startObserving();

    // Also add CSS to ensure the changes persist
    const style = document.createElement('style');
    style.textContent = `
        /* Hide right sidebar */
        #right-sidebar-container {
            display: none !important;
        }

        /* Expand main container */
        .main-container {
            grid-template-columns: 1fr !important;
            max-width: 100% !important;
        }

        /* Expand main content */
        #main-content {
            max-width: 100% !important;
            width: 100% !important;
        }

        /* Hide footer in sidebar */
        #right-sidebar-container footer,
        #right-sidebar-container [class*="footer"] {
            display: none !important;
        }
    `;

    // Insert style as early as possible
    if (document.head) {
        document.head.appendChild(style);
    } else {
        const headObserver = new MutationObserver(() => {
            if (document.head) {
                document.head.appendChild(style);
                headObserver.disconnect();
            }
        });
        headObserver.observe(document.documentElement, { childList: true, subtree: true });
    }

})();
