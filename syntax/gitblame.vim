let b:current_syntax = 'gitblame'

syntax match gitblameBoundary "^\^"
syntax match gitblameBlank "^\s\+\s\@=" nextgroup=gitblameAnnotation,gitblameOriginalLineNumber skipwhite

syntax match gitblameHash        "\%(^\^\=\)\@<=\x\{7,40\}\>" nextgroup=gitblameAnnotation,gitblameOriginalLineNumber skipwhite
syntax match gitblameUncommitted "\%(^\^\=\)\@<=0\{7,40\}\>"  nextgroup=gitblameAnnotation,gitblameOriginalLineNumber skipwhite

syntax region gitblameAnnotation matchgroup=gitblameDelimiter start="(" end="\%( \d\+\)\@<=)" contained keepend oneline
syntax match gitblameTime "[0-9:/+-][0-9:/+ -]*[0-9:/+-]\%( \+\d\+)\)\@=" contained containedin=gitblameAnnotation

if has('conceal')
  syntax match gitblameLineNumber   " *\d\+)\@=" contained containedin=gitblameAnnotation conceal
  syntax match gitblameOriginalFile " \%(\f\+\D\@<=\|\D\@=\f\+\)\%(\%(\s\+\d\+\)\=\s\%((\|\s*\d\+)\)\)\@=" contained nextgroup=gitblameOriginalLineNumber,gitblameAnnotation skipwhite conceal

  syntax match gitblameOriginalLineNumber " *\d\+\%(\s(\)\@="       contained nextgroup=gitblameAnnotation skipwhite conceal
  syntax match gitblameOriginalLineNumber " *\d\+\%(\s\+\d\+)\)\@=" contained nextgroup=gitblameShort      skipwhite conceal
else
  syntax match gitblameLineNumber   " *\d\+)\@=" contained containedin=gitblameAnnotation
  syntax match gitblameOriginalFile " \%(\f\+\D\@<=\|\D\@=\f\+\)\%(\%(\s\+\d\+\)\=\s\%((\|\s*\d\+)\)\)\@=" contained nextgroup=gitblameOriginalLineNumber,gitblameAnnotation skipwhite

  syntax match gitblameOriginalLineNumber " *\d\+\%(\s(\)\@="       contained nextgroup=gitblameAnnotation skipwhite
  syntax match gitblameOriginalLineNumber " *\d\+\%(\s\+\d\+)\)\@=" contained nextgroup=gitblameShort      skipwhite
endif

syntax match gitblameShort " \d\+)" contained contains=gitblameLineNumber
syntax match gitblameNotCommittedYet "(\@<=Not Committed Yet\>" contained containedin=gitblameAnnotation

highlight def link gitblameBoundary           Keyword
highlight def link gitblameHash               Identifier
highlight def link gitblameUncommitted        Ignore
highlight def link gitblameTime               PreProc
highlight def link gitblameLineNumber         Number
highlight def link gitblameOriginalFile       String
highlight def link gitblameOriginalLineNumber Float
highlight def link gitblameShort              gitblameDelimiter
highlight def link gitblameDelimiter          Delimiter
highlight def link gitblameNotCommittedYet    Comment
