# See: https://stackoverflow.com/a/48455387
from pygments.token import Name

# Change default dark blue for "object.__file__" to a more readable color.
# Recommended for dark background.
c.TerminalInteractiveShell.highlighting_style_overrides = {
    Name.Variable: "#B8860B",         # Older ipython or pygments (unclear since which versions)
    Name.Variable.Magic: "#B8860B",   # Newer ipython or pygments (unclear since which versions)
    # Name.Variable: "#2CB5E9"
}

c.TerminalInteractiveShell.highlight_matching_brackets = True

