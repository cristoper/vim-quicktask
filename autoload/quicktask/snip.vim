" quicktask.vim: A lightweight task management plugin.


" ============================================================================
" MakeSnipName(): Make a snip name out of the task text. {{{1
function! quicktask#snip#MakeSnipName()
    " Begin with the text of the task.
    let task_text = quicktask#utils#GetTaskText()
    let task_string = ''

    " If we have task text, create a snip string automatically.
    if len(task_text)
        let matches = matchlist(task_text, '^\s*- \(.*\)$')
        if len(matches)
            let task_string = tolower(substitute(matches[1], '[^a-zA-Z]', '-', 'g'))
            if strlen(task_string) > 30
                let task_string = matchstr(task_string, '^\(.\{15\}\)')
            endif
        endif
    endif

    " If we couldn't get an adequate string automatically, prompt the user for
    " one.
    if !strlen(task_string)
        echo "The task's name is not long enough or couldn't be found."
        let orig_text = input("Enter a name for the snip: ")
        let task_string = tolower(substitute(orig_text, '[^a-zA-Z0-9]', '-', 'g'))
        if strlen(task_string) > 30
            let task_string = matchstr(task_string, '^\(.\{15\}\)')
        endif
    endif

    " Don't let the string END with a hyphen.
    if match(task_string, '-$')
        let task_string = substitute(task_string, '-$', '', '')
    endif

    return strftime('%Y%m%d%H%M%S-').task_string
endfunction

" ============================================================================
" AddSnipToTask(): Add a new snip to a task. {{{1
"
" Add a new snip (external note) to a task. This will be overhauled in 2.0
" when snips are in external files.
function! quicktask#snip#AddSnipToTask()
    " Make sure we are properly configured to use snips.
    if !quicktask#snip#CheckSnipsReadiness()
        return
    endif

    " If we are not on a task line right now, we need to search up for one.
    call quicktask#utils#FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = quicktask#utils#GetTaskIndent()

    " The indent we want to find is the tasks's indent plus one.
    let indent = indent + &tabstop
    let physical_indent = repeat(" ", indent)

    " Search downward, looking for either the end of the task block or
    " start/end notes and record them. Begin on the line immediately
    " following the task line.
    let current_line = line('.')+1
    let snip_line = current_line
    let matched = 0
    while current_line <= line('$')
        " Does this line have an indent level equal to or greater than our
        " current task's indent level?
        if match(getline(current_line), '\v^\s{'.indent.'}') > -1
            " Is this line a child task line?
            if match(getline(current_line), '\v^\s*-') > -1
                " Insert the snip above
                let snip_line = current_line - 1
                break
            else
                let snip_line = current_line - 1
                break
                " If it matches something else, like a plain note, insert the
                " snip above.
            endif
        else
            " This is the line beyond the task; the line above is the one we
            " want.
            let snip_line = current_line - 1
            break
        endif

        let current_line = current_line + 1
    endwhile

    " Generate a snip name
    let snip_name = quicktask#snip#MakeSnipName()

    " Insert the snip placeholder in the task
    call append(snip_line, physical_indent.'$ '.snip_name)

    " Create a new snip file
    execute "silent! topleft ".g:quicktask_snip_win_split_direction." ".g:quicktask_snip_win_height."split ".g:quicktask_snip_path.snip_name
    execute "normal I# vim:ft=".g:quicktask_snip_default_filetype."\<ESC>O\<ESC>O\<ESC>"
    execute "setf ".g:quicktask_snip_default_filetype
    call quicktask#snip#ConfigureSnipWindow()
endfunction

" ============================================================================
" CheckSnipsReadiness(): Check snips settings; can we use snips? {{{1
function! quicktask#snip#CheckSnipsReadiness()
    " ensure that snips path ends in a '/'
    if g:quicktask_snip_path !~ '/$'
        let g:quicktask_snip_path = g:quicktask_snip_path .. "/"
    endif

    if !exists("g:quicktask_snip_path") || !len(g:quicktask_snip_path)
        call quicktask#utils#EchoWarning("You cannot use snips because your snips path is not configured.")
        return 0
    elseif !isdirectory(g:quicktask_snip_path)
        call quicktask#utils#EchoWarning("You cannot use snips because your snips path does not exist.")
        return 0
    endif

    return 1
endfunction

" ============================================================================
" OpenSnip(): Open a snip file or reveal its buffer. {{{1
function! quicktask#snip#OpenSnip()
    " Make sure we are properly configured to use snips.
    if !quicktask#snip#CheckSnipsReadiness()
        return
    endif

    if match(getline('.'),  '^\s\+[$]\s[A-Za-z0-9-]\+$') > -1
        let snip_parts = matchlist(getline('.'), '^\s\+[$]\s\([A-Za-z0-9-]\+\)$')
        if len(snip_parts) < 1
            return
        endif

        let filename = snip_parts[1]
        let full_file = g:quicktask_snip_path.filename
        if filereadable(full_file)
            execute "silent! topleft ".g:quicktask_snip_win_split_direction." ".g:quicktask_snip_win_height."split ".full_file
            call quicktask#snip#ConfigureSnipWindow()
        else
            call quicktask#utils#EchoWarning("The snip file couldn't be found or couldn't be read.")
        endif
    endif
endfunction

" ============================================================================
" ConfigureSnipWindow(): Set up the options for the snip window. {{{1
function! quicktask#snip#ConfigureSnipWindow()
    if g:quicktask_snip_win_maximize
        if g:quicktask_snip_win_split_direction == 'vertical'
            execute "vertical resize"
        else
            execute "resize"
        endif
    endif
    execute "nnoremap <buffer> <ESC> :bdelete<CR>"
endfunction

