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
(function() {
    'use strict';

    console.log('Reddit sidebar remover loaded v1.6');

    function removeSidebarAndExpand() {
        // Remove sidebars
        ['right-sidebar-container', 'left-sidebar-container'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.style.setProperty('display', 'none', 'important');
        });

        // ── KEY FIX: Reset the grid container that still has 2 columns ──
        // We must override BOTH the column definition AND the template areas,
        // because #main-content is placed into a named grid area (column 2).
        const gridContainers = document.querySelectorAll(
            '.grid-container, .main-container, [class*="grid-container"]'
        );
        gridContainers.forEach(el => {
            el.style.setProperty('grid-template-columns', '1fr', 'important');
            el.style.setProperty('grid-template-areas', 'none', 'important');
            el.style.setProperty('grid-template', 'none', 'important');
            el.style.setProperty('max-width', 'none', 'important');
            el.style.setProperty('width', '100%', 'important');
        });

        // ── KEY FIX: Reset the grid-area assignment on #main-content ──
        // When a grid item has a named grid-area, it cannot be moved with
        // grid-column alone — the area name itself must be cleared.
        const mainContent = document.getElementById('main-content');
        if (mainContent) {
            mainContent.style.setProperty('grid-area', 'auto', 'important');
            mainContent.style.setProperty('grid-column', '1 / -1', 'important');
            mainContent.style.setProperty('grid-column-start', '1', 'important');
            mainContent.style.setProperty('grid-row', 'auto', 'important');
            mainContent.style.setProperty('max-width', '100%', 'important');
            mainContent.style.setProperty('width', '100%', 'important');
            mainContent.style.setProperty('margin-left', '0', 'important');
            mainContent.style.setProperty('justify-self', 'stretch', 'important');
        }

        const mainContainer = document.querySelector('.main-container');
        if (mainContainer) {
            mainContainer.style.setProperty('grid-template-columns', '1fr', 'important');
            mainContainer.style.setProperty('grid-template', 'none', 'important');
            mainContainer.style.setProperty('max-width', 'none', 'important');
            mainContainer.style.setProperty('width', '100%', 'important');
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', removeSidebarAndExpand);
    } else {
        removeSidebarAndExpand();
    }

    const observer = new MutationObserver(removeSidebarAndExpand);
    const startObserving = () => {
        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        } else {
            setTimeout(startObserving, 100);
        }
    };
    startObserving();

    // ── CSS: Wipe the template-areas definition at source ──
    const style = document.createElement('style');
    style.textContent = `
        :root {
            --max-content-width: 100% !important;
        }

        #right-sidebar-container, #left-sidebar-container {
            display: none !important;
        }

        /* Reset grid-template (includes template-areas and template-columns) */
        .grid-container,
        .grid-container.theme-rpl,
        .grid-container.theme-rpl.grid,
        .grid-container.theme-rpl.grid.flex-nav-expanded,
        .grid-container.theme-rpl.grid.flex-nav-upsell.flex-nav-expanded,
        .grid-container.flex-nav-expanded,
        [class*="grid-container"],
        .main-container {
            grid-template: none !important;
            grid-template-columns: 1fr !important;
            grid-template-areas: none !important;
            grid-template-rows: none !important;
            max-width: none !important;
            width: 100% !important;
        }

        /* Clear the named area assignment that locks #main-content to column 2 */
        #main-content {
            grid-area: auto !important;
            grid-column: 1 / -1 !important;
            grid-column-start: 1 !important;
            justify-self: stretch !important;
            max-width: 100% !important;
            width: 100% !important;
            margin-left: 0 !important;
        }

        shreddit-app,
        shreddit-feed,
        main {
            max-width: 100% !important;
            width: 100% !important;
        }

        @media (min-width: 1200px) {
            .grid-container:not(.grid-full),
            .grid-container.theme-rpl.grid.flex-nav-expanded {
                --flex-nav-width: 0px !important;
                grid-template: none !important;
                grid-template-columns: 1fr !important;
            }
        }
    `;

    const attachStyle = () => {
        if (!document.head) return false;
        if (!document.head.contains(style)) document.head.appendChild(style);
        return true;
    };

    if (!attachStyle()) {
        const headObserver = new MutationObserver(() => {
            if (attachStyle()) headObserver.disconnect();
        });
        headObserver.observe(document.documentElement, { childList: true, subtree: true });
    }

})();
