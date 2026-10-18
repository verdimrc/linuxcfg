// ==UserScript==
// @name         redcafe: no rhs and expand content
// @namespace    local.forum-layout
// @version      1.0.0
// @description  Remove RedCafe's right sidebar and expand the content.
// @author       Haha Hehe, Perplexity + GPT-6.1 Sol Thinking
// @match        *://www.redcafe.net/*
// @run-at       document-start
// @grant        GM_addStyle
// ==/UserScript==

(function () {
    'use strict';

    const sidebarSelector =
        '#top > div.p-body > div > div > div > div.p-body-sidebar';

    GM_addStyle(`
        /* Hide the sidebar immediately, before removing it from the DOM. */
        ${sidebarSelector} {
            display: none !important;
        }

        /* Override the original sidebar-related width constraints. */
        .p-body-main--withSidebar .p-body-content {
            width: 100% !important;
            max-width: 100% !important;
            display: inline-block !important;
            box-sizing: border-box;
        }
    `);

    function removeSidebar() {
        document.querySelectorAll(sidebarSelector).forEach(sidebar => {
            sidebar.remove();
        });
    }

    // Handle both the initial page load and dynamically inserted sidebars.
    const observer = new MutationObserver(removeSidebar);
    observer.observe(document, {
        childList: true,
        subtree: true
    });

    removeSidebar();
})();
