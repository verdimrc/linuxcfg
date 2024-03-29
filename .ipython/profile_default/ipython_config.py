# See: https://stackoverflow.com/a/48455387

"""
Syntax highlighting on Input: Change default dark blue for "object.__file__" to
a more readable color, esp. on dark background.

Find out the correct token type with:

>>> from pygments.lexers import PythonLexer
>>> list(PythonLexer().get_tokens('os.__class__'))
[(Token.Name, 'os'),
 (Token.Operator, '.'),
 (Token.Name.Variable.Magic, '__class__'),
 (Token.Text, '\n')]
"""
from pygments.token import Name

c.TerminalInteractiveShell.highlighting_style_overrides = {
    Name.Variable: "#B8860B",
    Name.Variable.Magic: "#B8860B",  # Unclear why certain ipython prefers this
    Name.Function: "#6fa8dc",        # For IPython 8+ (tone down dark blue for function name)
}

c.TerminalInteractiveShell.highlight_matching_brackets = True


################################################################################
"""
Syntax highlighting on traceback: Tone down all dark blues. IPython-8+ has more
dark blue compared to older versions. Quick test with the following:

>>> import asdf

Unfortunately, `IPython.core.ultratb.VerboseTB.get_records() hardcoded the
"default" pygments style, and doesn't seem to provide a way to override like
what Input provides. Hence, let's directly override pygments.
"""
from pygments.styles.default import DefaultStyle
DefaultStyle.styles = {k: v.replace("#0000FF", "#3d85c6") for k, v in DefaultStyle.styles.items()}
