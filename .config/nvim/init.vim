set nocompatible

""" Plugins
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source ~/.config/nvim/init.vim
endif

call plug#begin('~/.vim/plugged')
Plug 'scrooloose/nerdtree', {'on': ['NERDTreeTabsToggle', 'NERDTreeToggle']}
Plug 'jistr/vim-nerdtree-tabs', { 'on': 'NERDTreeTabsToggle'}
"Plug 'nvim-tree/nvim-tree.lua'
"Plug 'nvim-tree/nvim-web-devicons'
Plug 'bling/vim-airline'
Plug 'vim-scripts/RltvNmbr.vim'
Plug 'ntpeters/vim-better-whitespace'
Plug 'tmsvg/pear-tree'

" System-wide bundles:
" - [deprecated] conque: sudo apt-get install vim-conque
"   * Deprecation reason: vim-8 has built-in :terminal and :termdebug commands

" Programming languages
"Plug 'davidhalter/jedi-vim', {'for': 'python'}
"Plug 'JuliaLang/julia-vim', {'for': 'julia'}
"Plug 'derekwyatt/vim-scala', {'for': 'scala'}
"Plug 'tmhedberg/SimpylFold', {'for': 'python'}
"Plug 'luochen1990/rainbow'

" Color
Plug 'nanotech/jellybeans.vim'
call plug#end()

"luafile nvim-tree.lua


""" VIM settings
"set autochdir
set mouse=
set laststatus=2
set hlsearch
set colorcolumn=80
set splitbelow
set splitright
set lazyredraw
autocmd FileType help setlocal number
autocmd BufNewFile,BufRead *.jl set filetype=julia
autocmd BufNewFile,BufRead *.hql set filetype=sql
autocmd BufNewFile,BufRead *.pmml set filetype=xml
autocmd BufNewFile,BufRead *.cu set filetype=cuda
autocmd BufNewFile,BufRead *.cuh set filetype=cuda
"if v:version >= 800
    " Smart paste mode. See Vim's xterm-bracketed-paste help topic.
    let &t_BE = "\<Esc>[?2004h"
    let &t_BD = "\<Esc>[?2004l"
    let &t_PS = "\<Esc>[200~"
    let &t_PE = "\<Esc>[201~"
"endif

""" Coding style
" prefer spaces to tabs
set tabstop=4
set shiftwidth=4
set expandtab
set nowrap
set number
set foldmethod=indent
set foldlevel=99


""" Shortcuts
map <F3> :set paste!<CR>

" Use <leader>l to toggle display of whitespace
nmap <leader>l :set list!<CR>


""" Plugins configuration
" Activate nerdtree with f2
"map <F2> :NERDTreeToggle<CR>
map <F2> :NERDTreeTabsToggle<CR>
"map <F2> :NvimTreeToggle<CR>

"let g:NERDTreeDirArrows=0
"let NERDTreeIgnore = ['\.pyc$']
"autocmd FileType nerdtree set number norelativenumber

" Try to enable relative & static numbers, side-by-side.
" Silence the error message if RltvNmbr plugin not loaded.
autocmd BufEnter * :silent! RltvNmbr

" Highlight unwanted whitespace, and strip on save
let g:better_whitespace_enabled = 1
let g:strip_whitespace_on_save = 1
let g:strip_whitespace_confirm = 0
let g:strip_only_modified_lines = 0

" running under X11
set t_Co=256
set cursorline
set background=dark
let g:jellybeans_overrides = {
\       "CursorLine": { "guibg": "343434"},
\       "Search": { "guibg": "ffff87", "guifg": "303030"},
\       "VertSplit": { "guibg": "767676", "guifg": "767676"}
\   }
:silent! colorscheme jellybeans

" Color of vertical rule at 80 char
highlight ColorColumn ctermbg=237

" highlight characters past column 80.
"highlight Excess ctermbg=237 guibg=Black
"match Excess /\%80v.*/

" more subtle popup colors
if has ('gui_running')
    highlight Pmenu guibg=#cccccc gui=bold
endif

"let g:airline_powerline_fonts=1

let g:airline_skip_empty_sections = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#tab_nr_type = 1

if exists('$KITTY_WINDOW_ID')
    let &t_ut=''
endif
