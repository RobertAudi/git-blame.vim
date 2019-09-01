let s:default_values = {
      \   'enable_root_rev_parse': 1,
      \   'mappings': {
      \     'previewCommit': 'p',
      \     'nextCommit': 'd',
      \     'parentCommit': 'u',
      \     'close': 'q',
      \   }
      \ }

let s:default_line_numbers = -1

" Utility functions {{{
" ----------------------------------------------------------------------------

" Display an error message.
function! s:Error(msg) abort
  echohl
  echon a:msg
  echohl NONE
endfunction

" Set the line numbers options for the gitblame buffers
function! s:setLineNumbers() abort
  let l:line_numbers = get(g:, 'gitblame_line_numbers', s:default_line_numbers)

  if l:line_numbers == 0
    setlocal nonumber norelativenumber
  elseif l:line_numbers == 1
    setlocal number norelativenumber
  elseif l:line_numbers == 2
    setlocal nonumber relativenumber
  elseif l:line_numbers == -1
    setlocal number< relativenumber<
  else
    call s:Error("Invalid value for 'g:gitblame_line_numbers': " . string(l:line_numbers))

    setlocal number< relativenumber<
  endif
endfunction

function! s:system(cmd) abort
  let l:output = system(a:cmd)

  if v:shell_error && l:output !=# ''
    call s:Error(l:output)

    return ''
  endif

  return l:output
endfunction

" Execute command and show the result by options:
"
"   `option.edit`      edit command used for open result buffer
"   `option.pipe`      pipe current buffer to command
"   `option.title`     required title for the new tmp buffer
"   `option.nokeep`    if 1, not keepalt
"
function! s:execute(cmd, option) abort
  let l:edit = get(a:option, 'edit', 'edit')
  let l:pipe = get(a:option, 'pipe', 0)
  let l:bnr = bufnr('%')

  if l:edit ==# 'pedit'
    let l:edit = 'new +setlocal\ previewwindow'
  endif

  if l:edit !~# 'keepalt' && !get(a:option, 'nokeep', 0)
    let l:edit = 'keepalt ' . l:edit
  endif

  if l:pipe
    let l:stdin = join(getline(1, '$'),"\n")
    let l:output = system(a:cmd, l:stdin)
  else
    let l:output = system(a:cmd)
  endif

  if v:shell_error && l:output !=# ''
    call s:Error(l:output)

    return -1
  endif

  execute l:edit . ' ' . a:option.title
  execute 'nnoremap <buffer> <nowait> <silent> ' . s:getKeyForMapping('close') . ' :call <SID>SmartQuit("' . l:edit . '")<CR>'

  let b:gitblame_prebufnr = l:bnr
  let l:list = split(l:output, '\v\r?\n')

  if len(l:list)
    setlocal noreadonly modifiable

    call setline(1, l:list[0])
    silent! call append(1, l:list[1:])
  endif

  setlocal buftype=nofile readonly nomodifiable bufhidden=wipe
  call s:setLineNumbers()
endfunction

function! s:sub(str, pat, rep) abort
  return substitute(a:str, '\v\C' . a:pat, a:rep, '')
endfunction

function! s:getKeyForMapping(action) abort
  if !has_key(s:default_values.mappings, a:action)
    throw 'Unknow git blame action: ' . a:action
  endif

  let l:key_mappings = get(g:, 'gitblame_mappings', s:default_values.mappings)
  let l:key = get(l:key_mappings, a:action, s:default_values.mappings[a:action])

  return l:key
endfunction

" ---------------------------------------------------------------------------- }}}

function! s:FindGitdir(path) abort
  let l:path = resolve(fnamemodify(a:path , ':p'))

  if !empty($GIT_DIR)
    let l:gitdir = $GIT_DIR
  elseif get(g:, 'gitblame_enable_root_rev_parse', s:default_values['enable_root_rev_parse'])
    let l:old_cwd = getcwd()
    let l:cwd = fnamemodify(l:path, ':p:h')

    execute 'lcd ' . l:cwd

    let l:root = system('git rev-parse --show-toplevel')

    execute 'lcd ' . l:old_cwd

    if v:shell_error
      let l:gitdir = ''
    else
      let l:gitdir = substitute(l:root, '\r\?\n', '', '') . '/.git'
    endif
  else
    let l:dir = finddir('.git', expand(l:path) . ';')

    if empty(l:dir)
      let l:gitdir = ''
    else
      let l:gitdir = fnamemodify(l:dir, ':p:h')
    endif
  endif

  if empty(l:gitdir)
    call s:Error('Git directory not found')
  endif

  return l:gitdir
endfunction

function! s:ShowNextCommit() abort
  let l:commit = matchstr(getline(1), '\v\s\zs.+$')
  let l:revisionRange = l:commit . '..master'
  let l:command = 'git --git-dir=' . b:gitdir . ' log --pretty=format:"%H"'
        \ . ' --reverse --ancestry-path ' . l:revisionRange . ' | head -n 1'
  let l:nextCommit = substitute(s:system(l:command), '\n', '', '')

  if empty(l:nextCommit)
    return
  endif

  call s:ShowCommit(l:nextCommit, {
        \   'edit': 'edit',
        \   'gitdir': b:gitdir,
        \   'all': 1,
        \ })
endfunction

function! s:ShowParentCommit() abort
  let l:commit = matchstr(getline(2), '\v\s\zs.+$')

  if empty(l:commit)
    return
  endif

  call s:ShowCommit(l:commit, {
        \   'edit': 'edit',
        \   'gitdir': b:gitdir,
        \   'all': 1,
        \ })
endfunction

function! s:findObject(args) abort
  if !len(a:args)
    return 'HEAD'
  endif

  let l:arr = split(a:args, '\v\s+')

  for l:str in l:arr
    if l:str !~# '\v^-'
      return l:str
    endif
  endfor

  return ''
endfunction

function! s:ShowRefFromBlame(bnr) abort
  let l:commit = matchstr(getline('.'), '^\^\=\zs\x\+')
  let l:gitdir = s:FindGitdir(bufname(a:bnr))

  if empty(l:gitdir)
    return
  endif

  let l:root = fnamemodify(l:gitdir, ':h')
  let l:option = {
        \   'edit': 'split',
        \   'gitdir': l:gitdir,
        \   'all' : 1,
        \ }

  call s:ShowCommit(l:commit, l:option)
endfunction

let s:hash_colors = {}
function! s:blameHighlight() abort
  let l:seen = {}

  for l:lnum in range(1, line('$'))
    let l:hash = matchstr(getline(l:lnum), '^\^\=\zs\x\{6\}')

    if l:hash ==# '' || l:hash ==# '000000' || has_key(l:seen, l:hash)
      continue
    endif

    let l:seen[l:hash] = 1
    let s:hash_colors[l:hash] = ''

    execute 'syntax match gitblameHash' . l:hash . ' "\%(^\^\=\)\@<=' . l:hash . '\x\{1,34\}\>" nextgroup=gitblameAnnotation,gitblameOriginalLineNumber,blameOriginalFile skipwhite'
  endfor

  call s:RehighlightBlame()
endfunction

function! s:RehighlightBlame() abort
  for [l:hash, l:cterm] in items(s:hash_colors)
    if !empty(l:cterm) || has('gui_running')
      execute 'highlight gitblameHash' . l:hash . ' guifg=#' . l:hash . get(s:hash_colors, l:hash, '')
    else
      execute 'highlight link gitblameHash' . l:hash . ' Identifier'
    endif
  endfor
endfunction

function! s:SmartQuit(edit) abort
  let l:bnr = get(b:, 'blame_bufnr', '')

  if a:edit =~# 'edit'
    try
      execute 'b ' . b:gitblame_prebufnr
    catch /.*/
      execute 'q'
    endtry
  else
    execute 'q'
  endif

  if !empty(l:bnr)
    call gitblame#blame()
  endif
endfunction

" If cwd inside current file git root, return cwd, otherwise return git root
function! s:SmartRoot() abort
  let l:gitdir = s:FindGitdir(expand('%'))

  if empty(l:gitdir)
    return ''
  endif

  let l:root = fnamemodify(l:gitdir, ':h')
  let l:cwd = getcwd()

  return l:cwd =~# '^' . l:root ? l:cwd : l:root
endfunction

function! s:FoldText() abort
  if &foldmethod !=# 'syntax'
    return foldtext()
  elseif getline(v:foldstart) =~# '^diff '
    let [l:add, l:remove] = [-1, -1]
    let l:filename = ''

    for l:lnum in range(v:foldstart, v:foldend)
      if l:filename ==# '' && getline(l:lnum) =~# '^[+-]\{3\} [abciow12]/'
        let l:filename = getline(l:lnum)[6:-1]
      endif

      if getline(l:lnum) =~# '^+'
        let l:add += 1
      elseif getline(l:lnum) =~# '^-'
        let l:remove += 1
      elseif getline(l:lnum) =~# '^Binary '
        let l:binary = 1
      endif
    endfor

    if l:filename ==# ''
      let l:filename = matchstr(getline(v:foldstart), '^diff .\{-\} a/\zs.*\ze b/')
    endif

    if l:filename ==# ''
      let l:filename = getline(v:foldstart)[5:-1]
    endif

    if exists('binary')
      return 'Binary: ' . l:filename
    else
      return (l:add < 10 && l:remove < 100 ? ' ' : '') . l:add . '+ '
            \ . (l:remove < 10 && l:add < 100 ? ' ' : '') . l:remove . '- ' . l:filename
    endif
  elseif getline(v:foldstart) =~# '^# .*:$'
    let l:lines = getline(v:foldstart, v:foldend)

    call filter(l:lines, 'v:val =~# "^#\t"')
    call map(l:lines, 's:sub(v:val, "^#\t%(fixed: +|add: +)=", "")')
    call map(l:lines, 's:sub(v:val, "^([[:alpha:] ]+): +(.*)", "\\2 (\\1)")')

    return getline(v:foldstart) . ' ' . join(l:lines, ', ')
  endif

  return foldtext()
endfunction

" Show the commit ref with `option.edit` and `option.all` using gitdir of current file
"
"   `option.file`      could contain the file for show
"   `option.fold`      if 0, open all folds
"   `option.all`       show all file changes
"   `option.gitdir`    could contain gitdir to work on
"
function! s:ShowCommit(args, option) abort
  let l:fold = get(a:option, 'fold', 1)
  let l:gitdir = get(a:option, 'gitdir', '')

  if empty(l:gitdir)
    let l:gitdir = s:FindGitdir(expand('%'))
  endif

  if empty(l:gitdir)
    return
  endif

  let l:showall = get(a:option, 'all', 0)
  let l:format = "--pretty=format:'commit %H%nparent %P%nauthor %an <%ae> %ad%ncommitter %cn <%ce> %cd%n %e%n%n%s%n%n%b' "

  if l:showall
    let l:command = 'git --no-pager' . ' --git-dir=' . l:gitdir . ' show  --no-color ' . l:format . a:args
  else
    let l:root = fnamemodify(l:gitdir, ':h')
    let l:file = get(a:option, 'file', substitute(expand('%:p'), l:root . '/', '', ''))
    let l:command = 'git --no-pager' . ' --git-dir=' . l:gitdir . ' show --no-color ' . l:format . a:args . ' -- ' . l:file
  endif

  let l:opt = deepcopy(a:option)
  let l:opt.title = '__gitblame__show__' . s:findObject(a:args) . (l:showall ? '' : '/' . fnamemodify(l:file, ':r')) . '__'

  let l:res = s:execute(l:command, l:opt)

  if l:res == -1
    return
  endif

  if l:fold
    setlocal foldenable
  endif

  setlocal filetype=git foldtext=s:FoldText() foldmethod=syntax

  let b:gitdir = l:gitdir

  call setpos('.', [bufnr('%'), 7, 0, 0])

  execute 'nnoremap <buffer> <nowait> <silent> ' . s:getKeyForMapping('parentCommit') . ' :call <SID>ShowParentCommit()<CR>'
  execute 'nnoremap <buffer> <nowait> <silent> ' . s:getKeyForMapping('nextCommit') . ' :call <SID>ShowNextCommit()<CR>'
endfunction

" blame current file
function! gitblame#blame(...) abort
  let l:edit = a:0 ? a:1 : 'edit'
  let l:root = s:SmartRoot()

  if empty(l:root)
    return
  endif

  let l:cwd = getcwd()
  let l:bnr = bufnr('%')

  execute 'lcd ' . l:root

  let l:view = winsaveview()
  let l:cmd = 'git --no-pager blame -- ' . expand('%')
  let l:opt = {
        \   'edit': l:edit,
        \   'title': '__gitblame__blame__',
        \ }
  let l:res = s:execute(l:cmd, l:opt)

  if l:res == -1
    return
  endif

  execute 'lcd ' . l:cwd

  setlocal filetype=gitblame

  call winrestview(l:view)
  call s:blameHighlight()

  execute 'nnoremap <buffer> <nowait> <silent> ' . s:getKeyForMapping('previewCommit') . ' :call <SID>ShowRefFromBlame(' . l:bnr . ')<CR>'
endfunction

" Modeline {{{
" vim: set foldmarker={{{,}}} foldlevel=0 foldmethod=marker : }}}
