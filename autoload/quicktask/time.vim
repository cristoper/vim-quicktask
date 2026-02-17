let s:task_or_section_regex = '\v^(\s{-}- |.*:\s*$)'

" ============================================================================
" FormatTime(): Format minutes into HH:MM {{{1
function! quicktask#time#FormatTime(minutes)
    let hours = a:minutes / 60
    let minutes = a:minutes % 60
    return printf("%02d:%02d", hours, minutes)
endfunction

" ============================================================================
" FlattenTasks(): Recursively flatten list of task trees to single list {{{1
function! quicktask#time#FlattenTasks(tasks, depth)
    let flat_tasks = []
    for task in a:tasks
        let flat_tasks += [task]
        if !empty(task.children)
            let flat_tasks += quicktask#time#FlattenTasks(task.children, a:depth+1)
        endif
    endfor
    return flat_tasks
endfunction

" ============================================================================
" UpdateTasksTime(): Add/update @ Time annotations for every task in tasks and
" their children. {{{1
"
" Takes a list of parsed tasks (from QTParseTask()) and adds or updates each
" @ Time annotation based on the calculated minutes attribute.
function! quicktask#time#UpdateTasksTime(tasks) abort
    let winview = winsaveview()

    try
        " We edit tasks in place, so we need to flatten the task tree and then
        " iterate through them from the bottom up. Otherwise task line numbers
        " will shift before we process them.
        let flat_tasks = quicktask#time#FlattenTasks(a:tasks, 0)
        let sorted_tasks = sort(flat_tasks, {i1, i2 -> i2.line - i1.line})

        for task in sorted_tasks
            " Recursively update children

            " Move to the start of the task
            call cursor(task.line, 0)
            let task_end_line = quicktask#utils#FindTaskEnd(v:false, v:false)
            let indent = quicktask#utils#GetTaskIndent() + &tabstop
            let physical_indent = repeat(" ", indent)

            " Loop through lines in task to find last '@ Start' line and delete
            " any existing '@ Time' lines
            let cur_line = line('.')+1
            let start_line = 0
            while cur_line <= task_end_line
                let line = getline(cur_line)
                if line =~ s:task_or_section_regex
                    " We've reached another/sub task/section
                    break
                elseif line =~ '\v^\s{'.indent.'}\@ Time'
                    call deletebufline("%", cur_line)
                    continue
                elseif line =~ '\v^\s{'.indent.'}\@ Start'
                    let start_line = cur_line
                endif
                let cur_line = cur_line + 1
            endwhile

            if start_line == 0
                " sections and tasks with no "@ Start" line
                let start_line = line('.')
            endif

            if start_line > 0
                if task.total_minutes > 0
                    let time = quicktask#time#FormatTime(task.minutes)
                    let total_time = quicktask#time#FormatTime(task.total_minutes)
                    call append(start_line, physical_indent."@ Time [" . total_time . "]")
                endif
            endif

        endfor
    finally
        call winrestview(winview)
    endtry
endfunction

" Update task times for task on current line (including all super- and
" sub-tasks)
function! quicktask#time#UpdateTaskTime(line) abort
    let savepos = getcurpos()
    call cursor(a:line, 0)
    let top = quicktask#utils#FindTaskTopParent()
    let tasks = quicktask#parse#QTParseTask(top)
    call quicktask#time#UpdateTasksTime([tasks])
    call setpos('.', savepos)
endfunction

" ============================================================================
" UpdateAllTaskTimes(): Update times for all tasks in the buffer. {{{1
function! quicktask#time#UpdateAllTaskTimes() abort
    " Get top-level tasks/sections
    " Notice "-1" third argument to range(): we must iterate backwards or add
    " '@ Time' lines will change line numbers of next top-level tasks
    let top_level_tasks = quicktask#utils#TopLevelTasks()
    for task in top_level_tasks
        call quicktask#time#UpdateTaskTime(task)
    endfor
endfunction
