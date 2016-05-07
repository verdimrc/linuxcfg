require(['base/js/namespace', 'base/js/events'], function (IPython, events) {
      events.on("notebook_loaded.Notebook", function () {
              IPython.notebook.minimum_autosave_interval = 0; // disable autosave

                });
});
