" File: fold.vim
" Author: Kaedenn (kaedenn AT gmail DOT com)
" Version: 1.10
"
" The "Fold" plugin defines convenience functions to handle folding for
" specific file types, with a default for all other file types.
"
" Type ,f to fold according to language-specific rules.
" Type ,F to fold sections.
"
" Sections are regions between "{{{<nr>" and "<nr>}}}" where "<nr>" is a
" number from 0-9. Sections shouldn't overlap but can be nested.
"
" Additional fold patterns can be specified using "vim-fold" lines.
" These lines are similar to vim modelines and have the following
" formats:
"   <any><space>vim-fold:<space><pattern>
"   <any><space>vim-fold-set:<space><pattern>:<any-nocolon>
" where
"   <any> is a sequence of zero or more characters
"   <space> is a sequence of one or more spaces
"   <pattern> is the pattern you wish to fold
"   <any-nocolon> is a sequence of zero or more characters excluding ':'
" These expressions are applied only when g:vimfold_line_enable == 1.
"
" The last character of <pattern> must work with % movement, like
" ( ) [ ] { } < >.
"
" Various boolean options can be set via "vim-fold-opt" lines. These
" lines are similar to vim modelines and have the following formats:
"   <any><space>vim-fold-opt:<space><options>
"   <any><space>vim-fold-opt-set:<space><options>:<any-nocolon>
" where
"   <any> is a sequence of zero or more characters
"   <space> is a sequence of one or more spaces
"   <options> is a sequence of words
"   <any-nocolon> is a sequence of zero or more characters excluding ':'
"
" Configuration:
"   g:vimfold_disable       if defined, disable this entire plugin
"   g:vimfold_no_map        disable mapping ,f and ,F
"   g:vimfold_line_enable   enable vim-fold lines
"   g:vimfold_sec_open      section open string (default: "{{{")
"   g:vimfold_sec_close     section close string (default: "}}}")
" The vimfold_line_enable variables are dangerous. See Caveats below.
"
" Examples:
"   Add a fold rule from "foo(" to the matching ")":
"   # vim-fold: foo(
"   # vim-fold-set: foo(:
"
"   Fold multi-line Python-style arrays/tuples/dicts:
"   # vim-fold: \(\[\|(\|{\)$
"   # vim-fold-set: \(\[\|(\|{\)$:
"
" Caveats:
"   vim-fold allows execution of arbitrary vim expressions. Therefore,
"   unless you're editing files you trust or have created yourself, I
"   suggest leaving this feature disabled (leave g:vimfold_line_enable
"   unset or set 0).
"
" Changes:
"   1.5:
"     (Python) Improve function folding and add triple-quoted literal support
"     (JS) Add /** .. */ folding
"   1.6:
"     (Perl) Add support for Perl, including array literals and PODs
"   1.6.1:
"     (PLSQL) Hide FoldPLSQL_Util with <SID>
"   1.7:
"     Configuration rewrite and script refactor
"   1.7.1:
"     Add g:vimfold_enable
"   1.7.2:
"     Fix bug with ,f and ,F not being mapped as expected
"   1.8:
"     Re-add Perl folding, add Bash folding
"   1.9:
"     Fix bug with name detection in PL/SQL functions/procedures
"     Expose option setting/getting API
"     Overall cleanliness improvements
"   1.10:
"     Add g:vimfold_mapleader
"     Add g:vimfold_disable
"     Add g:vimfold_no_map
"     Rename g:vimfold_enable to g:vimfold_line_enable
"
" ISSUES:
"
" (BUG?) Python: @decorate(arg) decorators break folding
"
" (ISSUE) Remove dangerous execute in vim-fold/vim-fold-set handling.

if exists("g:vimfold_disable")
  finish
endif

" vim-fold inline patterns and options
let g:vimfold_pattern = '^[^ ]*[ ]\+\(vim-fold\):[ ]\+\(.*\)$'
let g:vimfoldset_pattern = '^[^ ]*[ ]\+\(vim-fold-set\):[ ]\+\(.*\):[^:]*$'
let g:vimfoldopt_pattern = '^[^ ]*[ ]\+\(vim-fold-opt\):[ ]\+\(.*\)$'
let g:vimfoldoptset_pattern = '^[^ ]*[ ]\+\(vim-fold-opt-set\):[ ]\+\(.*\):[^:]*$'

if exists("g:vimfold_mapleader")
  let maplocalleader = g:vimfold_mapleader
endif

" Return whether or not the given vim-fold option is set
function! VimFold_CheckOpt(opt)
  if !exists("b:fold_options") | return 0 | endif
  for optstr in b:fold_options
    if optstr == a:opt
      return 1
    endif
  endfor
  return 0
endfunction

" Set a vim-fold option
function! VimFold_SetOpt(opt)
  if !exists("b:fold_options") | let b:fold_options = [] | endif
  call add(b:fold_options, a:opt)
endfunction

" Return whether or not fold-line configuration is enabled
function! <SID>Get_EnableFoldLine()
  if exists("g:vimfold_line_enable") && g:vimfold_line_enable == 1
    return 1
  endif
  return 0
endfunction

" Display a debug message
function! <SID>Debug(...)
  if VimFold_CheckOpt("debug") == 1
    echo a:000
  endif
endfunction

" Execute "cmd" across lines numbered from "ls" to "le"
function! <SID>RangeExec(ls, le, cmd)
  if type(a:ls) != type(0)
    throw "argument error: ls is not a number: " . a:ls
  endif
  if type(a:le) != type(0)
    throw "argument error: le is not a number: " . a:le
  endif
  if a:ls < 0
    throw "argument error: ls < 0: " . a:ls
  endif
  if a:le > line("$")
    throw "argument error: le > EOF: " . a:le
  endif

  execute ":" a:ls "," a:le a:cmd
endfunction

" Extract vim-fold directive from the given line
function! <SID>ParseFoldLine(line)
  if match(a:line, g:vimfold_pattern) > -1
    return substitute(a:line, g:vimfold_pattern, '\1 \2', '')
  elseif match(a:line, g:vimfoldset_pattern) > -1
    return substitute(a:line, g:vimfoldset_pattern, '\1 \2', '')
  elseif match(a:line, g:vimfoldopt_pattern) > -1
    return substitute(a:line, g:vimfoldopt_pattern, '\1 \2', '')
  elseif match(a:line, g:vimfoldoptset_pattern) > -1
    return substitute(a:line, g:vimfoldoptset_pattern, '\1 \2', '')
  else
    return ""
  endif
endfunction

" Parse and add the current line as a vim fold pattern or option
function! <SID>AddFoldLine()
  if !exists("b:fold_options") | let b:fold_options = [] | endif
  if !exists("b:fold_patterns") | let b:fold_patterns = [] | endif
  let l:pat = <SID>ParseFoldLine(getline("."))
  if strlen(l:pat) > 0 && stridx(l:pat, " ") > 0
    let l:cmd = strpart(l:pat, 0, stridx(l:pat, " "))
    let l:args = strpart(l:pat, stridx(l:pat, " ") + 1)
    if l:cmd == "vim-fold" || l:cmd == "vim-fold-set"
      call add(b:fold_patterns, l:args)
    elseif l:cmd == "vim-fold-opt"
      call add(b:fold_options, l:args)
    elseif l:cmd == "vim-fold-opt-set"
      for l:word in split(l:args)
        call add(b:fold_options, l:word)
      endfor
    endif
  endif
endfunction

" Scan for and populate b:fold_patterns and b:fold_options
function! <SID>FoldScan()
  let l:oldpos = getpos(".")
  call setpos(".", [bufnr("%"), 0, 0, 0])
  silent! %g/^[^ ]*[ ]\+vim-fold\(-opt\)\?\(-set\)\?:[ ]\+/call <SID>AddFoldLine()
  call setpos(".", l:oldpos)
endfunction

" Apply the vim-fold patterns
function! <SID>FoldApply()
  if <SID>Get_EnableFoldLine()
    for l:fp in b:fold_patterns
      call <SID>Debug('Executing fold pattern', l:fp)
      " FIXME: Do this without execute
      silent! execute ':g/' . l:fp . '/norm $zf%'
    endfor
  endif
  if VimFold_CheckOpt("sections") == 1
    call <SID>Debug('vimfold option "sections" set; folding sections')
    call <SID>FoldSections()
  endif
endfunction

" Set up folding
function! <SID>FoldBegin()
  normal mz
  set nowrapscan
  if !exists("b:fold_options") | let b:fold_options = [] | endif
  if !exists("b:fold_patterns") | let b:fold_patterns = [] | endif
endfunction

" Clean up after folding
function! <SID>FoldEnd()
  noh
  normal 'z
  set wrapscan
  " For some reason syntax highlighting breaks on long files
  if VimFold_CheckOpt("nosync") != 1
    syn sync fromstart
  endif
endfunction

" ,f action for Python files
function! <SID>FoldPython()
  call <SID>FoldBegin()
  silent! execute ':%g/^[A-Z].*[({\[]$/norm $zf%'
  "silent! execute ':%g/^  \(def\) /norm zf/\zs\ze$\n[\n]\+\([^ ]\|  [^ ]\)'
  "silent! execute ':%g/^    \(def\) /norm zf/\zs\ze$\n[\n]\+\([^ ]\|  [^ ]\)'
  silent! execute ':%g/^\(def\|class\|if\) /norm zf/\zs\ze$\n[\n]\+[^ ]'
  silent! execute ':%g/^[ 	]*[r]\?"""/norm zf/^[ 	]*"""\n\zs\ze\n'
  silent! execute ':%g/^[A-Z0-9_]\+ = [r]\?"""$/norm zf/^[ 	]*"""\n\zs\ze\n'
  silent! execute ":%g/^[ 	]*'''/norm zf/^[ 	]*'''\\n\\zs\\ze\\n"
  silent! execute ":%g/^[A-Z0-9_]\\+ = '''$/norm zf/^[ 	]*'''\\n\\zs\\ze\\n"
  call <SID>FoldApply()
  call <SID>FoldEnd()
endfunction

" ,f action for Perl files
function! <SID>FoldPerl()
  call <SID>FoldApply()
  call <SID>FoldBegin()
  silent! %g/__END__/norm zfG
  silent! %g/^our .*($/norm $zf%
  silent! %g/^}/norm zf%
  " Fold POD sections
  call setpos(".", [bufnr("%"), 0, 0, 0])
  let l:s = search("^=[a-z]", "W")
  while l:s != 0
    let l:ls = line(".")
    if getline(l:ls) == "=cut"
      continue
    endif
    let l:e = search("^=cut", "W")
    if l:e > 0
      execute(":" . l:s . "," . l:e . "fold")
    else
      execute(":" . l:s . ",$fold")
    endif
    let l:s = search("^=[a-z]", "W")
  endwhile
  call <SID>FoldEnd()
endfunction

" ,f action for Java files (crude)
function! <SID>FoldJava()
  call <SID>FoldBegin()
  execute ':%g/^\s\+\(public\|protected\|private\) [^{]\+{[^}]*$/norm t{zf%'
  call <SID>FoldApply()
  call <SID>FoldEnd()
endfunction

" ,f action for JavaScript files
function! <SID>FoldJS()
  call <SID>FoldBegin()
  let l:comment = '\%( \/\* .* \*\/\)\?'
  " Order is very important here!
  " <2 spaces> function(arguments) {
  silent! execute ':%g/^  [(]\?\<function\>\([^(]\+\)\?([^)]*) {' . l:comment . '$/norm t{zf%'
  " (static)? (set|get)? function-name(arguments) {
  silent! execute ':%g/^  \(static \)\?\([sg]et\> \)\?\w\+([^)]*) {[^}]*' . l:comment . '$/norm t{zf%'
  " (set|get)? [identifier](arguments) {
  silent! execute ':%g/^  \([sg]et\> \)\?\[[^\]]\+\]([^}]*) {[^}]*' . l:comment . '$/norm t{zf%'
  " <text>function<text>{
  silent! execute ':%g/^[(]\?function\>[^{]\+{' . l:comment . '$/norm t{zf%'
  " <text> = function <text> {
  silent! execute ':%g/^[^ ]\+ = [(]\?function[^{]\+{' . l:comment . '$/norm t{zf%'
  " <text>(<text>?) => {
  silent! execute ':%g/^[^ ]\+[^\w]([^)]*) => {' . l:comment . '$/norm t{zf%'
  " <stuff>class <stuff?> {   (disabled)
  "execute ':%g/^.*\<class [^{]*{$/norm t{zf%'
  " (var|const|let) <stuff> {
  silent! execute ':%g/^\(var\|const\|let\) [^{]\+ {[^}]*' . l:comment . '$/norm t{zf%'
  " <stuff> = {
  silent! execute ':%g/^[^ ]\+ = {' . l:comment . '$/norm t{zf%'
  " <stuff> = {
  silent! execute ':%g/^[^ ]\+ = \[' . l:comment . '$/norm t[zf%'
  " /** ... */ block comments
  silent! execute '%g/^[ ]*\/\*\*/norm zf/\*\/$/'
  call <SID>FoldApply()
  call <SID>FoldEnd()
endfunction

" ,f action for Markdown files
function! <SID>FoldMD()
  call <SID>FoldBegin()
  execute ':g/^#/,/\v(\n^#)@=|%$/fold'
  call <SID>FoldApply()
  call <SID>FoldEnd()
endfunction

" ,f action for Vim files
function! <SID>FoldVim()
  call <SID>FoldBegin()
  call setpos(".", [bufnr("%"), 0, 0, 0])
  let l:s = search("^function[!]\\? ", "W")
  while l:s != 0
    let l:ls = line(".")
    let l:le = search("^endfunction", "nW")
    execute ":" l:ls "," l:le "fold"
    let l:s = search("^function[!]\\? ", "W")
  endwhile
  call <SID>FoldApply()
  call <SID>FoldEnd()
endfunction

" Helper function for PL/SQL folding
function! <SID>FoldPLSQL_Util(type_pat, name_pat, ...)
  call setpos(".", [bufnr("%"), 0, 0, 0])
  let l:start = search(a:type_pat, 'W')
  let l:count = 0
  while l:start != 0
    let l:name = matchstr(getline('.'), a:name_pat)
    let l:end_pat = '^[ ]*END ' . l:name . '[ ]*[;]\?[ ]*$'
    let l:end = search(l:end_pat, 'W')
    if l:end > l:start
      execute(":" . l:start . "," . l:end . "fold")
      let l:count = l:count + 1
      if a:0 == 'O'
        execute(":" . l:start . "," . l:end . "foldopen")
      endif
    endif
    let l:start = search(a:type_pat, 'W')
  endwhile
  call <SID>Debug('Folded ' . l:count . ' items using T=' . a:type_pat . ', N=' . a:name_pat)
endfunction

" ,f action for PL/SQL files
function! <SID>FoldPLSQL()
  call <SID>FoldBegin()
  call <SID>FoldPLSQL_Util('^[ ]\+FUNCTION ', '^[ ]\+FUNCTION[ ]\+\zs\w\+\ze', 'O')
  call <SID>FoldPLSQL_Util('^[ ]\+PROCEDURE ', '^[ ]\+PROCEDURE[ ]\+\zs\w\+\ze', 'O')
  call <SID>FoldPLSQL_Util('\(^\|[ ]\+\)PACKAGE ', 'PACKAGE[ ]\+\zs[^ ]\+\ze\([ ]\+AUTHID .*\)\?\([ ]*[IA]S\)\?[ ]*$', 'O')
  call <SID>FoldPLSQL_Util('\(^\|[ ]\+\)PACKAGE BODY ', 'PACKAGE BODY[ ]\+\zs[^ ]\+\ze\([ ]*[IA]S\)\?[ ]*$', 'O')
  call <SID>FoldApply()
  call <SID>FoldEnd()
  norm zM
endfunction

" ,f action for Bash scripts (crude)
function! <SID>FoldBash()
  call <SID>FoldBegin()
  silent! g/^}/norm zf%
  call <SID>FoldEnd()
endfunction

" ,f action for scarpet scripts (crude)
function! <SID>FoldScarpet()
  call <SID>FoldBegin()
  " Fold first-column close-paren and close-brace if followed by a semicolon
  silent! g/^[)}];[ 	]*$/norm ^zf%
  call <SID>FoldEnd()
endfunction

" VimFold_FoldDefault implementation (crude)
function! <SID>FoldDefault()
  silent! g/^}/norm zf%
endfunction

" VimFold_FoldSections implementation
function! <SID>FoldSections()
  let l:sec_open = "{{{"
  let l:sec_close = "}}}"
  if exists("g:vimfold_sec_open")
    let l:sec_open = g:vimfold_sec_open
  endif
  if exists("g:vimfold_sec_close")
    let l:sec_close = g:vimfold_sec_close
  endif
  call setpos(".", [bufnr("%"), 0, 0, 0])
  let l:s = search(l:sec_open . "[0-9]", "W")
  while l:s != 0
    let l:l = getline(".")
    let l:ls = line(".")
    let l:sn = l:l[match(l:l, l:sec_open . "[0-9]") + 3]
    let l:le = search(l:sn . l:sec_close, "nW")
    call <SID>RangeExec(l:ls, l:le, "fold")
    call <SID>RangeExec(l:ls, l:le, "foldopen")
    let l:s = search(l:sec_open . "[0-9]", "W")
  endwhile
  normal zM
endfunction

" Default ,f action
function! VimFold_FoldDefault()
  call <SID>FoldBegin()
  call <SID>FoldDefault()
  call <SID>FoldEnd()
endfunction

" Fold all {{{<n> ... <n>}}} sections
function! VimFold_FoldSections()
  call <SID>FoldBegin()
  call <SID>FoldSections()
  call <SID>FoldEnd()
endfunction

" Call b:fold_function
function! VimFold_Fold()
  if exists("b:fold_function")
    call b:fold_function()
  else
    call VimFold_FoldDefault()
  endif
endfunction

" Register a fold function
function! <SID>Register(ftype, func)
  if !exists("g:vimfold_functions")
    let g:vimfold_functions = {}
  endif
  let g:vimfold_functions[a:ftype] = function(a:func)
endfunction

" Map <LocalLeader>f and <LocalLeader>F
function! <SID>MapKeys()
  silent! nunmap <buffer> <LocalLeader>f
  silent! nunmap <buffer> <LocalLeader>F
  nnoremap <buffer> <LocalLeader>f :call VimFold_Fold()<CR>
  nnoremap <buffer> <LocalLeader>F :call VimFold_FoldSections()<CR>
  au BufNewFile,BufRead * nnoremap <buffer> <LocalLeader>f :call VimFold_Fold()<CR>
  au BufNewFile,BufRead * nnoremap <buffer> <LocalLeader>F :call VimFold_FoldSections()<CR>
endfunction

" Initialize vim-fold plugin
function! VimFold_Intialize()
  let l:ftype = &filetype
  if has_key(g:vimfold_functions, l:ftype)
    echo "Binding function to filetype " . l:ftype
    let b:fold_function = g:vimfold_functions[l:ftype]
  endif
  let b:fold_patterns = []
  let b:fold_options = []
  call <SID>FoldScan()
endfunction

let g:vimfold_functions = {}
call <SID>Register("python", "<SID>FoldPython")
call <SID>Register("java", "<SID>FoldJava")
call <SID>Register("javascript", "<SID>FoldJS")
call <SID>Register("markdown", "<SID>FoldMD")
call <SID>Register("vim", "<SID>FoldVim")
call <SID>Register("plsql", "<SID>FoldPLSQL")
call <SID>Register("sh", "<SID>FoldBash")
call <SID>Register("perl", "<SID>FoldPerl")
call <SID>Register("scarpet", "<SID>FoldScarpet")
if !exists("g:vimfold_no_map") | call <SID>MapKeys() | endif

au FileType * call VimFold_Intialize()

" vim-fold-opt-set: debug:

