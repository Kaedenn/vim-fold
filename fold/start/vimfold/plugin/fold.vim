" File: fold.vim
" Author: Kaedenn (kaedenn AT gmail DOT com)
" Version: 1.12.1
"
" The "Fold" plugin defines convenience functions to handle folding for
" specific file types, with a default for all other file types.
"
" Type <leader>f to fold according to language-specific rules.
" Type <leader>F to fold sections.
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
"   g:vimfold_no_map        disable mapping <leader>f and <leader>F
"   g:vimfold_line_enable   enable vim-fold lines
"   g:vimfold_sec_open      section open string (default: "{{{")
"   g:vimfold_sec_close     section close string (default: "}}}")
"   g:vimfold_max_indent    (Lua) how deep should we fold?
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
" New Fold Functions:
"   To add your own fold function for a given filetype, define that function
"   wherever you wish and add the following line:
"     call VimFold_Register("the-filetype", "the-function-name")
"   This line must execute after the vim-fold plugin is loaded.
"
"   For example, if you define MyObjCFoldFunc() for Objective-C, you would add
"     call VimFold_Register("objc", "MyObjCFoldFunc")
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
"     Fix bug with <leader>f and <leader>F not being mapped as expected
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
"   1.11:
"     Add support for Vue template files
"     Add support for typescript scripts (using JavaScript logic)
"     Add missing FoldApply calls
"     Rewrite VimFold_CheckOpt to remove unnecessary for-loop
"     Add VimFold_UnsetOpt
"     Refine the public API to allow for custom fold functions
"     Move support function calls outside of the type-specific functions
"   1.11.1:
"     (Python) Adjust tlpat to terminate on [A-Z]
"   1.11.2:
"     Add some error handling to FoldBegin
"   1.11.3:
"     Fix bug in GetIndent; "expandtabs" logic was backwards
"   1.12:
"     Add Lua, XML (crude)
"     Add g:vimfild_max_indent for Lua
"   1.12.1:
"     Remove default arguments from CountParens
"
" PROBLEMS:
"
" (BUG) Python folding breaks with multi-line literals with no indentation
"   workaround: textwrap.dedent(multi-line-doc-string)
" (ISSUE) don't overwrite the 'z mark in FoldBegin/FoldEnd; use a variable
" (ISSUE) Allow nested folding for parts of files instead of using %g
" (ISSUE) Remove dangerous execute in vim-fold/vim-fold-set handling

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

" For sloppy indentation-based folding, how deep should we go?
if !exists("g:vimfold_max_indent")
  let g:vimfold_max_indent = 4
endif

" Build the likely indentation string for count indents
function! <SID>GetIndent(count)
  let l:indent = repeat(" ", &shiftwidth)
  if !&expandtab
    let l:indent = "	"
  end
  return repeat(l:indent, a:count)
endfunction

" Return whether or not the given vim-fold option is set
function! VimFold_CheckOpt(opt)
  if exists("b:fold_options")
    let l:ipos = index(b:fold_options, a:opt)
    if l:ipos >= 0
      return 1
    endif
  endif
  return 0
endfunction

" Set a vim-fold option
function! VimFold_SetOpt(opt)
  if !exists("b:fold_options") | let b:fold_options = [] | endif
  call add(b:fold_options, a:opt)
  call <SID>Debug('Set option %s', a:opt)
endfunction

" Unset a vim-fold option
function! VimFold_UnsetOpt(opt)
  if exists("b:fold_options")
    let l:ipos = index(b:fold_options, a:opt)
    if l:ipos >= 0
      call remove(b:fold_options, l:ipos)
    else
      call <SID>Debug('Unset %s failed: option not set', a:opt)
    endif
  else
    call <SID>Debug('Unset %s failed: b:fold_options not defined', a:opt)
  endif
endfunction

" Apply the vim-fold patterns
function! VimFold_FoldApply()
  if <SID>Get_EnableFoldLine()
    for l:fp in b:fold_patterns
      call <SID>Debug('Executing fold pattern %s', l:fp)
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
function! VimFold_FoldBegin()
  if &foldmethod == "indent"
    echoe "can't operate with foldmethod set to indent"
  else
    " FIXME: use a variable instead of overwriting the 'z mark
    normal mz
    set nowrapscan
    if !exists("b:fold_options") | let b:fold_options = [] | endif
    if !exists("b:fold_patterns") | let b:fold_patterns = [] | endif
    if !exists("b:fold_function")
      echoe "no fold function defined"
    else
      call <SID>Debug("Beginning fold via %s", b:fold_function)
    end
  end
endfunction

" Clean up after folding
function! VimFold_FoldEnd()
  noh
  normal 'z
  set wrapscan
  " For some reason syntax highlighting breaks on long files
  if VimFold_CheckOpt("nosync") != 1
    syn sync fromstart
  endif
endfunction

" BEGIN IMPLEMENTATION DETAIL FUNCTIONS {{{0
" These functions are considered implementation details and should only be
" invoked if you know what you're doing.

" <leader>f handler: call b:fold_function
function! VimFold_DoFold()
  call VimFold_FoldBegin()
  if exists("b:fold_function")
    call b:fold_function()
  else
    call <SID>FoldDefault()
  endif
  call VimFold_FoldApply()
  call VimFold_FoldEnd()
endfunction

" <leader>F handler: fold all {{{<n> ... <n>}}} sections
function! VimFold_DoFoldSections()
  call VimFold_FoldBegin()
  call <SID>FoldSections()
  call VimFold_FoldEnd()
endfunction

" END IMPLEMENTATION DETAIL FUNCTIONS 0}}}

" BEGIN PRIVATE FUNCTIONS {{{0
" These functions are truly private. Submit a GitHub issue if you think they
" should be accessible.

" Count the parentheses (or braces, or brackets) on the given line
function! <SID>CountParens(line, syma, symb)
  let bcount = 0
  let i = 0
  while i < strlen(a:line)
    if a:line[i] == a:syma
      let bcount += 1
    elseif a:line[i] == a:symb
      let bcount -= 1
    endif
    let i += 1
  endwhile
  return bcount
endfunction

" Return whether or not fold-line configuration is enabled
function! <SID>Get_EnableFoldLine()
  if exists("g:vimfold_line_enable") && g:vimfold_line_enable == 1
    return 1
  endif
  return 0
endfunction

" Display a formatted debug message
function! <SID>Debug(msg, ...)
  if VimFold_CheckOpt("debug") == 1
    echo call(function('printf'), [a:msg] + a:000)
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

" Get the configured indent expression
function! <SID>GetIndentString()
  if &expandtab
    return repeat(' ', &shiftwidth)
  else
    return '	'
  endif
endfunction

" Go to the first byte of the file
function! <SID>GoBOF()
  call setpos(".", [bufnr("%"), 0, 0, 0])
endfunction

" BEGIN FILETYPE-SPECIFIC FOLD FUNCTIONS {{{1

" <leader>f action for Python files
function! <SID>FoldPython()
  " *my* most-common top-level keywords
  let l:tlkeywords = ['def', 'class', 'if']
  let l:tlpat = '\(' . join(l:tlkeywords, '\|') . '\|@\|#\|[A-Z]\)'
  let l:kwpat = '\(' . join(l:tlkeywords, '\|') . '\)'
  let l:istr = <SID>GetIndentString()
  " functions
  silent! execute ':%g/^'.l:istr.'\(def\) /norm zf/\zs\ze$\n[\n]\+\([^ ]\|'.l:istr.'[^ ]\)'
  " top-level VAR = [, VAR = (, VAR = {
  silent! execute ':%g/^[A-Z].*[({\[]$/norm $zf%'
  silent! execute ':%g/^'.l:kwpat.' /norm zf/\zs\ze$\n[\n]\+'.l:tlpat.''
  silent! execute ':%g/^[ 	]*[r]\?"""/norm zf/^[ 	]*"""\n\zs\ze\n'
  silent! execute ':%g/^[A-Z0-9_]\+ = [r]\?"""$/norm zf/^[ 	]*"""\n\zs\ze\n'
  silent! execute ":%g/^[ 	]*'''/norm zf/^[ 	]*'''\\n\\zs\\ze\\n"
  silent! execute ":%g/^[A-Z0-9_]\\+ = '''$/norm zf/^[ 	]*'''\\n\\zs\\ze\\n"
endfunction

" <leader>f action for Perl files
function! <SID>FoldPerl()
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
endfunction

" <leader>f action for Java files (crude)
function! <SID>FoldJava()
  "execute ':%g/^\s\+\(public\|protected\|private\) [^{]\+{[^}]*$/norm t{zf%'
  " multi-line comment blocks
  execute ':%g/^\s*\/\*[ \t]*/norm zf/^\s*\*\/\s*$\n\zs\ze/'
  " functions with { on next line
  execute ':%g/^\s\+\(public\|protected\|private\) [A-Za-z].* [a-zA-Z_].[^(]\+(\(.*\))[ \t]*\n[ \t]*{/norm jt{zf%'
  " functions with { on same-line
  execute ':%g/^\s\+\(public\|protected\|private\) [A-Za-z].* [a-zA-Z_].[^(]\+(\(.*\))\([ \t]*\){/norm t{zf%'
endfunction

" <leader>f action for JavaScript files
function! <SID>FoldJavaScript()
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
  " export function<text>{
  silent! execute ':%g/^\(export \)\?function\>[^{]\+{' . l:comment . '$/norm t{zf%'
  " <text> = function <text> {
  silent! execute ':%g/^[^ ]\+ = [(]\?function[^{]\+{' . l:comment . '$/norm t{zf%'
  " <text>(<text>?) => {
  silent! execute ':%g/^[^ ]\+[^\w]([^)]*) => {' . l:comment . '$/norm t{zf%'
  " <stuff>class <stuff?> {   (disabled)
  "execute ':%g/^.*\<class [^{]*{$/norm t{zf%'
  " (var|const|let) <stuff> {
  silent! execute ':%g/^\(export \)\?\(var\|const\|let\) [^{]\+ {[^}]*' . l:comment . '$/norm t{zf%'
  " <stuff> = {
  silent! execute ':%g/^\(export \)\?[^ ]\+ = {' . l:comment . '$/norm t{zf%'
  " <stuff> = [
  silent! execute ':%g/^\(export \)\?[^ ]\+ = \[' . l:comment . '$/norm t[zf%'
  " /** ... */ block comments
  silent! execute '%g/^[ ]*\/\*\*/norm zf/\*\/$/'
endfunction

" <leader>f action for typescript files
function! <SID>FoldTypeScript()
  " Note that the rules below for folding functions assume the parameters are
  " all on a single line. Muti-line parameter lists don't work here.
  call <SID>FoldJavaScript()
  " object and array literals
  silent! execute ':%g/^\(export \)\?const[ ]\+\w\+[ ]*=[ ]*{$/norm $zf%'
  silent! execute ':%g/^\(export \)\?const[ ]\+\w\+[ ]*=[ ]*\[$/norm $zf%'
  " special class functions (static functions, setters, and getters)
  silent! execute ':%g/^[ ]\+\(static\|[sg]et\>\) \w.\+ {$/norm $zf%'
  " class constructors
  silent! execute ':%g/^[ ]\+constructor[ ]*([^)]*)[ ]*{$/norm $zf%'
  " classes
  silent! execute ':%g/^\(export \(default \)\?\)\?class[ ]\+\w\+[ ]\+[^{]*{$/norm $zf%'
  " enums and interfaces
  silent! execute ':%g/^\(export \)\?\(enum\|interface\) [^{]\+ {[^}]*$/norm t{zf%'
endfunction

" <leader>f action for Markdown files
function! <SID>FoldMD()
  execute ':g/^#/,/\v(\n^#)@=|%$/fold'
endfunction

" <leader>f action for Vim files
function! <SID>FoldVim()
  call setpos(".", [bufnr("%"), 0, 0, 0])
  let l:s = search("^function[!]\\? ", "W")
  while l:s != 0
    let l:ls = line(".")
    let l:le = search("^endfunction", "nW")
    execute ":" l:ls "," l:le "fold"
    let l:s = search("^function[!]\\? ", "W")
  endwhile
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
  call <SID>Debug('Folded %d items using T=%s, N=%s', l:count, a:type_pat, a:name_pat)
endfunction

" <leader>f action for PL/SQL files
function! <SID>FoldPLSQL()
  call <SID>FoldPLSQL_Util('^[ ]\+FUNCTION ', '^[ ]\+FUNCTION[ ]\+\zs\w\+\ze', 'O')
  call <SID>FoldPLSQL_Util('^[ ]\+PROCEDURE ', '^[ ]\+PROCEDURE[ ]\+\zs\w\+\ze', 'O')
  call <SID>FoldPLSQL_Util('\(^\|[ ]\+\)PACKAGE ', 'PACKAGE[ ]\+\zs[^ ]\+\ze\([ ]\+AUTHID .*\)\?\([ ]*[IA]S\)\?[ ]*$', 'O')
  call <SID>FoldPLSQL_Util('\(^\|[ ]\+\)PACKAGE BODY ', 'PACKAGE BODY[ ]\+\zs[^ ]\+\ze\([ ]*[IA]S\)\?[ ]*$', 'O')
  norm zM
endfunction

" <leader>f action for Bash scripts (crude)
function! <SID>FoldBash()
  silent! g/^}/norm zf%
endfunction

" <leader>f action for scarpet scripts (crude)
function! <SID>FoldScarpet()
  " Fold first-column close-paren and close-brace if followed by a semicolon
  silent! g/^[)}];[ 	]*$/norm ^zf%
endfunction

" <leader>f action for vue files (semi-crude)
function! <SID>FoldVue()
  silent! g/^<template/norm jzf/^<\/template>
  silent! g/^<style/norm jzf/^<\/style>
  silent! g/^<script/norm jzf/^<\/script>
endfunction

" <leader>f action for Lua scripts (crude)
function! <SID>FoldLua()
  " Invoke zE because we don't want to fold the same region more than once
  norm zE
  " multi-line comments
  silent! %g/\[\[/norm zf%zo
  " table literals and friends
  silent! %g/=\s*{$/norm $zf%zo
  silent! %g/({$/norm $zf%zo
  silent! %g/^[ ]*{\([ ]*--.*\)\?$/norm t{zf%zo
  " fold functions
  let icount = g:vimfold_max_indent
  while icount >= 0
    let indent = '\(' . <SID>GetIndent(icount) . '\)'
    let prefix = '\(local \)\?\([a-zA-Z0-9_]\+[ ]*=[ ]*\)\?'
    let pattern = '^' . indent . prefix . 'function[ ]*\([ ]\+[^(]*\)\?([^)]*)\([ ]*--.*\)\?'
    let endpat = '^' . indent . 'end\>[,]\?\n\zs\ze'
    let fcommand = '%g/' . pattern . '/norm zf/' . endpat . '/'
    silent! exec fcommand
    let icount = icount - 1
  endwhile
  norm zM
endfunction

" <leader>f actions for XML files (crude)
function! <SID>FoldXml()
  let nfolds = 0
  let pat = "^[ ]*<[A-Za-z0-9_][A-Za-z0-9_]*\\>"
  let pos = search(pat)
  while pos != 0
    let line = getline(pos)
    let line = substitute(line, "\\" . nr2char(13), "", "")
    let nspaces = strlen(substitute(line, "[^ ].*", "", ""))
    let xmltag = matchstr(line, "[^ <]\\+\\>")
    if nspaces > 0
      let end_pat = "^[ ]\\{" . nspaces . "\\}<\\/" . xmltag . ">"
    else
      let end_pat = "^<\\/" . xmltag . ">"
    endif
    let end_pos = search(end_pat, "nW")
    if end_pos > pos
      execute ":" . pos . "," . end_pos . "fold"
      execute ":foldopen!"
      let nfolds = nfolds + 1
    endif
    let pos = search(pat, "W")
  endwhile
  normal ggzM
endfunction

" END FILETYPE-SPECIFIC FOLD FUNCTIONS 1}}}

" VimFold_FoldDefault implementation (crude)
function! <SID>FoldDefault()
  silent! g/^}/norm zf%
endfunction

" VimFold_DoFoldSections implementation
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

" Map <LocalLeader>f and <LocalLeader>F
function! <SID>MapKeys()
  silent! nunmap <buffer> <LocalLeader>f
  silent! nunmap <buffer> <LocalLeader>F
  nnoremap <buffer> <LocalLeader>f :call VimFold_DoFold()<CR>
  nnoremap <buffer> <LocalLeader>F :call VimFold_DoFoldSections()<CR>
  au BufNewFile,BufRead * nnoremap <buffer> <LocalLeader>f :call VimFold_DoFold()<CR>
  au BufNewFile,BufRead * nnoremap <buffer> <LocalLeader>F :call VimFold_DoFoldSections()<CR>
endfunction

" END PRIVATE FUNCTIONS 0}}}

" Register a fold function
function! VimFold_Register(ftype, func)
  if !exists("g:vimfold_functions")
    let g:vimfold_functions = {}
  endif
  let g:vimfold_functions[a:ftype] = function(a:func)
endfunction

" Initialize vim-fold plugin
" Call this if you need to reinitialize the plugin after, say, adding a custom
" fold function for some new filetype or replacing an existing fold function.
function! VimFold_Intialize()
  let l:ftype = &filetype
  if has_key(g:vimfold_functions, l:ftype)
    let b:fold_function = g:vimfold_functions[l:ftype]
  endif
  let b:fold_patterns = []
  let b:fold_options = []
  call <SID>FoldScan()
endfunction

let g:vimfold_functions = {}
call VimFold_Register("python", "<SID>FoldPython")
call VimFold_Register("java", "<SID>FoldJava")
call VimFold_Register("javascript", "<SID>FoldJavaScript")
call VimFold_Register("typescript", "<SID>FoldTypeScript")
call VimFold_Register("markdown", "<SID>FoldMD")
call VimFold_Register("vim", "<SID>FoldVim")
call VimFold_Register("plsql", "<SID>FoldPLSQL")
call VimFold_Register("sh", "<SID>FoldBash")
call VimFold_Register("perl", "<SID>FoldPerl")
call VimFold_Register("scarpet", "<SID>FoldScarpet")
call VimFold_Register("vue", "<SID>FoldVue")
call VimFold_Register("lua", "<SID>FoldLua")
call VimFold_Register("xml", "<SID>FoldXml")

" To add your own fold function, define it wherever you wish and add
" call VimFold_Register("filetype", "funcname")
" Note: Be sure to invoke this *after* this plugin is loaded.

if !exists("g:vimfold_no_map") | call <SID>MapKeys() | endif

au FileType * call VimFold_Intialize()

" vim-fold-opt-set: debug:
" vim: set ts=2 sts=2 sw=2 et:
