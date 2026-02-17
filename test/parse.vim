filetype plugin indent on
let s:suite = themis#suite('QuickTask Parser')
let s:assert = themis#helper('assert')
let s:test_dir = expand('<sfile>:p:h')
let s:test_file = s:test_dir.."/test.qt"


" This runs before every single test function
function! s:suite.before_each()
  enew! " Create a new empty buffer
  setlocal filetype=quicktask
  call setline(1, readfile(s:test_file))
endfunction

function! s:suite.test_ast()
  let actual = QTExportBuffer(function('quicktask#export#NodeToAST'))
  let l:expected = join(readfile(s:test_dir.."/expected_ast.txt"), "\n").."\n"
  call s:assert.equals(l:actual, l:expected)
endfunction

function! s:suite.test_md()
  let actual = QTExportBuffer(function('quicktask#export#NodeToMarkdown'))
  let l:expected = join(readfile(s:test_dir.."/expected_md.md"), "\n").."\n"
  call s:assert.equals(l:actual, l:expected)
endfunction

function! s:suite.test_csv()
  let header = "date,task,project,project_hierarchy,start,end,time,notes\n"
  let actual = QTExportBuffer(function('quicktask#export#NodeToTimeCSV'))
  let actual = header .. actual
  let l:expected = join(readfile(s:test_dir.."/expected_csv.csv"), "\n").."\n"
  call s:assert.equals(l:actual, l:expected)
endfunction

function! s:suite.test_adoc()
  let actual = QTExportBuffer(function('quicktask#export#NodeToAsciidoc'))
  let l:expected = join(readfile(s:test_dir.."/expected_ad.ad"), "\n").."\n"
  call s:assert.equals(l:actual, l:expected)
endfunction

function! s:suite.test_html()
  let actual = QTExportBuffer(function('quicktask#export#NodeToHTML'))
  let l:expected = join(readfile(s:test_dir.."/expected_html.html"), "\n").."\n"
  call s:assert.equals(l:actual, l:expected)
endfunction
