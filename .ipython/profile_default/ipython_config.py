from pygments.token import Token, Keyword, Name, Comment, String, Error, Number, Operator, Generic, Whitespace

# Change default dark blue for "object.__file__" to a more readable color.
# Recommended for dark background.
c.TerminalInteractiveShell.highlighting_style_overrides = {
    Name.Variable: "#B8860B",
    # Name.Variable: "#2CB5E9"
}

c.TerminalInteractiveShell.highlight_matching_brackets = True

