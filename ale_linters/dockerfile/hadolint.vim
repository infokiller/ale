" Author: hauleth - https://github.com/hauleth

" always, yes, never
call ale#Set('dockerfile_hadolint_use_docker', 'never')
call ale#Set('dockerfile_hadolint_docker_image', 'hadolint/hadolint')

" Shellcheck knows a 'style' severity - pin it to info level as well.
let s:json_level_to_type = {
    \ 'style': 'I',
    \ 'info': 'I',
    \ 'warning': 'W',
    \ 'error': 'E',
\ }

function! ale_linters#dockerfile#hadolint#Handle(buffer, lines) abort
    " The json output is an array where each lint finding is in a dict, for
    " example:
    "
    " [
    "     {
    "         "line": 5,
    "         "code": "DL3008",
    "         "message": "Pin versions in apt get install.",
    "         "column": 1,
    "         "file": "-",
    "         "level": "warning"
    "     },
    "     ...
    " ]
    let l:output = []
    for l:error in json_decode(a:lines)
        let l:domain = 'https://github.com/hadolint/hadolint/wiki/'
        if l:error['code'][:1] is# 'SC'
            let l:domain = 'https://github.com/koalaman/shellcheck/wiki/'
        endif
        let l:detail = printf("%s ( %s%s ) \n\n%s", 
            \ l:error['code'], l:domain, l:error['code'], l:error['message'],
        \ ) 
        call add(l:output, {
        \   'lnum': l:error['line'],
        \   'col': l:error['column'],
        \   'type': get(s:json_level_to_type, l:error['level'], 'E'),
        \   'text': l:error['message'],
        \   'detail': l:detail,
        \})
    endfor
    return l:output
endfunction

" This is a little different than the typical 'executable' callback.  We want
" to afford the user the chance to say always use docker, never use docker,
" and use docker if the hadolint executable is not present on the system.
"
" In the case of neither docker nor hadolint executables being present, it
" really doesn't matter which we return -- either will have the effect of
" 'nope, can't use this linter!'.

function! ale_linters#dockerfile#hadolint#GetExecutable(buffer) abort
    let l:use_docker = ale#Var(a:buffer, 'dockerfile_hadolint_use_docker')

    " check for mandatory directives
    if l:use_docker is# 'never'
        return 'hadolint'
    elseif l:use_docker is# 'always'
        return 'docker'
    endif

    " if we reach here, we want to use 'hadolint' if present...
    if executable('hadolint')
        return 'hadolint'
    endif

    "... and 'docker' as a fallback.
    return 'docker'
endfunction

function! ale_linters#dockerfile#hadolint#GetCommand(buffer) abort
    let l:command = ale_linters#dockerfile#hadolint#GetExecutable(a:buffer)
    let l:opts = '--format=json -'

    if l:command is# 'docker'
        return printf('docker run --rm -i %s hadolint %s',
            \ ale#Var(a:buffer, 'dockerfile_hadolint_docker_image'), 
            \ l:opts)
    endif

    return 'hadolint ' . l:opts
endfunction


call ale#linter#Define('dockerfile', {
\   'name': 'hadolint',
\   'executable': function('ale_linters#dockerfile#hadolint#GetExecutable'),
\   'command': function('ale_linters#dockerfile#hadolint#GetCommand'),
\   'callback': 'ale_linters#dockerfile#hadolint#Handle',
\})
