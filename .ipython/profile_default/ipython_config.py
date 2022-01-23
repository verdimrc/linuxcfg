# See: https://stackoverflow.com/a/48455387
from pygments.token import Name

"""
Change default dark blue for "object.__file__" to a more readable color, esp. on dark background.

Find out the correct token type with:

>>> from pygments.lexers import PythonLexer
>>> list(PythonLexer().get_tokens('os.__class__'))
[(Token.Name, 'os'),
 (Token.Operator, '.'),
 (Token.Name.Variable.Magic, '__class__'),
 (Token.Text, '\n')]
"""
c.TerminalInteractiveShell.highlighting_style_overrides = {
    Name.Variable: "#B8860B",
    Name.Variable.Magic: "#B8860B",   # Unclear why certain ipython prefers this.
    Name.Function: "#6fa8dc",         # For IPython 8+ (tone down dark blue for function name)
}

c.TerminalInteractiveShell.highlight_matching_brackets = True
