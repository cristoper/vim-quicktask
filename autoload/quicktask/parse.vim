" quicktask.vim: A lightweight task management plugin.
" This file contains parser-related functions

" regex
let s:section_regex = '\v^\s*[^-].*:\s*$'
let s:task_or_section_regex = '\v^(\s{-}- |.*:\s*$)'

" ============================================================================
" QTParseTask(): Parse a task into a dictionary. {{{1
"
" line - a line number in the task to parse
"
" QTParseTask() also takes optional arguments which are used internally to
" track state during recursion. Public callers of QTParseTask() should only
" pass `line`. The optional arguments are:
"
" sections - a list of sections encountered so far
" depth - the current recursion depth
"
" Returns a dictionary of task data:
"    task = {
"        'task': <task text>,
"        'is_section': <true if current line is a section heading>,
"        'parent': <reference to parent node>,
"        'depth': <recursion depth>,
"        'sections': [<section1>, <section2>, ...],
"        'line': <line number>,
"        'end_line': <line number of last line of task>,
"        'project': <project text>,
"        'added': <date added>,
"        'times': [[<date>. <start time>, <end time>], ...],
"        'minutes': <total minutes>,       " sum of Start,end times
"        'total_minutes': <total minutes>,  " including children's minutes
"        'has_open_time': <true if there is an open time>,
"        'notes': [<note text>, ...],
"        'children': [<task>, ...],   " empty unless recursive is true
"        'snips': [<snip name>, ...],
"        'complete': <date completed>, " empty if not DONE
"    }
function! quicktask#parse#QTParseTask(line, ...)
    let save_cursor = getcurpos()
    call cursor(a:line, 0)
    let start_line = quicktask#utils#FindTaskStart(1)
    let end_line = quicktask#utils#FindTaskEnd(0)
    let indent = quicktask#utils#GetTaskIndent()
    let curline = getline(start_line)
    let is_section = curline =~ s:section_regex

    if a:0 > 0
        let sections = copy(a:1)
    else
        let sections = []
    endif

    if a:0 > 1
        let depth = a:2
    else
        let depth = 1
    endif

    let task = getline(start_line)

    if is_section
        let label = matchstr(task, '\S.*[^:]') 
        let sections += [label]
    endif

    let task = {
        \ 'task': task,
        \ 'is_section': is_section,
        \ 'parent': {},
        \ 'depth': depth,
        \ 'sections': sections,
        \ 'line': start_line,
        \ 'end_line': end_line,
        \ 'task_indent': indent,
        \ 'added': '',
        \ 'times': [],
        \ 'minutes': 0,
        \ 'total_minutes': 0,
        \ 'has_open_time': 0,
        \ 'notes': [],
        \ 'children': [],
        \ 'snips': [],
        \ 'complete': '',
        \ }
    let minutes = 0

    " parse line-by-line
    let current_line = start_line + 1
    while current_line <= end_line
        let line = getline(current_line)
        let cur_indent = quicktask#utils#GetAnyIndent(current_line)

        if line =~ '^\s*$'
            " skip blank lines
            let current_line = current_line + 1
            continue
        endif

        if cur_indent < indent
            " we have reached the end of the task
            " or are processing a malformed task
            call quicktask#utils#EchoWarning("Reached unexpected end of task at line ".current_line)
            return task
        endif

        if line =~ s:task_or_section_regex && cur_indent > indent
            " this line is the start of a child task
            let subtask = quicktask#parse#QTParseTask(current_line, sections, depth+1)
            let subtask.parent = task
            let task.children += [subtask]

            " skip down to the next line at our indent level
            call cursor(current_line, 0)
            let next_sibling = quicktask#utils#FindNextSibling()
            let current_line = next_sibling ? next_sibling : end_line+1
            continue
        endif

        let added_line = matchlist(line, '\v^\s*\@ Added \[(.*)\]')
        if !empty(added_line)
            let task.added = added_line[1]
            let current_line = current_line + 1
            continue
        endif

        let start_regex = '\v^\s*\@ Start \[(.{-})\] \[(.{-})\]%(, end \[(.{-})\])?'
        let startline = matchlist(line, start_regex)
        if !empty(startline)
            let time_date = startline[1]
            let start_time = startline[2]
            let end_time = startline[3]
            let task.times += [[time_date, start_time, end_time]]
            if end_time == ''
                let task.has_open_time = 1
            else
                " calculate minutes from start and end times
                let start_epoch = strptime("%H:%M", start_time)
                let end_epoch = strptime("%H:%M", end_time)
                if end_epoch < start_epoch
                    " end time is earlier than start time
                    " assume it's the next day and add 24 hours
                    let end_epoch = end_epoch + 86400
                endif
                let elapsed = (end_epoch - start_epoch) / 60
                let minutes += elapsed
            endif
            let current_line = current_line + 1
            continue
        endif

        let note_line = matchlist(line, '\v^\s*\* (.*)$')
        if !empty(note_line)
            " save cursor
            let save_cursor = getcurpos()
            call cursor(current_line, 0)

            let note = note_line[1]
            " To support multi-line notes, treat this line and all lines to
            " the next line with a recognized prefix as part of this note
            let note_end = search('\v^(\S|\s*(-|\*|\@|\$))', 'nW')
            call setpos('.', save_cursor)

            if note_end == 0
                let note_end = line('$')+1
            endif
            let note_end -= 1 " don't include non-note next line

            if note_end > current_line
                " we have a multi-line note
                " need to remove cur_indent from each line
                let note_multilines = getline(current_line+1, note_end)
                for line in note_multilines
                    let line = substitute(line, '^\s\{'.cur_indent.'}', '', '')
                    let note .= "\n" .. line
                endfor
            endif

            let task.notes += [note]
            let current_line = note_end + 1
            continue
        endif

        let snip_line = matchlist(line, '\v^\s*\$ (.*)$')
        if !empty(snip_line)
            let task.snips += [snip_line[1]]
            let current_line = current_line + 1
            continue
        endif

        let complete_line = matchlist(line, '\v^\s*\@ DONE \[(.*)\]')
        if !empty(complete_line)
            let task.complete = complete_line[1]
            let current_line = current_line + 1
            continue
        endif

        let time_line = matchlist(line, '\v^\s*\@ Time')
        if !empty(time_line)
            " skip Time lines
            let current_line = current_line + 1
            continue
        endif

        " We didn't match a known line type
        call quicktask#utils#EchoWarning("Skipping unknown line type: ".current_line)
        let current_line = current_line + 1
    endwhile

    " Add total_minutes of direct children to our minutes
    " (Needs to include only DIRECT children or some minutes will be double counted)
    let total_minutes = minutes
    let task.minutes = minutes
    for child in task.children
        let total_minutes += child.total_minutes
    endfor
    let task.total_minutes = total_minutes

    call setpos('.', save_cursor)
    return task
endfunction

" ============================================================================
" FindTaskAtLine(): Recurses tree to find task {{{1
"
" depth-first search for task that starts on specified line-number. This can
" be useful to find a specific task in a parsed tree of the buffer.
" tree - a list of tasks (from QTParseTask())
" line - a line number to find
function! quicktask#parse#FindTaskAtLine(tree, line)
    if a:tree == v:null || !has_key(a:tree, 'children')
        return {}
    endif

    if a:line == a:tree.line
        return a:tree
    endif

    for child in a:tree.children
        let found = quicktask#utils#FindTaskAtLine(child, a:line)
        if !empty(found)
            return found
        endif
    endfor
    return {}
endfunction

" ============================================================================
" WalkTreeDF(node, callback): Depth-first traversal the tree rooted in node
" {{{1
function! quicktask#parse#WalkTreeDF(node, callback)
    call call(a:callback, [a:node])
    for child in a:node.children
        call quicktask#parse#WalkTreeDF(child, a:callback)
    endfor
endfunction

