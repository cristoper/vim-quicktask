filetype plugin indent on
let s:suite = themis#suite('QuickTask Movement')
let s:assert = themis#helper('assert')
let s:test_dir = expand('<sfile>:p:h')
let s:test_file = s:test_dir.."/test.qt"

let s:task_lines = [3,5,11,16,17,21,25,28]


" This runs before every single test function
function! s:suite.before_each()
  enew! " Create a new empty buffer
  setlocal filetype=quicktask
  setlocal foldlevel=99
  call setline(1, readfile(s:test_file))
endfunction

" Test movement functions
function! s:suite.test_move_to_next_section()
  let heading1 = search('Heading 1:', 'nW')
  let child_section = search('Child Section:', 'nW')
  let completed_tasks = search('COMPLETED TASKS:', 'nW')

  call cursor(1, 1)
  call quicktask#move#MoveToNextSection(1)
  call s:assert.equals(line('.'), heading1)
  
  call quicktask#move#MoveToNextSection(1)
  call s:assert.equals(line('.'), child_section)
  
  call quicktask#move#MoveToNextSection(1)
  call s:assert.equals(line('.'), completed_tasks)

  " Try to move beyond last section
  call quicktask#move#MoveToNextSection(1)
  call s:assert.equals(line('.'), completed_tasks) 
endfunction

function! s:suite.test_move_to_prev_section()
  let heading1 = search('Heading 1:', 'nW')
  let child_section = search('Child Section:', 'nW')
  let completed_tasks = search('COMPLETED TASKS:', 'nW')

  call cursor('$', 1)
  call quicktask#move#MoveToPrevSection(1)
  call s:assert.equals(line('.'), completed_tasks)
  
  call quicktask#move#MoveToPrevSection(1)
  call s:assert.equals(line('.'), child_section)
  
  call quicktask#move#MoveToPrevSection(1)
  call s:assert.equals(line('.'), heading1)
  
  " Try to move beyond first section
  call quicktask#move#MoveToPrevSection(1)
  call s:assert.equals(line('.'), heading1)
endfunction

function! s:suite.test_move_to_next_task()
  " Move to "Child Section" then check that MoveToNextTask() goes to child
  " task and then sibling task
  call cursor(1,1)

  for line in s:task_lines
    call quicktask#move#MoveToNextTask(1)
    call s:assert.equals(line('.'), line)
  endfor
  
  " Try to move beyond last task
  call quicktask#move#MoveToNextTask(1)
  call s:assert.equals(line('.'), 28) " Should stay at last section
endfunction

function! s:suite.test_move_to_prev_task()
  " Move to last task then check that MoveToPrevTask() goes to sibling task
  " and then child task
  call cursor('$', 1)
  let task_lines = copy(s:task_lines)
  let task_lines = reverse(task_lines)
  
  for line in task_lines
    call quicktask#move#MoveToPrevTask(1)
    call s:assert.equals(line('.'), line)
  endfor
endfunction

function! s:suite.test_move_to_first_sibling()
  " Move to a child task (line 7)
  call cursor(12, 1)
  call quicktask#move#MoveToFirstSibling()
  call s:assert.equals(line('.'), 5) " Should move to first sibling (child task)
  
  " Calling again should not move
  call quicktask#move#MoveToFirstSibling()
  call s:assert.equals(line('.'), 5) " Should stay at same line
endfunction

function! s:suite.test_move_to_last_sibling()
  " Move to a child task (line 7)
  call cursor(12, 1)
  call quicktask#move#MoveToLastSibling()
  call s:assert.equals(line('.'), 25)
  
  " Calling again should not move
  call quicktask#move#MoveToLastSibling()
  call s:assert.equals(line('.'), 25) " Should stay at same line
endfunction

function! s:suite.test_move_to_prev_sibling()
  " Move to child task (line 7)
  call cursor(12, 1)
  call quicktask#move#MoveToPrevSibling()
  call s:assert.equals(line('.'), 5)
  
  " Calling again should move to parent
  call quicktask#move#MoveToPrevSibling()
  call s:assert.equals(line('.'), 3)
endfunction

function! s:suite.test_move_to_next_sibling()
  call cursor(12, 1)
  call quicktask#move#MoveToNextSibling()
  call s:assert.equals(line('.'), 25)
  
  " Try to move next when no next sibling exists
  call quicktask#move#MoveToNextSibling()
  call s:assert.equals(line('.'), 25) " Should move to child task
endfunction

function! s:suite.test_move_to_parent_task()
  call cursor(16, 1)  "Child Section:"
  call quicktask#move#MoveToParentTask()
  call s:assert.equals(line('.'), 11)
  
  " Try to move to parent when no parent exists
  call cursor(3, 1)
  call quicktask#move#MoveToParentTask()
  call s:assert.equals(line('.'), 3) " Should stay at same line
endfunction

function! s:suite.test_move_to_child_task()
  call cursor(16, 1)
  call quicktask#move#MoveToChildTask()
  call s:assert.equals(line('.'), 17) " Should move to first child
  
  " Try to move to child when no children exist
  call quicktask#move#MoveToChildTask()
  call s:assert.equals(line('.'), 17) " Should stay at same line
endfunction

"
" Test operator pending functions
"
function! s:suite.test_select_task()
  " Test SelectTask with blanks (should select task including blank lines)
  call cursor(17, 1)
  call quicktask#utils#SelectTask(v:false)
  
  " Verify we're in visual mode and selected the right area
  let mode = mode()
  let start = line('v')
  let end = line('.')
  call s:assert.equals(mode, 'V')
  call s:assert.equals(start, 17)
  call s:assert.equals(end, 20)
endfunction

function! s:suite.test_select_no_blanks_task()
  " Test SelectTask with blanks (should select task excluding blank lines)
  call cursor(17, 1)
  call quicktask#utils#SelectTask(v:true)
  
  " Verify we're in visual mode and selected the right area
  let mode = mode()
  let start = line('v')
  let end = line('.')
  call s:assert.equals(mode, 'V')
  call s:assert.equals(start, 17)
  call s:assert.equals(end, 19)
endfunction

" Test movement mappings
function! s:suite.test_move_to_next_section_map()
  let heading1 = search('Heading 1:', 'nW')
  let child_section = search('Child Section:', 'nW')
  let completed_tasks = search('COMPLETED TASKS:', 'nW')

  call cursor(1, 1)
  normal ]s
  call s:assert.equals(line('.'), heading1)
  
  normal ]s
  call s:assert.equals(line('.'), child_section)
  
  normal ]s
  call s:assert.equals(line('.'), completed_tasks)

  " Try to move beyond last section
  normal ]s
  call s:assert.equals(line('.'), completed_tasks) 
endfunction

function! s:suite.test_move_to_prev_section_map()
  let heading1 = search('Heading 1:', 'nW')
  let child_section = search('Child Section:', 'nW')
  let completed_tasks = search('COMPLETED TASKS:', 'nW')

  call cursor('$', 1)
  normal [s
  call s:assert.equals(line('.'), completed_tasks)
  
  normal [s
  call s:assert.equals(line('.'), child_section)
  
  normal [s
  call s:assert.equals(line('.'), heading1)
  
  " Try to move beyond first section
  normal [s
  call s:assert.equals(line('.'), heading1)
endfunction
"
" Test movement mappings with <C-k> and <C-j>
function! s:suite.test_move_to_next_task_map()
  call cursor(1,1)

  for line in s:task_lines
    normal ]]
    call s:assert.equals(line('.'), line)
  endfor
  
  " Try to move beyond last task
  normal ]]
  call s:assert.equals(line('.'), 28) " Should stay at last section
endfunction

function! s:suite.test_move_to_prev_task_map()
  call cursor('$', 1)
  let task_lines = copy(s:task_lines)
  let task_lines = reverse(task_lines)
  
  for line in task_lines
    normal [[
    call s:assert.equals(line('.'), line)
  endfor
endfunction

function! s:suite.test_move_to_next_sibling_map()
   call cursor(1,1) 
   execute "normal \<C-j>"
   call s:assert.equals(line('.'), 3)
   execute "normal \<C-j>"
   call s:assert.equals(line('.'), 28)
   execute "normal \<C-j>"
   call s:assert.equals(line('.'), 28)
endfunction

function! s:suite.test_move_to_prev_sibling_map()
   call cursor('$',1) 
   execute "normal \<C-k>"
   call s:assert.equals(line('.'), 28)
   execute "normal \<C-k>"
   call s:assert.equals(line('.'), 3)
   execute "normal \<C-k>"
   call s:assert.equals(line('.'), 3)
endfunction
