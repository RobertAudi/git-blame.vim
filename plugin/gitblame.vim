if exists('g:loaded_gitblame')
  finish
endif
let g:loaded_gitblame = 1

" Restore diff status if no diff buffer open
function! s:Onbufleave()
  let l:wnr = +bufwinnr(+expand('<abuf>'))
  let l:val = getwinvar(l:wnr, 'gitblame_diff_origin')

  if !len(l:val)
    return
  endif

  for l:i in range(1, winnr('$'))
    if l:i == l:wnr
      continue
    endif

    if len(getwinvar(l:i, 'gitblame_diff_origin'))
      return
    endif
  endfor

  let l:wnr = bufwinnr(l:val)

  if l:wnr > 0
    execute l:wnr . 'wincmd w'

    diffoff
  endif
endfunction

augroup gitblame
  autocmd!

  autocmd BufWinLeave __gitblame__file* call s:Onbufleave()
augroup END

let g:gitblame_mappings = extend({
      \   'previewCommit': 'p',
      \   'nextCommit': 'd',
      \   'parentCommit': 'u',
      \   'close': 'q',
      \ }, get(g:, 'gitblame_mappings', {}), 'force')

let g:gitblame_line_numbers = get(g:, 'gitblame_line_numbers', -1)

command! -nargs=0 GitBlame call gitblame#blame()

nnoremap <silent> <Plug>GitBlameOpen :GitBlame<CR>

" Modeline {{{
" vim: set foldmarker={{{,}}} foldlevel=0 foldmethod=marker : }}}
