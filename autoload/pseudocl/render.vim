" Copyright (c) 2014 Junegunn Choi
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

let s:cpo_save = &cpo
set cpo&vim

let s:RETURN   = 0
let s:CONTINUE = 1
let s:UNKNOWN  = 2
let s:EXIT     = 3

hi PseudocLCursor term=inverse cterm=inverse gui=inverse

function! pseudocl#render#loop(opts)
  let s:highlight = a:opts.highlight
  try
    call s:hide_cursor()
    let shortmess = &shortmess
    set shortmess+=T

    let old           = a:opts.input
    let history       = copy(a:opts.history)
    let s:matches     = []
    let s:history_idx = len(history)
    call add(history, old)

    while 1
      call a:opts.renderer(pseudocl#get_prompt(), old, a:opts.cursor)
      let [code, a:opts.cursor, new] =
            \ s:getchar(old, a:opts.cursor, a:opts.words, history)

      if code == s:CONTINUE
        if new != old
          call a:opts.on_change(new, old, a:opts.cursor)
        endif
        let old = new
        continue
      elseif code == s:RETURN
        call a:opts.renderer(pseudocl#get_prompt(), new, -1)
        return new
      elseif code == s:EXIT
        call a:opts.renderer(pseudocl#get_prompt(), new, -1)
        throw 'exit'
      else
        call a:opts.on_unknown_key(code, new, a:opts.cursor)
      endif
    endwhile
  finally
    call s:show_cursor()
    let &shortmess = shortmess
  endtry
endfunction

function! pseudocl#render#echo(prompt, line, cursor)
  call pseudocl#render#clear()
  call s:echo_prompt(a:prompt)
  call s:echo_line(a:line, a:cursor)
endfunction

function! pseudocl#render#clear()
  echon "\r\r"
  echon ''
endfunction

function! s:echo_line(str, cursor)
  execute 'echohl '.s:highlight
  try
    if a:cursor < 0
      echon a:str
    elseif a:cursor == len(a:str)
      echon a:str
      echohl PseudoCLCursor
      echon ' '
    else
      echon strpart(a:str, 0, a:cursor)

      echohl PseudoCLCursor
      let m = matchlist(strpart(a:str, a:cursor), '^\(.\)\(.*\)')
      echon m[1]

      execute 'echohl '.s:highlight
      echon m[2]
    endif
  finally
    echohl None
  endtry
endfunction

function! s:hide_cursor()
  if !exists('s:t_ve')
    let s:t_ve = &t_ve
    set t_ve=
  endif

  if hlID('Cursor') != 0
    redir => hi_cursor
    silent hi Cursor
    redir END
    let s:hi_cursor = 'highlight ' . substitute(hi_cursor, 'xxx\|\n', '', 'g')
    hi Cursor guibg=bg
  endif
endfunction

function! s:show_cursor()
  if exists('s:t_ve')
    let &t_ve = s:t_ve
    unlet s:t_ve
  endif

  if exists('s:hi_cursor')
    echom s:hi_cursor
    execute s:hi_cursor
  endif
endfunction

function! s:echo_prompt(prompt)
  let type = type(a:prompt)
  if type == 1
    call s:prompt_in_str(a:prompt)
  elseif type == 3
    call s:prompt_in_list(a:prompt)
  else
    echoerr "Invalid type"
  endif
endfunction

function! s:prompt_in_str(str)
  execute 'echohl '.s:highlight
  echon a:str
  echohl None
endfunction

function! s:prompt_in_list(list)
  let list = copy(a:list)
  while !empty(list)
    let hl = remove(list, 0)
    let str = remove(list, 0)
    execute 'echohl ' . hl
    echon str
  endwhile
  echohl None
endfunction

function! s:input(prompt, default)
  try
    call s:show_cursor()
    return input(a:prompt, a:default)
  finally
    call s:hide_cursor()
  endtry
endfunction

" Return:
"   - code
"   - cursor
"   - str
function! s:getchar(str, cursor, words, history)
  let str     = a:str
  let cursor  = a:cursor
  let matches = []

  let c  = getchar()
  let ch = nr2char(c)

  try
    if c == "\<S-Left>"
      let prefix = substitute(strpart(str, 0, cursor), '\s*$', '', '')
      let pos = match(prefix, '\S*$')
      if pos >= 0
        return [s:CONTINUE, pos, str]
      endif
    elseif c == "\<S-Right>"
      let begins = len(matchstr(strpart(str, cursor), '^\s*'))
      let pos = match(str, '\s', cursor + begins + 1)
      return [s:CONTINUE, pos == -1 ? len(str) : pos, str]
    elseif ch == "\<C-C>" || ch == "\<Esc>"
      return [s:EXIT, cursor, str]
    elseif ch == "\<C-A>" || c == "\<Home>"
      let cursor = 0
    elseif ch == "\<C-E>" || c == "\<End>"
      let cursor = len(str)
    elseif ch == "\<Return>"
      return [s:RETURN, cursor, str]
    elseif ch == "\<C-U>"
      let str = strpart(str, cursor)
      let cursor = 0
    elseif ch == "\<C-W>"
      let prefix = substitute(substitute(strpart(str, 0, cursor), '\s*$', '', ''), '\s*\S*$', '', '')
      let str = prefix . strpart(str, cursor)
      let cursor = len(prefix)
    elseif ch == "\<C-D>" || c == "\<Del>"
      let prefix = strpart(str, 0, cursor)
      let suffix = substitute(strpart(str, cursor), '^.', '', '')
      let str = prefix . suffix
    elseif ch == "\<C-K>"
      let str = strpart(str, 0, cursor)
    elseif ch == "\<C-H>" || c  == "\<BS>"
      if cursor == 0 && empty(str)
        return [s:EXIT, cursor, str]
      endif
      let prefix = substitute(strpart(str, 0, cursor), '.$', '', '')
      let str = prefix . strpart(str, cursor)
      let cursor = len(prefix)
    elseif ch == "\<C-B>" || c == "\<Left>"
      let cursor = len(substitute(strpart(str, 0, cursor), '.$', '', ''))
    elseif ch == "\<C-F>" || c == "\<Right>"
      let cursor += len(matchstr(strpart(str, cursor), '^.'))
    elseif (ch == "\<C-N>" || ch == "\<C-P>" || ch == "\<Up>" || ch == "\<Down>")
      let s:history_idx = (ch == "\<C-N>" || ch == "\<Up>") ?
            \ min([s:history_idx + 1, len(a:history) - 1]) :
            \ max([s:history_idx - 1, 0])
      if s:history_idx < len(a:history)
        let line = a:history[s:history_idx]
        return [s:CONTINUE, len(line), line]
      end
    elseif !empty(a:words) && (ch == "\<Tab>" || c == "\<S-Tab>")
      let before  = strpart(str, 0, cursor)
      let matches = get(s:, 'matches', pseudocl#complete#match(before, a:words))

      if !empty(matches)
        if ch == "\<Tab>"
          let matches = extend(copy(matches[1:-1]), matches[0:0])
        else
          let matches = extend(copy(matches[-1:-1]), matches[0:-2])
        endif
        let item   = matches[0]
        let str    = item . strpart(str, cursor)
        let cursor = len(item)
      endif
    elseif ch == "\<C-R>"
      let reg = nr2char(getchar())

      let text = ''
      if reg == "\<C-W>"
        let text = expand('<cword>')
      elseif reg == "\<C-A>"
        let text = expand('<cWORD>')
      elseif reg == "="
        let text = eval(s:input('=', ''))
      elseif reg =~ '[a-zA-Z0-9"]'
        let text = getreg(reg)
      end
      if !empty(text)
        let str = strpart(str, 0, cursor) . text . strpart(str, cursor)
        let cursor += len(text)
      endif
    elseif ch == "\<C-V>" || ch =~ '[[:print:]]'
      if ch == "\<C-V>"
        let ch = nr2char(getchar())
      endif
      let str = strpart(str, 0, cursor) . ch . strpart(str, cursor)
      let cursor += len(ch)
    else
      return [c, cursor, str]
    endif

    call remove(a:history, -1)
    call add(a:history, str)
    let s:history_idx = len(a:history) - 1
    return [s:CONTINUE, cursor, str]
  finally
    if empty(matches)
      unlet! s:matches
    else
      let s:matches = matches
    endif
  endtry
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

