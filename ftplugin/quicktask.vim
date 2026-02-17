" quicktask.vim: A lightweight task management plugin.
"
" Author:   Aaron Bieber
" Version:  1.4
" Date:     25 January 2014
"
" See the documentation in doc/quicktask.txt
"
" Quicktask is free software: you can redistribute it and/or modify it under
" the terms of the GNU General Public License as published by the Free
" Software Foundation, either version 3 of the License, or (at your option)
" any later version.
"
" Quicktask is distributed in the hope that it will be useful, but WITHOUT ANY
" WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
" FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
" details.
"
" You should have received a copy of the GNU General Public License along with
" Quicktask.  If not, see <http://www.gnu.org/licenses/>.

" Compatibility option reset: {{{1
let s:cpo_save = &cpo
set cpo&vim

" Boilerplate for ftplugins. {{{1
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

if !exists('b:undo_ftplugin')
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '|setlocal comments< formatoptions< spell< wrap< textwidth< expandtab< shiftwidth< tabstop< iskeyword< foldmethod< foldexpr< fillchars< foldtext<'

" Set all buffer-local settings: {{{1
setlocal comments=b:#,f:-,f:*
setlocal formatoptions=qnwta
setlocal spell
setlocal wrap
setlocal textwidth=80

" Quicktask uses real tabs with a visible indentation of two spaces.
setlocal expandtab
setlocal shiftwidth=2
setlocal tabstop=2

" Add the 'at' sign to the list of keyword characters so that our
" abbreviations may use it.
setlocal iskeyword=@,@-@,48-57,_,192-255

" Folding settings
setlocal foldmethod=expr
setlocal foldexpr=QTFoldLevel(v:lnum)
setlocal fillchars+=fold:\ 
setlocal foldtext=QTFoldText()

" Script settings
if has('gui_win32')
    let s:path_sep = '\'
else
    let s:path_sep = '/'
endif

" User-configurable options and their defaults {{{1
if !exists("g:quicktask_no_mappings")
    let g:quicktask_no_mappings = 0
endif

if !exists("g:quicktask_autosave")
    let g:quicktask_autosave = 0
endif

if !exists("g:quicktask_snip_win_height")
    let g:quicktask_snip_win_height = ''
endif

if !exists("g:quicktask_task_insert_added")
    let g:quicktask_task_insert_added = 1
endif

if !exists("g:quicktask_auto_sum_time")
    let g:quicktask_auto_sum_time = 1
endif

if !exists("g:quicktask_task_added_include_time")
    let g:quicktask_task_added_include_time = 0
endif

if !exists("g:quicktask_snip_default_filetype")
    let g:quicktask_snip_default_filetype = "markdown"
endif

if !exists("g:quicktask_snip_win_split_direction") ||
    \ g:quicktask_snip_win_split_direction != "vertical"

    let g:quicktask_snip_win_split_direction = ""
endif

if !exists("g:quicktask_snip_win_maximize")
    let g:quicktask_snip_win_maximize = 0
endif

" ============================================================================
" Configure snips if the user has configured the path. {{{1
if exists("g:quicktask_snip_path")
    " Expand the path right now so we don't have to do it over and over.
    let g:quicktask_snip_path = expand(g:quicktask_snip_path)

    " Should we create the directory?
    if !isdirectory(expand(g:quicktask_snip_path))
        call quicktask#utils#EchoWarning("Your snips directory, ".g:quicktask_snip_path." doesn't exist.")
        let ans = ''
        while match(ans, '[YyNn]') < 0
            echo "Create it? [y/n] "
            let ans = nr2char(getchar())
        endwhile

        if ans == 'y' || ans == 'Y'
            call mkdir(g:quicktask_snip_path, 'p')
        elseif ans == 'n' || ans == 'N'
            echomsg "You will not be able to create new snips or load existing snips."
        endif
    endif

    " Append a trailing slash if one was not given.
    if match(g:quicktask_snip_path, '[\/]$') == -1
        let g:quicktask_snip_path = g:quicktask_snip_path.s:path_sep
    endif
endif

" ============================================================================
" QTFoldLevel(): Returns the fold level of the current line. {{{1
"
" This is used by the Vim folding system to fold tasks based on their depth
" and relationship to one another.
function! QTFoldLevel(linenum)
    let pre_indent = indent(a:linenum-1) / &tabstop
    let cur_indent = indent(a:linenum) / &tabstop
    let nxt_indent = indent(a:linenum+1) / &tabstop

    " fold blank lines with task
    if getline(a:linenum) =~ '^\s*$'
        return "="
    endif

    if nxt_indent == cur_indent + 1
        return '>'.nxt_indent
    elseif pre_indent == cur_indent && nxt_indent < cur_indent
        return '<'.cur_indent
    else
        return cur_indent
    endif
endfunction

" ============================================================================
" QTFoldText(): Provide the text displayed on a fold when closed. {{{1
"
" This is used by the Vim folding system to find the text to display on fold
" headings when folds are closed. We use this to cause the headings to display
" in an indented fashion matching the tasks themselves.
function! QTFoldText()
    let lines = v:foldend - v:foldstart + 1
    return getline(v:foldstart).' ('.lines.')'
    "return substitute(getline(v:foldstart), "\s", '  ', 'g').' ('.lines.')'
endfunction

" ============================================================================
" CloseFoldIfOpen(): Quietly close a fold only if it is open. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! CloseFoldIfOpen()
    if foldclosed(line('.')) == -1
        silent! normal zc
    endif
endfunction

" ============================================================================
" OpenFoldIfClosed(): Quietly open a fold only if it is closed. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! OpenFoldIfClosed()
    if foldclosed(line('.')) > -1
        execute "silent! normal ".foldlevel(line('.'))."zo"
    endif
endfunction

" ============================================================================
" QTExportBuffer(): Export buffer to a custom format {{{1
"
" Returns a string of all nodes in the buffer. Each node is serialized by calling
" the provided SerializeNode function.
"
" SerializeNode(task) - a function that takes a task and returns a string
function! QTExportBuffer(SerializeNode) abort
    let nodes = reverse(quicktask#utils#TopLevelTasks())
    let str = ""

    function! s:serialize_closure(task) closure
        let node_str = call(a:SerializeNode, [a:task])
        if !empty(node_str)
            let str .= node_str
        endif
    endfunction

    for node in nodes
        let task = quicktask#parse#QTParseTask(node)
        call quicktask#parse#WalkTreeDF(task, function('s:serialize_closure'))
    endfor
    return str
endfunction


" ============================================================================
" Private mappings {{{1

" Time and task
nmap <silent> <Plug>TaskComplete             :call quicktask#utils#TaskComplete()<CR>
nmap <silent> <Plug>ShowActiveTasksOnly      :call quicktask#utils#ShowActiveTasksOnly()<CR>
nmap <silent> <Plug>ShowWatchedTasksOnly     :call quicktask#utils#ShowWatchedTasksOnly()<CR>
nmap <silent> <Plug>ShowTodayTasksOnly       :call quicktask#utils#ShowTodayTasksOnly()<CR>
nmap <silent> <Plug>AddNextTimeToTask        :call quicktask#utils#AddNextTimeToTask()<CR>
nmap <silent> <Plug>UpdateTaskTimes          :call quicktask#time#UpdateAllTaskTimes()<CR>
nmap <silent> <Plug>FindIncompleteTimestamps :call quicktask#utils#FindIncompleteTimestamps()<CR>:silent set hlsearch \| echo<CR>

" Editing
nmap <silent> <Plug>AddTaskAbove             :call quicktask#utils#AddTaskAbove()<CR>
nmap <silent> <Plug>AddTaskBelow             :call quicktask#utils#AddTaskBelow()<CR>
nmap <silent> <Plug>AddNoteToTask            :call quicktask#utils#AddNoteToTask()<CR>
nmap <silent> <Plug>AddChildTask             :call quicktask#utils#AddChildTask()<CR>
nmap <silent> <Plug>MoveTaskUp               :call quicktask#utils#MoveTaskUp()<CR>
nmap <silent> <Plug>MoveTaskDown             :call quicktask#utils#MoveTaskDown()<CR>
nmap <silent> <Plug>IndentTask               :call quicktask#utils#IndentTask()<CR>
nmap <silent> <Plug>OutdentTask              :call quicktask#utils#OutdentTask()<CR>
nmap <silent> <Plug>AddSnipToTask            :call quicktask#snip#AddSnipToTask()<CR>
nmap <silent> <Plug>OpenSnipUnderCursor      :call quicktask#snip#OpenSnip()<CR>

" Movement
map <silent> <Plug>SelectTask               :call quicktask#utils#SelectTask(0)<CR>
map <silent> <Plug>SelectNoBlanksTask       :call quicktask#utils#SelectTask(1)<CR>
nmap <silent> <Plug>MoveToNextSection        :<C-u>call quicktask#move#MoveToNextSection(v:count1)<CR>
nmap <silent> <Plug>MoveToPrevSection        :<C-u>call quicktask#move#MoveToPrevSection(v:count1)<CR>
nmap <silent> <Plug>MovePrevSibling          :call quicktask#move#MoveToPrevSibling()<CR>
nmap <silent> <Plug>MoveNextSibling          :call quicktask#move#MoveToNextSibling()<CR>
nmap <silent> <Plug>MoveToParent             :call quicktask#move#MoveToParentTask()<CR>
nmap <silent> <Plug>MoveToChild              :call quicktask#move#MoveToChildTask()<CR>
nmap <silent> <Plug>MovePrevTask             :<C-u>call quicktask#move#MoveToPrevTask(v:count1)<CR>
nmap <silent> <Plug>MoveNextTask             :<C-u>call quicktask#move#MoveToNextTask(v:count1)<CR>
nmap <silent> <Plug>MoveTopSibling           :call quicktask#move#MoveToFirstSibling()<CR>
nmap <silent> <Plug>MoveBottomSibling        :call quicktask#move#MoveToLastSibling()<CR>

" Public mappings {{{1
if ! g:quicktask_no_mappings && ! exists('b:quicktask_did_mappings')
    " Time and task
    nmap <unique><buffer> <Leader>tD  <Plug>TaskComplete
    nmap <unique><buffer> <Leader>ta  <Plug>ShowActiveTasksOnly
    nmap <unique><buffer> <Leader>tw  <Plug>ShowWatchedTasksOnly
    nmap <unique><buffer> <Leader>ty  <Plug>ShowTodayTasksOnly
    nmap <unique><buffer> <Leader>ts  <Plug>AddNextTimeToTask
    nmap <unique><buffer> <Leader>tt  <Plug>UpdateTaskTimes
    nmap <unique><buffer> <Leader>tfi <Plug>FindIncompleteTimestamps

    " Editing
    nmap <unique><buffer> <Leader>tO  <Plug>AddTaskAbove
    nmap <unique><buffer> <Leader>to  <Plug>AddTaskBelow
    nmap <unique><buffer> <Leader>tn  <Plug>AddNoteToTask
    nmap <unique><buffer> <Leader>tc  <Plug>AddChildTask
    nmap <unique><buffer> <Leader>tu  <Plug>MoveTaskUp
    nmap <unique><buffer> <Leader>td  <Plug>MoveTaskDown
    nmap <unique><buffer> <Leader>tl  <Plug>IndentTask
    nmap <unique><buffer> <Leader>th  <Plug>OutdentTask
    nmap <unique><buffer> <Leader>tS  <Plug>AddSnipToTask
    nmap <unique><buffer> <CR>        <Plug>OpenSnipUnderCursor

    " Movement maps
    nmap <unique><buffer> <Leader>tv  <Plug>SelectTask
    nmap <silent><buffer> [s          <Plug>MoveToPrevSection
    nmap <silent><buffer> ]s          <Plug>MoveToNextSection
    nmap <silent><buffer> [[          <Plug>MovePrevTask
    nmap <silent><buffer> ]]          <Plug>MoveNextTask
    nmap <silent><buffer> [t          <Plug>MoveTopSibling
    nmap <silent><buffer> ]t          <Plug>MoveBottomSibling
    nmap <silent><buffer> <C-k>       <Plug>MovePrevSibling
    nmap <silent><buffer> <C-j>       <Plug>MoveNextSibling
    nmap <silent><buffer> <C-h>       <Plug>MoveToParent
    nmap <silent><buffer> <C-l>       <Plug>MoveToChild

    " Operator pending
    xmap it <Plug>SelectNoBlanksTask
    xmap at <Plug>SelectTask
    omap it <Plug>SelectNoBlanksTask
    omap at <Plug>SelectTask

    command -buffer -nargs=0 QTAddTaskBelow call quicktask#utils#AddTaskBelow()
    command -buffer QTUpdateTimes silent call quicktask#time#UpdateAllTaskTimes()
    command -buffer QTTimeSheet silent call quicktask#export#BufferToCSV()
    command -buffer QTMarkdown silent call quicktask#export#BufferToMarkdown()
    command -buffer QTAsciidoc silent call quicktask#export#BufferToAsciidoc()
    command -buffer QTHtml silent call quicktask#export#BufferToHTML()

    let b:quicktask_did_mappings = 1
endif

" ============================================================================
" Autocommands {{{1
if g:quicktask_autosave
    augroup quicktask
      au!
      autocmd BufLeave,FocusLost * call quicktask#utils#SaveOnFocusLost()
    augroup END
endif

" ============================================================================
" Abbreviations {{{1
iabbrev <expr> @today quicktask#utils#GetDatestamp('today')
iabbrev <expr> @tomorrow quicktask#utils#GetDatestamp('tomorrow')
iabbrev <expr> @yesterday quicktask#utils#GetDatestamp('yesterday')
iabbrev <expr> @nextweek quicktask#utils#GetDatestamp('nextweek')
iabbrev <expr> @now quicktask#utils#GetTimestamp()

" Compatibility option reset: {{{1
let &cpo = s:cpo_save
unlet s:cpo_save
