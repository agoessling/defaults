set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

Plugin 'tpope/vim-fugitive'
Plugin 'kien/ctrlp.vim'
Plugin 'altercation/vim-colors-solarized'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" color
syntax on
colorscheme solarized
set background=dark
set t_Co=256
set cursorline
set colorcolumn=+1

" line numbers
set number

" completion
set wildmode=longest,list,full

" search
set hlsearch
set ignorecase
set smartcase
set incsearch

" folding
set foldmethod=syntax
set foldnestmax=2
set nofoldenable

" key mappings
nmap <ESC>u :noh<CR>
nmap <ESC>n :set number!<CR>
nmap <ESC>p :set paste!<CR>
nmap <ESC>w :set wrap!<CR>
nmap <ESC>k :set tabstop=8 softtabstop=8 shiftwidth=8 noexpandtab<CR>
map <C-J> :bnext<CR>
map <C-K> :bprev<CR>

" highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" style
set expandtab
set shiftwidth=2
set softtabstop=2
set formatoptions+=ro
au BufNewFile,BufRead *
  \ if &filetype == 'java' |
  \   set textwidth=100 |
  \ elseif &filetype == 'cpp' |
  \   set textwidth=80 |
  \ elseif &filetype == 'c' |
  \   set textwidth=80 |
  \ elseif &filetype == 'python' |
  \   set textwidth=80 |
  \ endif
