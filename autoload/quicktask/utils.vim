" quicktask.vim: A lightweight task management plugin.

let s:one_indent = repeat(" ", &tabstop)
let s:section_regex = '\v^\s*[^-].*:\s*$'
let s:task_or_section_regex = '\v^(\s{-}- |.*:\s*$)'

" ============================================================================
" EchoWarning(): Echo a warning message, in color! {{{1
function! quicktask#utils#EchoWarning(message)
    echohl WarningMsg
    echo a:message
    echohl None
endfunction

" ============================================================================
" GetAnyIndent(): Get the indent of the given line number. Use '.' to get
" current line indent {{{1
function! quicktask#utils#GetAnyIndent(line)
    if a:line == ''
        let a:line = '.'
    endif
    let matches = matchlist(getline(a:line), '\v^(\s{-})[^ ]')
    if empty(matches)
        return 0
    endif
    return len(matches[1])
endfunction

" ============================================================================
" GetTaskIndent(): Return current indent level. {{{1
"
" With the cursor on a task line, return the indent level of that task.
function! quicktask#utils#GetTaskIndent()
    if getline('.') =~ s:task_or_section_regex
        " What is the indentation level of this task?
        let matches = matchlist(getline('.'), '\v^(\s{-})[^ ]')
        let indent = len(matches[1])

        return indent
    endif

    return -1
endfunction

" ============================================================================
" FindTaskStart(): Find the start of the current task. {{{1
"
" Search backwards for a task line. This function moves the cursor.
" If the cursor is already on a task line, do nothing.
function! quicktask#utils#FindTaskStart(move)
    " Only move the cursor if we are asked to.
    let flags = 'bcW'
    if !a:move
        let flags .= 'n'
    endif

    return search(s:task_or_section_regex, flags)
endfunction

" ============================================================================
" FindTaskEnd(): Find the end of the current task. {{{1
"
" Search forward for the end of the current task. If we do not start on a task
" line, we first search backwards for a task line. We then search forward for
" the first line that isn't a part of that task, which may be the next task,
" the next section, or the end of the file.
function! quicktask#utils#FindTaskEnd(move)
    " If we are not on a task line
    call quicktask#utils#FindTaskStart(1)
    let task_end_line = line('.')

    " Get the indent of this task
    let indent = quicktask#utils#GetTaskIndent()

    " If this is a task line
    if indent > -1
        " Search downward, looking for either the end of the task block or
        " start/end notes and record them. Begin on the line immediately
        " following the task line.
        let task_end_line = search('^\(\s\{0,'.indent.'}[^ ]\)', 'nW')
    endif

    if task_end_line == 0
        " No next parent-level indent found, so task extends to end of buffer
        let task_end_line = line('$')+1
    endif

    if a:move
        " Move the cursor to the line immediately prior, which should be the
        " last line of the task we are looking for.
        call cursor(task_end_line-1, 0)
    else
        return task_end_line - 1
    endif
endfunction

" ============================================================================
" FindTaskParent(): Find the start line of the current task's parent. {{{1
"
" Get the indent level of the current task and, if non-zero, find the first
" line of the task that encloses this one (its 'parent').
function! quicktask#utils#FindTaskParent()
    call quicktask#utils#FindTaskStart(1)
    let indent = quicktask#utils#GetTaskIndent()

    if indent == 0
        return 0
    else
        let parent_indent = indent - &tabstop
        let parent_line = search('^\s\{'.parent_indent.'}\S', 'bnW')
        return parent_line
    endif
endfunction

" ============================================================================
" FindTaskTopParent(): Find the topmost parent of the current task {{{1
"
" Get the line number of the topmost parent the current task. If no parent,
" return 0
function! quicktask#utils#FindTaskTopParent()
    let line = quicktask#utils#FindTaskParent()
    let parent_line = line
    while parent_line != 0
        let line = parent_line
        call cursor(line, 0)
        let parent_line = quicktask#utils#FindTaskParent()
    endwhile
    return line
endfunction

" ============================================================================
" FindNextSibling(): Find the sibling task below the current task. {{{1
"
" Get the indent level of the current task and find a task below this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! quicktask#utils#FindNextSibling()
    call quicktask#utils#FindTaskStart(1)
    let indent = quicktask#utils#GetTaskIndent()

    " If we might be a child, get the location of the next line 'below' our
    " indent level, such as our parent's next sibling. This is our 'boundary
    " line', beyond which we cannot search for siblings.
    if indent > 0
        let parent_indent = indent - &tabstop
        let boundary_line = search('^\s\{0,'.parent_indent.'}\S', 'nW')
        if boundary_line == 0
            " no more tasks below our indent level
            let boundary_line = line('$')+1
        endif
    else
        " If we are at the lowest indent level, our boundary is the end of the
        " file.
        let boundary_line = line('$')
    endif

    return search('^\s\{'.indent.'}\S', 'nW', boundary_line-1)
endfunction

" ============================================================================
" FindPrevSibling(): Find the sibling task above the current task. {{{1
"
" Get the indent level of the current task and find a task above this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! quicktask#utils#FindPrevSibling()
    call quicktask#utils#FindTaskStart(1)
    let indent = quicktask#utils#GetTaskIndent()

    " If we are a child of something, find the boundary at which we must stop
    " searching. For backwards searching, this is our parent task's line.
    if indent > 0
        let boundary_line = quicktask#utils#FindTaskParent()
    else
        " If we are at the lowest indent level, our boundary is the beginning
        " of the file.
        let boundary_line = 1
    endif

    return search('^\s\{'.indent.'}[^\t \@#]', 'bnW', boundary_line)
endfunction

" ============================================================================
" SelectTask(): Create a linewise visual selection of the current task. {{{1
function! quicktask#utils#SelectTask()
    call quicktask#utils#FindTaskStart(1)
    let end_line = quicktask#utils#FindTaskEnd(0)

    execute "normal V".end_line."G"
endfunction

" ============================================================================
" IndentTask(): Indent the current task. {{{1
function! quicktask#utils#IndentTask()
    " Only allow indenting if this task has a sibling above it
    let sibling = quicktask#utils#FindPrevSibling()
    if sibling == 0
        call quicktask#utils#EchoWarning("Cannot indent task without a sibling above it")
        return
    endif

    call quicktask#utils#SelectTask()
    execute "normal >"
endfunction

" ============================================================================
" OutdentTask(): Outdent the current task. {{{1
function! quicktask#utils#OutdentTask()
    " Only allow outdenting if we're not already at column 0
    if quicktask#utils#GetTaskIndent() == 0
        call quicktask#utils#EchoWarning("Cannot outdent task that is already at column 0")
        return
    endif
    call quicktask#utils#SelectTask()
    execute "normal <"
endfunction

" ============================================================================
" GetTaskText(): Get the first line of text of a task. {{{1
function! quicktask#utils#GetTaskText()
    let task_line_num = quicktask#utils#FindTaskStart(0)
    if task_line_num
        return getline(task_line_num)
    endif

    " Fallback
    return ''
endfunction

" ============================================================================
" AddTask(after, indent): Add a task to the file. {{{1
"
" Add a 'skeleton' task to the file after the line given and at the indent
" level specified.
function! quicktask#utils#AddTask(after, indent, move_cursor)
    if a:indent > 0
        let physical_indent = repeat(" ", a:indent)
    else
        let physical_indent = ""
    endif

    " Compose the two lines to insert
    let new_task_lines = [ physical_indent . "- " ]

    if g:quicktask_task_insert_added
        let date_format = "%a %Y-%m-%d"
        if g:quicktask_task_added_include_time
            let date_format = "%a %Y-%m-%d %H:%M"
        endif
        let date_line = physical_indent . s:one_indent . "@ Added [" . strftime(date_format) . "]"
        let new_task_lines += [ date_line ]
    endif

    call append(a:after, new_task_lines)

    if a:move_cursor
        call cursor(a:after+1, len(getline(a:after+1)))
        startinsert!
    endif
endfunction

" ============================================================================
" AddTaskAbove(): Add a task above the current task. {{{1
"
" Add a task above the current task, at the current task's level.
function! quicktask#utils#AddTaskAbove()
    " We don't support inserting a task above a section.
  if getline('.') =~ ':$' && getline('.') !~ '^\s*-'
        call quicktask#utils#EchoWarning("Inserting a task above a section isn't supported.")
        return
    endif

    call quicktask#utils#FindTaskStart(1)
    let indent = quicktask#utils#GetTaskIndent()
    " Append the new task above this line
    let task_line_num = line('.')

    " Append the task, moving the cursor and starting insert
    call quicktask#utils#AddTask(task_line_num-1, indent, 1)
endfunction

" ============================================================================
" AddTaskBelow(): Add a task below the current task. {{{1
"
" Add a task below the current task, at the current task's level.
function! quicktask#utils#AddTaskBelow()
    " We insert directly below sections.
    if getline('.') =~ ':$' && getline('.') !~ '^\s*-'
        let indent = quicktask#utils#GetAnyIndent('.') + &tabstop
        let task_line_num = line('.')
    else
        " Find current task
        call quicktask#utils#FindTaskStart(1)
        " Get indent (this will be our new indent)
        let indent = quicktask#utils#GetTaskIndent()
        if indent < 0
            let indent = &tabstop
        endif

        " Find the end of the task and note the line number
        call quicktask#utils#FindTaskEnd(1)
        let task_line_num = line('.')
    endif

    " Append the task, moving the cursor and starting insert
    call quicktask#utils#AddTask(task_line_num, indent, 1)
endfunction

" ============================================================================
" AddChildTask(): Add a task as a child of the current task. {{{1
function! quicktask#utils#AddChildTask()
    " If we are not on a task line right now, we need to search up for one.
    call quicktask#utils#FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = quicktask#utils#GetTaskIndent()
    if indent < 0
        let indent = &tabstop
    else
        " The indent we want to find is the tasks's indent plus one.
        let indent = indent + &tabstop
    endif

    call quicktask#utils#FindTaskEnd(1)
    call quicktask#utils#AddTask(line('.'), indent, 1)
endfunction

" ============================================================================
" AddNoteToTask(): Add a new note to a task. {{{1
"
" Add a new note to the task.
function! quicktask#utils#AddNoteToTask()
    " If we are not on a task line right now, we need to search up for one.
    call quicktask#utils#FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = quicktask#utils#GetTaskIndent()

    " The indent we want to find is the tasks's indent plus one.
    let indent = indent + &tabstop

    let physical_indent = repeat(" ", indent)
    let note_line = physical_indent . '* '

    " Search downward, looking for existing note or beginning of Added note
    let current_line = line('.') + 1

    while current_line <= line('$')
        " If we are still at the correct indent level
        if match(getline(current_line), '\v^\s{'.indent.'}') > -1
            " If this line is a sub-task, we have reached our location.
            if match(getline(current_line), '\v^\s*-') > -1
                let current_line = current_line - 1
                break
            " If this line is an Added/Start line, we have reached our
            " location.
            elseif match(getline(current_line), '\v^\s*\@') > -1
                let current_line = current_line - 1
                break
            " If this line is a note, keep looking.
            elseif match(getline(current_line), '\v^\s*\*') > -1
                let current_line = current_line + 1
                continue
            endif
        else
            " We have reached the end of the task; we have arrived.
            let current_line = current_line - 1
            break
        endif

        let current_line = current_line + 1
    endwhile

    " Add the note to current task and move the cursor to the note
    call append(current_line, [note_line])
    call cursor(current_line + 1, indent + 3)

    " Switch to insert mode to edit the note
    startinsert!
endfunction

" ============================================================================
" MoveTaskDown(): Move the current task down. {{{1
"
" Move the current task below the following task.
function! quicktask#utils#MoveTaskDown()
    call quicktask#utils#FindTaskStart(1)
    let task_start = line('.')

    let next_sibling = quicktask#utils#FindNextSibling()
    if !next_sibling
        call quicktask#utils#EchoWarning("This task has no siblings below it. To move the task elsewhere, use delete/put.")
        return
    else
        call quicktask#utils#FindTaskEnd(1)
        let task_end = line('.')
        call cursor(task_start, 0)
    endif

    " Pull the contents of the task into a list of lines
    let task_text = getline(task_start, task_end)
    " Delete the task from the buffer
    execute "silent! ".task_start.",".task_end."d"

    "Find the end of the task that is now our moved task's prior sibling.
    call quicktask#utils#FindTaskEnd(1)
    let insert_line = line('.')
    call append(insert_line, task_text)
    call cursor(insert_line+1, 0)
endfunction

" ============================================================================
" MoveTaskUp(): Move the current task up. {{{1
"
" Move the current task up above the preceding task.
function! quicktask#utils#MoveTaskUp()
    if line('.') == 1
        return
    endif

    " Move the cursor to the task line that we are moving and get the line
    " number and indent level.
    call quicktask#utils#FindTaskStart(1)
    let task_start = line('.')
    let indent = quicktask#utils#GetTaskIndent()

    " If we are a child of something, anything, make sure we don't try to move
    " our child task into another task.
    if indent > 0
        " __Find the task above us, that we would move beyond ("sibling").__
        " Start the search in the first column because backwards search will
        " match on the current line if the match is prior to the cursor
        " position.
        call cursor(task_start, 0)
        let prev_sibling_line = search('^\s\{'.indent.'}[^\t \@\*]', 'bnW')

        " __Find our parent.__
        " We assume that our parent is one indent level lower than we are.
        let parent_indent = indent - &tabstop
        " Find the parent line.
        let parent_line = search('^\s\{'.parent_indent.'}[^\t \@\*]', 'bnW')

        " If the previous sibling is before the parent line in the file then
        " we should not move this task! Display a warning and abort.
        if parent_line > prev_sibling_line
            call quicktask#utils#EchoWarning("You can't move a task out of its parent task; use normal delete/put to move it.")
            call cursor(task_start, 0)

            return
        endif
    endif

    " Place the cursor back at the start of the task to be moved.
    call cursor(task_start, 0)

    " Is the preceding line at the same or greater indent?
    if match(getline(task_start-1), '^\(\s*$\|\s\{'.indent.',}\)') > -1
        " Search to the previous task at the same indent.
        call search('^\s\{'.indent.'}[^\t \@\*]', 'bW')
        let final_line = line('.')
        call quicktask#utils#MoveTaskDown()
        call cursor(final_line, 0)
    endif
endfunction

" ============================================================================
" AddNextTimeToTask(): Add the next logical timestamp to a task. {{{1
"
" Add the next timestamp to a task. If the task has no timestamps yet,
" add a starting time note. If it has a start with no end, add the end.
" If it has complete start and end notes, add a new start note.
function! quicktask#utils#AddNextTimeToTask()
    " If we are not on a task line right now, we need to search up for one.
    call quicktask#utils#FindTaskStart(1)

    " Don't add Times to Sections
    if getline('.') =~ s:section_regex
        call quicktask#utils#EchoWarning("Times can only be added to tasks, not sections.")
        return
    endif

    " What is the indentation level of this task?
    let indent = quicktask#utils#GetTaskIndent()

    " The indent we want to find is the tasks's indent plus one.
    let indent = indent + &tabstop

    " Search downward, looking for either the end of the task block or
    " start/end notes and record them. Begin on the line immediately
    " following the task line.
    let current_line = line('.')+1
    let matched = 0
    while current_line <= line('$')+1
        " If we are still at the correct indent level
        if match(getline(current_line), '\v^\s{'.indent.'}') > -1
            " If this line is a sub-task, we have reached our location.
            if match(getline(current_line), '\v^\s*-') > -1
                call quicktask#utils#AddStartTimeToTask(current_line-1, indent)
                let matched = 1
                break
            " If this line is a Note, skip over it.
            elseif match(getline(current_line), '\v^\s*\*') > -1
                let current_line = current_line + 1
                continue
            " If this line is an Added/Start line, we have more checking to do.
            elseif match(getline(current_line), '\v^\s*\@') > -1
                if match(getline(current_line), '\vAdded \[') > -1
                    " We skip over the Added line if it exists.
                    let current_line = current_line + 1
                    continue
                elseif match(getline(current_line), '\vStart \[') > -1
                    if match(getline(current_line), '\v, end \[\d\d:\d\d\]') == -1
                        call quicktask#utils#AddEndTimeToTask(current_line, indent)
                        let matched = 1
                        break
                    endif
                else
                    call quicktask#utils#AddStartTimeToTask(current_line-1, indent)
                    let matched = 1
                    break
                endif
            endif
        else
            " We reached the next task
            call quicktask#utils#AddStartTimeToTask(current_line-1, indent)
            break
        endif

        let current_line = current_line + 1
    endwhile

    if g:quicktask_auto_sum_time
        call quicktask#time#UpdateTaskTime('.')
    endif
endfunction

" ============================================================================
" AddStartTimeToTask(): Add a new start time to a task. {{{1
"
" Called by AddNextTimeToTask() to create a new start time note.
function! quicktask#utils#AddStartTimeToTask(start, indent)
    " Place the cursor at the given start line.
    " call cursor(a:start, 0)

    " Create the physical indent.
    let physical_indent = repeat(" ", a:indent)

    " Get the timestamp string.
    let today = '['.strftime("%a %Y-%m-%d").']'
    let now = '['.strftime("%H:%M").']'

    call append(a:start, physical_indent."@ Start ".today." ".now)

    " If the current line is a task line, we have to indent the start time. If
    " not, then we don't.
    "if match(getline('.'), '\v^\s*-') > -1
    "   exe "normal! o\<Tab>@ Start ".today." ".now."\<Esc>"
    "else
    "   exe "normal! o@ Start ".today." ".now."\<Esc>"
    "endif
endfunction

" ============================================================================
" AddEndTimeToTask(): Add the end time to an existing start time. {{{1
"
" Called by AddNextTimeToTask() to append an end time to an existing start
" time note.
function! quicktask#utils#AddEndTimeToTask(start, indent)
    " Place the cursor at the given start line.
    call cursor(a:start, 0)

    if match(getline('.'), '\vStart \[') == -1
        call quicktask#utils#AddStartTimeToTask(a:start-1)
    endif

    " Now insert the end time.
    let now = '['.strftime("%H:%M").']'
    exe "normal! A, end ".now."\<Esc>"
endfunction

" ============================================================================
" TaskComplete(): Mark a task as complete (DONE). {{{1
"
" Mark a task as complete by placing a note at the very end of the task
" containing the keyword DONE followed by the current timestamp.
function! quicktask#utils#TaskComplete()
    " If we are not on a task line right now, we need to search up for one.
    call quicktask#utils#FindTaskStart(1)

    " What is the indentation level of this task?
    let indent = quicktask#utils#GetTaskIndent()

    " The indent we want to find is the tasks's indent plus the length of one
    " indent (the number of spaces in the user's tabstop).
    let indent = indent + &tabstop

    " Search downward, looking for either a reduction in the indentation level
    " or the end of the file. The first line to fail to match will be the line
    " AFTER our insertion point. Start searching on the line after the task
    " line.
    let current_line = line('.') + 1
    let matched = 0
    while current_line <= line('$')
        " If we are still at the correct indent level
        if match(getline(current_line), '\v^\s{'.indent.'}') == -1
            " Move the cursor to the line preceding this one.
            let start = current_line - 1
            " Break out, we have arrived.
            break
        endif

        let current_line = current_line + 1
    endwhile

    " Create the timestamp.
    let today = quicktask#utils#GetDatestamp('today')

    " Save the contents of register 'a'.
    " let old_a = @a
    " Create the DONE line and save it in register 'a'.
    " let @a = physical_indent.s:one_indent."* DONE ".today
    " Insert the DONE line.
    let physical_indent = repeat(" ", indent)
    call append(start, physical_indent."@ DONE ".today)
    "exe "normal! o\<Esc>\"aP"
    " Restore the value of register 'a'.
    "let @a = old_a

    " Automatically update the time summary upon completion.
    if g:quicktask_auto_sum_time
        call quicktask#time#UpdateTaskTime('.')
    endif
endfunction

" ============================================================================
" SaveOnFocusLost(): Save the current file silently. {{{1
"
" This will be called by an autocommand to save the current task list file
" when focus is lost.
function! quicktask#utils#SaveOnFocusLost()
    if &filetype == "quicktask"
        :silent! w
    endif
endfunction

" ============================================================================
" GetDatestamp(): Get a Quicktask-formatted datestamp. {{{1
"
" Datestamps are used throughout Quicktask both for user convenience of
" tracking their tasks in the continuum of the universe immemorial and also to
" locate current tasks. GetDatestamp() returns a Quicktask-formatted
" datestamp for the requested time relative to 'now.'
function! quicktask#utils#GetDatestamp(coordinate)
    if a:coordinate == 'today'
        return '['.strftime('%a %Y-%m-%d').']'
    elseif a:coordinate == 'tomorrow'
        return '['.strftime('%a %Y-%m-%d', localtime()+86400).']'
    elseif a:coordinate == 'yesterday'
        return '['.strftime('%a %Y-%m-%d', localtime()-86400).']'
    elseif a:coordinate == 'nextweek'
        return '['.strftime('%a %Y-%m-%d', localtime()+604800).']'
    endif

    " Always return something ("today" in this case).
    return '['.strftime('%a %Y-%m-%d').']'
endfunction

" ============================================================================
" GetTimestamp(): Get a Quicktask-formatted timestamp. {{{1
"
" Timestamps are used for the start and end times added to tasks and by the
" abbreviation system. GetTimestamp() returns a Quicktask-formatted timestamp
" for the current time.
function! quicktask#utils#GetTimestamp()
    return '['.strftime('%H:%M').']'
endfunction

" ============================================================================
" ShowActiveTasksOnly(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! quicktask#utils#ShowActiveTasksOnly()
    let current_line = line('.')
    execute "normal! zR"
    execute "g/DONE\\|HELD/call CloseFoldIfOpen()"
    call cursor(current_line, 0)
endfunction

function! quicktask#utils#ShowTodayTasksOnly()
    execute "normal! zM"
    execute "g/".strftime("%Y-%m-%d")."/call OpenFoldIfClosed()"
    execute "normal! gg"
endfunction

" ============================================================================
" ShowWatchedTasksOnly(): Fold all except watched tasks. {{{1
"
" The net result is that only tasks that you are watching (containing "WATCH"
" remain open and visible in the list.
function! quicktask#utils#ShowWatchedTasksOnly()
    let current_line = line('.')
    execute "normal! zM"
    execute "g/WATCH/call OpenFoldIfClosed()"
    call cursor(current_line, 0)
endfunction

" ============================================================================
" FindIncompleteTimestamps(): Execute a search for incomplete timestamps. {{{1
"
" This function only sets the forward search pattern. It is called from a
" command that forces hlsearch to "on", which has the effect of highlighting
" any timestamp notes that have start times and no end times (presumably
" beceause you forgot to end them or they are still pending).
function! quicktask#utils#FindIncompleteTimestamps()
    let @/ = '@\sStart\s\[\w\w\w\s\d\d\d\d-\d\d-\d\d\]\s\[\d\d:\d\d\]$'
endfunction

" ============================================================================
" TopLevelTasks(): Return line number of each top-level task in buffer. {{{1
function! quicktask#utils#TopLevelTasks()
     return filter(range(line('$'), 1, -1), 'getline(v:val) =~ "^[^\\t #]"')
 endfunction
