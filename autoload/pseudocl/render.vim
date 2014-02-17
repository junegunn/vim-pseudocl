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

if exists("*strwidth")
  function! s:strwidth(str)
    return strwidth(a:str)
  endfunction
else
  function! s:strwidth(str)
    return len(split(a:str, '\zs'))
  endfunction
endif

function! pseudocl#render#loop(opts)
  let s:highlight = a:opts.highlight
  let s:yanked = ''
  let xy = [&ruler, &showcmd]
  try
    set noruler noshowcmd
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
    let [&ruler, &showcmd] = xy
  endtry
endfunction

function! pseudocl#render#echo(prompt, line, cursor)
  if getchar(1) == 0
    call pseudocl#render#clear()
    let plen = s:echo_prompt(a:prompt)
    call s:echo_line(a:line, a:cursor, plen)
  endif
endfunction

function! pseudocl#render#clear()
  echon "\r\r"
  echon ''
endfunction

function! s:strtrans(str)
  return substitute(a:str, "\n", '^M', 'g')
endfunction

function! s:trim(str, margin, left)
  let str = a:str
  let mod = 0
  let ww  = winwidth(winnr()) - a:margin - 2
  let sw  = s:strwidth(str)
  let pat = a:left ? '^.' : '.$'
  while sw >= ww
    let sw -= s:strwidth(matchstr(str, pat))
    let str = substitute(str, pat, '', '')
    let mod = 1
  endwhile
  if mod
    let str = substitute(str, a:left ? '^..' : '..$', '', '')
  endif
  return [str, mod ? '..' : '', sw]
endfunction

function! s:trim_left(str, margin)
  return s:trim(a:str, a:margin, 1)
endfunction

function! s:trim_right(str, margin)
  return s:trim(a:str, a:margin, 0)
endfunction

function! s:echo_line(str, cursor, prompt_width)
  try
    if a:cursor < 0
      let [str, ellipsis, _] = s:trim_left(s:strtrans(a:str), a:prompt_width + 2)
      if !empty(ellipsis)
        echohl NonText
        echon ellipsis
      endif

      execute 'echohl '.s:highlight
      echon str
    elseif a:cursor == len(a:str)
      let [str, ellipsis, _] = s:trim_left(s:strtrans(a:str), a:prompt_width + 2)
      if !empty(ellipsis)
        echohl NonText
        echon ellipsis
      endif

      execute 'echohl '.s:highlight
      echon str

      echohl PseudoCLCursor
      echon ' '
    else
      let prefix = s:strtrans(strpart(a:str, 0, a:cursor))
      let m = matchlist(strpart(a:str, a:cursor), '^\(.\)\(.*\)')
      let cursor = s:strtrans(m[1])
      let suffix = s:strtrans(m[2])

      let [prefix, ellipsis, pwidth] = s:trim_left(prefix,  a:prompt_width + 1 + 2)

      if !empty(ellipsis)
        echohl NonText
        echon ellipsis
      endif

      execute 'echohl '.s:highlight
      echon prefix

      echohl PseudoCLCursor
      echon cursor

      let [suffix, ellipsis, _] = s:trim_right(suffix, a:prompt_width + pwidth - 1 + 2)
      execute 'echohl '.s:highlight
      echon suffix
      if !empty(ellipsis)
        echohl NonText
        echon ellipsis
      endif
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
    execute s:hi_cursor
  endif
endfunction

function! s:echo_prompt(prompt)
  let type = type(a:prompt)
  if type == 1
    let len = s:prompt_in_str(a:prompt)
  elseif type == 3
    let len = s:prompt_in_list(a:prompt)
  else
    echoerr "Invalid type"
  endif
  return len
endfunction

function! s:prompt_in_str(str)
  execute 'echohl '.s:highlight
  echon a:str
  echohl None
  return s:strwidth(a:str)
endfunction

function! s:prompt_in_list(list)
  let list = copy(a:list)
  let len = 0
  while !empty(list)
    let hl = remove(list, 0)
    let str = remove(list, 0)
    execute 'echohl ' . hl
    echon str
    let len += s:strwidth(str)
  endwhile
  echohl None
  return len
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
      let s:yanked = strpart(str, 0, cursor)
      let str = strpart(str, cursor)
      let cursor = 0
    elseif ch == "\<C-W>"
      let ostr = strpart(str, 0, cursor)
      let prefix = substitute(substitute(strpart(str, 0, cursor), '\s*$', '', ''), '\S*$', '', '')
      let s:yanked = strpart(ostr, len(prefix))
      let str = prefix . strpart(str, cursor)
      let cursor = len(prefix)
    elseif ch == "\<C-D>" || c == "\<Del>"
      let prefix = strpart(str, 0, cursor)
      let suffix = substitute(strpart(str, cursor), '^.', '', '')
      let str = prefix . suffix
    elseif ch == "\<C-K>"
      let s:yanked = strpart(str, cursor)
      let str = strpart(str, 0, cursor)
    elseif ch == "\<C-Y>"
      let str = strpart(str, 0, cursor) . s:yanked . strpart(str, cursor)
      let cursor += len(s:yanked)
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
    elseif ch == "\<C-N>"    || ch == "\<C-P>"      ||
         \ c  == "\<Up>"     || c  == "\<Down>"     ||
         \ c  == "\<PageUp>" || c  == "\<PageDown>" ||
         \ c  == "\<S-Up>"   || c  == "\<S-Down>"
      let s:history_idx = (ch == "\<C-N>"    || c == "\<PageDown>" ||
                          \ c == "\<S-Down>" || c == "\<Down>") ?
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
      elseif reg =~ '[a-zA-Z0-9"/%#*+:.-]'
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

