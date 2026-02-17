let s:task_or_section_regex = '\v^(\s{-}- |.*:\s*$)'
let s:section_regex = '\v^\s*[^-].*:\s*$'

" ============================================================================
" MovePrevSibling(): Move to the previous sibling task. {{{1
"
" If task has no previous sibling, then move to parent.
function! quicktask#move#MoveToPrevSibling() abort
    let prev_sibling = quicktask#utils#FindPrevSibling()
    if prev_sibling == 0
        call quicktask#move#MoveToParentTask()
        return
    endif
    call cursor(prev_sibling, 0)
endfunction

" ============================================================================
" MoveNextSibling(): Move to the next sibling task. {{{1
"
" If task has no next sibling, move to next child if any
function! quicktask#move#MoveToNextSibling() abort
    let next_sibling = quicktask#utils#FindNextSibling()
    if next_sibling == 0
        call quicktask#move#MoveToChildTask()
        return
    endif
    call cursor(next_sibling, 0)
endfunction

" ============================================================================
" MoveToParent(): Move to the parent task. {{{1
function! quicktask#move#MoveToParentTask() abort
    let parent_line = quicktask#utils#FindTaskParent()
    if parent_line == 0
        call quicktask#utils#EchoWarning("No parent task found")
        return
    endif
    call cursor(parent_line, 0)
endfunction

" ============================================================================
" MoveToChild(): Move to the first child task. {{{1
function! quicktask#move#MoveToChildTask() abort
    let task_start = quicktask#utils#FindTaskStart(0)
    let task = quicktask#parse#QTParseTask(task_start)
    if !empty(task.children)
        let first_child_line = task.children[0].line
        call cursor(first_child_line, 0)
        return
    endif
    call quicktask#utils#EchoWarning("No child task found")
endfunction

" ===========================================================================
" MoveToPrevTask(): Move to the previous task. {{{1
 function! quicktask#move#MoveToPrevTask(count) abort
     " If we're on a blank or comment line, move directly to the task above us
     " in the buffer
     let cur_line = getline('.')
     if cur_line =~ '^[#$]'
         call search(s:task_or_section_regex, 'bW')
         return
     endif

     for _ in range(a:count)
         call quicktask#utils#FindTaskStart(1)
         let prev = search(s:task_or_section_regex, 'bW')
         if prev == 0
             call quicktask#utils#EchoWarning("No previous task found")
             return
         endif
         call cursor(prev, 0)
     endfor
 endfunction

 " ===========================================================================
 " MoveToNextTask(): Move to the next task. {{{1
 function! quicktask#move#MoveToNextTask(count) abort
     let next = 0
     for _ in range(a:count)
         let next_task = search(s:task_or_section_regex, 'W')
         if next_task == 0
             break
         endif
         let next = next_task
     endfor
     if next == 0
         call quicktask#utils#EchoWarning("No next task found")
     else
         echom next
         call cursor(next, 0)
     endif
 endfunction

 " ===========================================================================
 " MoveToFirstSibling(): Move to the first sibling of the current task. {{{1
 function! quicktask#move#MoveToFirstSibling() abort
     let task_line = quicktask#utils#FindTaskStart(0)
     if task_line == 0
         return
     endif

     let parent = quicktask#utils#FindTaskParent()
     if parent == 0
         return
     endif

     let node = quicktask#parse#QTParseTask(parent)
     if empty(node.children)
         call quicktask#utils#EchoWarning("No sibling task found")
         return
     endif
     let first_sibling = node.children[0].line
     call cursor(first_sibling, 0)
 endfunction

 " ===========================================================================
 " MoveToLastSibling(): Move to the last sibling of the current task. {{{1
 function! quicktask#move#MoveToLastSibling() abort
     let task_line = quicktask#utils#FindTaskStart(0)
     if task_line == 0
         return
     endif

     let parent = quicktask#utils#FindTaskParent()
     if parent == 0
         return
     endif

     let node = quicktask#parse#QTParseTask(parent)
     if empty(node.children)
         call quicktask#utils#EchoWarning("No sibling task found")
         return
     endif
     let last_sibling = node.children[-1].line
     call cursor(last_sibling, 0)
 endfunction

 " ===========================================================================
 " MoveToNextSection(): Move to the next section heading. {{{1
 function! quicktask#move#MoveToNextSection(count) abort
     for _ in range(a:count)
         let next_section = search(s:section_regex, 'W')
         if next_section == 0
             call quicktask#utils#EchoWarning("No next section heading found")
             return
         endif
     endfor
 endfunction

 " ===========================================================================
 " MoveToPrevSection(): Move to the previous section heading. {{{1
 function! quicktask#move#MoveToPrevSection(count) abort
     for _ in range(a:count)
         let prev = search(s:section_regex, 'bW')
         if prev == 0
             call quicktask#utils#EchoWarning("No previous section heading found")
             return
         endif
     endfor
 endfunction
