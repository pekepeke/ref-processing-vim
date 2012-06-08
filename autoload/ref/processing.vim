" A ref source for processing
" Version: 0.0.1
" Author : pekepeke <pekepekesamurai@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" config. {{{1
let s:is_mac = has('macunix') || (executable('uname') && system('uname') =~? '^darwin')
" let s:is_win = has('win16') || has('win32') || has('win64')

if !exists('g:ref_processing_path')  " {{{2
  if s:is_mac
    let g:ref_processing_path = '/Applications/Processing.app/Contents/Resources/Java/modes/java/reference'
  " elseif s:is_win
  "   let g:ref_processing_path = 'http://processing.org/reference/'
  else
    let g:ref_processing_path = 'http://processing.org/reference/'
  endif
endif

if !exists('g:ref_processing_cmd')  " {{{2
  let g:ref_processing_cmd =
        \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
        \ executable('w3m')    ? 'w3m -dump %s' :
        \ executable('links')  ? 'links -dump %s' :
        \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
        \ ''
endif


let s:source = {'name': 'processing'}  " {{{1

function! s:source.available()  " {{{2
  return (isdirectory(g:ref_processing_path) || g:ref_processing_path =~# '^https\?:') &&
        \      len(g:ref_processing_cmd)
endfunction


function! s:source.get_body(query)  " {{{2
  let q = matchstr(a:query, '\v%(^|\s)\zs[^-]\S*')
  let is_grammar = a:query =~# '-g\>'
  if is_grammar
    let fpath = g:ref_processing_path . "/" . q . ".html"
  else
    let fpath = g:ref_processing_path . "/" . q . "_.html"
  endif
  if filereadable(fpath) || fpath =~# '^https\?:'
    return s:execute(fpath)
  endif

  throw 'no match: ' . a:query
endfunction



function! s:source.opened(query)  " {{{2
  call s:syntax()
endfunction



function! s:source.complete(query)  " {{{2
  let q = a:query == '' || a:query =~ '\s$' ? '' : split(a:query)[-1]
  if q =~ '-'
    return ['-f', '-g']
  endif
  let list = s:appropriate_list(a:query)
  return filter(copy(list), 'v:val =~# q')
endfunction


function! s:source.get_keyword()  " {{{2
  let isk = &l:isk
  setlocal isk& isk+=- isk+=. isk+=:
  let kwd = expand('<cword>')
  let &l:isk = isk
  if strpart(kwd, 0, 1) ==# toupper(strpart(kwd, 0, 1)) && exists("b:ref_history_pos")
    let buf_prefix = substitute(b:ref_history[b:ref_history_pos][1], '[A-Z]*$', '', '')
    if buf_prefix != ""
      let kwd = buf_prefix . kwd
    endif
  endif
  return kwd
endfunction



" functions. {{{1

function! s:appropriate_list(query) "{{{2
  return a:query =~# '-g\>' ? s:cache('grammar') : s:cache('function')
endfunction


function! s:syntax()  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'ref-processing'
    return
  endif

  syntax clear
  unlet! b:current_syntax

  runtime! syntax/processing.vim
  " " 動かない
  " " syntax include @refProcessingRef syntax/processing.vim
  " syntax match refProcessingRefdocString /^ *\(Name\|Examples\|Description\|Syntax\|Parameters\|Usage\|Related\)/

  " highlight default link refProcessingRefdocString Title

  " let b:current_syntax = 'ref-processing'
endfunction



function! s:execute(file)  "{{{2
  if type(g:ref_processing_cmd) == type('')
    let cmd = split(g:ref_processing_cmd, '\s\+')
  elseif type(g:ref_processing_cmd) == type([])
    let cmd = copy(g:ref_processing_cmd)
  else
    return ''
  endif

  let file = escape(a:file, '\')
  let res = ref#system(map(cmd, 'substitute(v:val, "%s", file, "g")')).stdout
  if &termencoding != '' && &termencoding !=# &encoding
    let converted = iconv(res, &termencoding, &encoding)
    if converted != ''
      let res = converted
    endif
  endif
  return res
endfunction



function! s:gather_func(name)  "{{{2
  if matchstr(g:ref_processing_path, '^https\?://')
    return
  endif

  let list = split(globpath(g:ref_processing_path, "*.html"), "\n")
  let list = map(list, 'substitute(v:val, "^.*/\\(.*\\)\\.html$", "\\1", "")')
  if a:name == 'grammar'
    return filter(list, 'v:val !~# "_$"')
  else
    return map(filter(list, 'v:val =~# "_$"'), 'substitute(v:val, "_$", "", "")')
  endif
endfunction



function! s:func(name)  "{{{2
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction



function! s:cache(kind)  " {{{2
  return ref#cache('processing', a:kind, s:func('gather_func'))
endfunction



function! ref#processing#define()  " {{{2
  return s:source
endfunction
call ref#register_detection('processing', 'processing')



let &cpo = s:save_cpo
unlet s:save_cpo
