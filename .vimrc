"http://unlogic.co.uk/2013/02/08/vim-as-a-python-ide/
"http://www.sontek.net/blog/2011/05/07/turning_vim_into_a_modern_python_ide.html

""" Access clipboard
" $ sudo apt-get install vim-gui-common
"
" $ vim --version|grep .xterm_clipboard -o
" +xterm_clipboard


""" Plugins
call plug#begin('~/.vim/plugged')
Plug 'scrooloose/nerdtree', {'on': ['NERDTreeTabsToggle', 'NERDTreeToggle']}
Plug 'jistr/vim-nerdtree-tabs', { 'on': 'NERDTreeTabsToggle'}
Plug 'bling/vim-airline'
Plug 'vim-scripts/RltvNmbr.vim'

" System-wide bundles:
" - conque: sudo apt-get install vim-conque

" Programming languages
"Plug 'davidhalter/jedi-vim', {'for': 'python'}
"Plug 'JuliaLang/julia-vim', {'for': 'julia'}
"Plug 'derekwyatt/vim-scala', {'for': 'scala'}
"Plug 'tmhedberg/SimpylFold', {'for': 'python'}

" Color
Plug 'nanotech/jellybeans.vim'
call plug#end()


""" VIM settings
"set autochdir
set laststatus=2
set hlsearch
set colorcolumn=80
set splitbelow
set splitright
set lazyredraw
autocmd BufNewFile,BufRead *.jl set filetype=julia
autocmd BufNewFile,BufRead *.hql set filetype=sql
autocmd BufNewFile,BufRead *.pmml set filetype=xml
autocmd BufNewFile,BufRead *.cu set filetype=cuda
autocmd BufNewFile,BufRead *.cuh set filetype=cuda

" Try to enable relative & static numbers, side-by-side.
" Silence the error message if RltvNmbr plugin not loaded.
autocmd BufEnter * :silent! RltvNmbr

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

let g:NERDTreeDirArrows=0
let NERDTreeIgnore = ['\.pyc$']

if exists('$DISPLAY')
    " running under X11
    set t_Co=256
    set cursorline
    set background=dark
    let g:jellybeans_overrides = {
\       "CursorLine": { "guibg": "343434"},
\       "Search": { "guibg": "ffff87", "guifg": "303030"},
\       "VertSplit": { "guibg": "767676", "guifg": "767676"}
\   }
    colorscheme jellybeans

    " Color of vertical rule at 80 char
    highlight ColorColumn ctermbg=237

    " highlight characters past column 80.
    "highlight Excess ctermbg=237 guibg=Black
    "match Excess /\%80v.*/

    " more subtle popup colors
    if has ('gui_running')
        highlight Pmenu guibg=#cccccc gui=bold
    endif

    let g:airline_powerline_fonts=1
else
    " running on console
    colorscheme peachpuff
endif

let g:airline_skip_empty_sections = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#tab_nr_type = 1
