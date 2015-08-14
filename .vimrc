"See also:
"http://unlogic.co.uk/2013/02/08/vim-as-a-python-ide/
"http://www.sontek.net/blog/2011/05/07/turning_vim_into_a_modern_python_ide.html


""" Enable access to X clipboard
" Ubuntu:
" $ sudo apt-get install vim-gui-common
"
" Verify:
" $ vim --version|grep .xterm_clipboard -o
" +xterm_clipboard


""" Vundle (https://github.com/VundleVim/Vundle.vim) and plugins
" Installation:
" $ git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
" $ vim +PluginInstall +qall

set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim/
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'jistr/vim-nerdtree-tabs'

" Use airline instead of powerline.
" Reason: Powerline tabs show the full abs. path which eats too much estate.
" To switch to powerline:
" - sudo pip install --user git+git://github.com/Lokaltog/powerline
" - .vimrc: set rtp+=~/.local/lib/python2.7/site-packages/powerline/bindings/vim/
"
" Then, install Powerline fonts (see .fonts/README.md)
Plugin 'bling/vim-airline'

" Conque -- run interactive commands (https://github.com/vim-scripts/Conque-Shell)
" Ubuntu:
" $ sudo apt-get install vim-conque
" $ vim-addons install conqueterm

" Programming languages
Plugin 'davidhalter/jedi-vim'
Plugin 'JuliaLang/julia-vim'
call vundle#end()
filetype plugin indent on
syntax enable


""" VIM settings
"set autochdir
set laststatus=2
set hlsearch
set colorcolumn=80
set splitbelow
set splitright
autocmd BufNewFile,BufRead *.jl set filetype=julia
autocmd BufNewFile,BufRead *.hql set filetype=sql
autocmd BufNewFile,BufRead *.pmml set filetype=xml


""" Coding style
" prefer spaces to tabs
set tabstop=4
set shiftwidth=4
set expandtab

" highlight characters past column 80. 
highlight Excess ctermbg=DarkGrey guibg=Black
match Excess /\%80v.*/

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

let NERDTreeIgnore = ['\.pyc$']

if exists('$DISPLAY') 
    " running under X11 
    set t_Co=256
    colorscheme tomorrow-night-bright

    " more subtle popup colors
    if has ('gui_running')
        highlight Pmenu guibg=#cccccc gui=bold
    endif

    let g:airline_powerline_fonts=1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#tabline#tab_nr_type = 1
else 
    " running on console 
endif 
