filetype plugin indent on
let s:suite = themis#suite('QuickTask Utils')
let s:assert = themis#helper('assert')

" This runs before every single test function
function! s:suite.before_each()
  " disable @ Added just to make it easier to assert matches without
  " considering date
  setlocal foldlevel=99
  let g:quicktask_task_insert_added = 0
  enew! " Create a new empty buffer
  setlocal filetype=quicktask
  call setline(1, [
        \ 'CURRENT TASKS:',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]'
        \ ])
endfunction

function! s:suite.test_mark_task_done()
  call cursor(2, 1)
  let today = quicktask#utils#GetDatestamp('today')
  call quicktask#utils#TaskComplete()
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  @ Time [01:01]',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ DONE '..today,
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]',
        \ '    @ Time [01:01]'
        \ ]
    call s:assert.equals(getline(1, '$'), expected)
endfunction

function! s:suite.test_add_task_above()
  call cursor(2, 1) " Move to line 2
  call quicktask#utils#AddTaskAbove()
  execute "normal! aAdded above\<Esc>"

  " Expect
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  - Added above',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]'
        \ ]
  call s:assert.equals(getline(1, '$'), expected)
endfunction

function! s:suite.test_add_task_below()
  call cursor(2, 1)
  call quicktask#utils#AddTaskBelow()
  execute "normal! aAdded below\<Esc>"

  " Expect
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '  - Added below',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]'
        \ ]
  call s:assert.equals(getline(1, '$'), expected)
endfunction

function! s:suite.test_add_note_to_task()
  call cursor(2, 1)
  call quicktask#utils#AddNoteToTask()
  execute "normal! aThis is a note\<Esc>"

  " Expect
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  - My first task.',
        \ '    * This is a note',
        \ '    @ Added [Fri 2026-02-13]',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]'
        \ ]
  call s:assert.equals(getline(1, '$'), expected)
endfunction

function! s:suite.add_child_test()
  call cursor(6, 1) " move to Second task
  call quicktask#utils#AddChildTask()
  execute "normal! aFirst child\<Esc>k"
  call quicktask#utils#AddChildTask()
  execute "normal! aSecond child\<Esc>"

  " Expect
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]',
        \ '    - First child',
        \ '    - Second child',
        \ ]
  call s:assert.equals(getline(1, '$'), expected)
endfunction

function! s:suite.test_indent_task()
  call cursor(6, 1) " Move to 'Second task'
  call quicktask#utils#IndentTask()

  " Expect
  let line_content = getline(5)
  call s:assert.match(line_content, '^    - Second task$')
  let line_content = getline(6)
  call s:assert.match(line_content, '^      @ Added \[Fri 2026-02-13\]$')
endfunction

function! s:suite.test_outdent_task()
  call cursor(6, 1) " Move to 'Second task'
  call quicktask#utils#OutdentTask()

  " Expect
  let line_content = getline(5)
  call s:assert.match(line_content, '^- Second task$')
  let line_content = getline(6)
  call s:assert.match(line_content, '^  @ Added \[Fri 2026-02-13\]$')
endfunction

function! s:suite.test_update_task_times()
  call quicktask#time#UpdateAllTaskTimes()

  " Expect
  let expected = [
        \ 'CURRENT TASKS:',
        \ '  @ Time [01:01]',
        \ '  - My first task.',
        \ '    @ Added [Fri 2026-02-13]',
        \ '',
        \ '  - Second task',
        \ '    @ Added [Fri 2026-02-13]',
        \ '    @ Start [Fri 2026-02-13] [15:32], end [16:33]',
        \ '    @ Time [01:01]'
        \ ]
  call s:assert.equals(getline(1, '$'), expected)
endfunction
