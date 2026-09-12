@echo off
REM https://www.reddit.com/r/git/comments/a8lk83/comment/iuwnhh2/
REG DELETE HKEY_CLASSES_ROOT\Directory\shell\git_gui /f
REG DELETE HKEY_CLASSES_ROOT\Directory\shell\git_shell /f
REG DELETE HKEY_CLASSES_ROOT\LibraryFolder\background\shell\git_gui /f
REG DELETE HKEY_CLASSES_ROOT\LibraryFolder\background\shell\git_shell /f
REG DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\background\shell\git_gui /f
REG DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\background\shell\git_shell /f
