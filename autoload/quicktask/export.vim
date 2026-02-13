" ============================================================================
" OpenSplit(): Open a new buffer and populate it with data {{{1
" 
" data - list of lines to display
" filetype - the filetype to set for the new buffer
function! quicktask#export#OpenSplit(data, filetype)
    vnew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    let &l:filetype=a:filetype
    call setline(1, a:data)
endfunction

" ============================================================================
" QuoteCSV() Quote a string for CSV output {{{1
function! quicktask#export#QuoteCSV(str)
    if a:str =~ '["\n,]'
        return '"' . substitute(a:str, '"', '""', 'g') . '"'
    endif
    return a:str
endfunction

" ============================================================================
" function! NodeToTimeCSV(): Convert node to list of timesheet fields {{{1
"
" Converts a parsed task node to a list of fields for a timesheet row.
function! quicktask#export#NodeToTimeCSV(task)
    let rows = []
    for time in a:task.times
        let date = time[0]
        let start = time[1]
        let end = time[2]
        let start_epoch = strptime("%H:%M", start)

        let time = ""
        if !empty(end)
            let end_epoch = strptime("%H:%M", end)
            if end_epoch < start_epoch
                " end time is earlier than start time
                " assume it's the next day and add 24 hours
                let end_epoch = end_epoch + 86400
            endif
            let elapsed = (end_epoch - start_epoch) / 60
            let time = quicktask#time#FormatTime(elapsed)
        endif

        let task_name = matchlist(a:task.task, '\v^\s*- (.*)$')
        if len(task_name) > 1
            let task_name = task_name[1]
        endif
        let task_name = quicktask#export#QuoteCSV(task_name)
        let notes = join(a:task.notes, "\n")
        let notes = quicktask#export#QuoteCSV(notes)

        " get section hiearchy
        let section = ""
        let sect_list = a:task.sections
        let sect_hiearchy = join(sect_list, ">")
        if !empty(sect_list)
            let section = sect_list[-1]
        endif

        let row = [date, task_name, section, sect_hiearchy, start, end, time, notes]
        let rows += [join(row, ',')]
    endfor
    if !empty(rows)
        return join(rows, "\n").."\n"
    endif
    return ""
endfunction

" ============================================================================
" NodeToMarkdown(): Convert node to markdown format {{{1
" 
" Sections become headings, notes become paragraphs, snips are inserted
" verbatim.
function! quicktask#export#NodeToMarkdown(task)
    let str = ""
    if a:task.is_section
        let str .= repeat("#", a:task.depth) .. " " .. a:task.sections[-1]
        let str .= "\n\n"
    endif

    for snip in a:task.snips
        " read snip file
        let contents = readfile(g:quicktask_snip_path .. snip) 
        let str .= join(contents, "\n") .. "\n\n"
        " strip out # vim: lines
        let str = substitute(str, '# vim:.*$', '', 'g')
    endfor

    for note in a:task.notes
        let str .= note .. "\n\n"
    endfor
    
    return str
endfunction

" ============================================================================
" NodeToAsciidoc(): Convert node to asciidoc format {{{1
" 
" Sections become headings, notes become paragraphs, snips are inserted
" verbatim.
function! quicktask#export#NodeToAsciidoc(task)
    let str = ""
    if a:task.is_section
        let str .= repeat("=", a:task.depth) .. " " .. a:task.sections[-1]
        let str .= "\n\n"
    endif

    if !empty(a:task.snips) && quicktask#snip#CheckSnipsReadiness()
        for snip in a:task.snips
            " read snip file
            let contents = readfile(g:quicktask_snip_path .. snip) 
            let str .= join(contents, "\n") .. "\n\n"
            " strip out # vim: lines
            let str = substitute(str, '# vim:.*$', '', 'g')
        endfor
    endif

    for note in a:task.notes
        let str .= note .. "\n\n"
    endfor
    
    return str
endfunction

" ============================================================================
" NodeToHTML(): Convert node to HTML format {{{1
" 
" Sections become headings, notes become paragraphs, snips are inserted
" verbatim.
function! quicktask#export#NodeToHTML(task)
    let str = ""
    if a:task.is_section
        let str .= "<h"..a:task.depth..">"..a:task.sections[-1].."</h"..a:task.depth..">"
        let str .= "\n\n"
    endif

    for snip in a:task.snips
        " read snip file
        let contents = readfile(g:quicktask_snip_path .. snip) 
        let str .= join(contents, "\n") .. "\n\n"
        " strip out # vim: lines
        let str = substitute(str, '# vim:.*$', '', 'g')
    endfor

    for note in a:task.notes
        let str .= "<p>"..note.."</p>\n\n"
    endfor
    
    return str
endfunction
"
" ============================================================================
" NodeToAST(): Convert node to text for debugging {{{1
function! quicktask#export#NodeToAST(task)
    let spaces = repeat(" ", a:task.depth*2)
    let str = ""
    let str .= a:task.task .. "\n"
    let str .= spaces .. "is_section: " .. a:task.is_section .. "\n"
    let str .= spaces .. "depth: " .. a:task.depth .. "\n"
    let str .= spaces .. "sections: " .. join(a:task.sections, ",") .. "\n"
    let str .= spaces .. "snips: " .. join(a:task.snips, ",") .. "\n"
    let str .= spaces .. "times: " .. join(a:task.times, ",") .. "\n"
    let str .= spaces .. "notes: [" .. join(a:task.notes, ",") .. "]\n"
    let str .= spaces .. "children: " .. len(a:task.children) .. "\n"
    let str .= "\n"

    return str
endfunction

" ============================================================================
" BufferToCSV(): Export current buffer to CSV format {{{1
" 
" Exports all tasks in the current buffer to a CSV format suitable for
" importing into a timesheet or spreadsheet. Opens CSV in a split window.
function! quicktask#export#BufferToCSV()
    let header = "date,task,project,project_hierarchy,start,end,time,notes\n"
    let csv = QTExportBuffer(function('quicktask#export#NodeToTimeCSV'))
    let lines = header .. csv
    call quicktask#export#OpenSplit(split(lines, "\n"), "csv")
endfunction

function! quicktask#export#BufferToMarkdown()
    let str = QTExportBuffer(function('quicktask#export#NodeToMarkdown'))
    call quicktask#export#OpenSplit(split(str, "\n"), "markdown")
endfunction

function! quicktask#export#BufferToAsciidoc()
    let str = QTExportBuffer(function('quicktask#export#NodeToAsciidoc'))
    call quicktask#export#OpenSplit(split(str, "\n"), "asciidoc")
endfunction

function! quicktask#export#BufferToHTML()
    let str = QTExportBuffer(function('quicktask#export#NodeToHTML'))
    call quicktask#export#OpenSplit(split(str, "\n"), "html")
endfunction

function! quicktask#export#BufferToAST()
    let str = QTExportBuffer(function('quicktask#export#NodeToAST'))
    call quicktask#export#OpenSplit(split(str, "\n"), "html")
endfunction
