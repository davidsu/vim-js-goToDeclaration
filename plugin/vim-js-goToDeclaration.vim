if !exists("g:fzf_defaultPreview")
	let g:fzf_defaultPreview = '/Users/davidsu/.dotfiles/config/nvim/plugged/fzf.vim/bin/preview.rb'
endif
if exists('$IGNORE_TESTS')
	let s:ignoreTests = $IGNORE_TESTS
else
	let s:ignoreTests = " --ignore '*.spec.js' --ignore '*.unit.js' --ignore '*.it.js' --ignore '*.*.spec.js' --ignore '*.*.*unit.js' --ignore '*.*.*it.js'"
endif
function! s:defaultPreview()
	" return fzf#vim#with_preview({'down': '100%'}, 'up:70%', 'ctrl-g')
	" return fzf#vim#with_preview({'down': '100%'}, 'up:50%', 'ctrl-e:execute:$DOTFILES/fzf/fhelp.sh {} > /dev/tty,ctrl-g')
	return {'options': ' --preview-window up:50% '.
				\'--preview "'''.g:fzf_defaultPreview.'''"\ -v\ {} '.
				\'--header ''CTRL-o - open without abort :: CTRL-s - toggle sort :: CTRL-g - toggle preview window'' '. 
				\'--bind ''ctrl-g:toggle-preview,'.
				\'ctrl-o:execute:$DOTFILES/fzf/fhelp.sh {} > /dev/tty''', 
				\'down': '100%'}

endfunction

if !exists("*CursorPing")
	function! CursorPing(...)
		let _cursorline = &cursorline
		let _cursorcolumn = &cursorcolumn
		set cursorline 
		if !a:0
			set cursorcolumn
		endif
		redraw
		sleep 350m
		let &cursorline = _cursorline
		let &cursorcolumn = _cursorcolumn
	endfunction
endif

if !exists("*FindFunction")
	function! FindFunction(functionName, ...)
		let additionalParams = ( a:0 > 0 ) ? a:1 : ''
		" (?<=...) positive lookbehind: must constain
		" (?=...) positive lookahead: must contain
		let agcmd = '''(?<=function\s)'.a:functionName.'(?=\()|'.a:functionName.'\s*:|(?<=prototype\.)'.a:functionName.'(?=\s*=\s*function)'' '.additionalParams
		call fzf#vim#ag_raw(agcmd, s:defaultPreview())
	endfunction
endif

if !exists(":FindNoTestFunction")
	command! -nargs=+ FindNoTestFunction call FindFunction(<args>, s:ignoreTests)
endif

function! s:jsxStayedInSameLine(pos, wordUnderCursor)
	return expand('%') =~ '.jsx$' && a:pos[1] == getpos('.')[1] && a:wordUnderCursor != expand('<cword>')
endfunction

function! s:handleJsxStayedInSameLine(wordUnderCursor)
	let @/=a:wordUnderCursor
	execute '?'.a:wordUnderCursor
	set hlsearch
	call CursorPing(1)
endfunction

function! s:stayedInSamePosition(pos)
	return join(a:pos) == join(getpos('.'))
endfunction

function! s:handleFunctionStayedInSamePosition(wordUnderCursor, isFunction)
	let @/=a:wordUnderCursor
	"can't jump to definition with tern, do a search with ag + fzf
	if a:isFunction
		FindNoTestFunction(a:wordUnderCursor)
	else
		call fzf#vim#ag(expand('<cword>'), s:defaultPreview() ) 
	endif
	let g:searchedKeyword=a:wordUnderCursor
endfunction

function! s:isCommanJsRequire()
	return getline('.') =~ '^const.*=\s*require(.*)$'
endfunction

function! s:goToCommanJSModule()
	call search('require(\(''\|"\).', 'e')
	silent TernDef
	call CursorPing()
endfunction
function! GoToDeclaration()
    let l:pos = getpos('.')
    let l:currFileName = expand('%')
    let l:lineFromCursorPosition = strpart(getline('.'), getpos('.')[2])
    let l:wordUnderCursor = expand('<cword>')
    let l:isFunction = match(l:lineFromCursorPosition , '^\(\w\|\s\)*(') + 1
    silent TernDef
	if s:isCommanJsRequire()
		let @/=l:wordUnderCursor
		call s:goToCommanJSModule()
    elseif s:jsxStayedInSameLine(l:pos, l:wordUnderCursor)
		call s:handleJsxStayedInSameLine(l:wordUnderCursor)
    elseif s:stayedInSamePosition(l:pos)
		call s:handleFunctionStayedInSamePosition(l:wordUnderCursor, l:isFunction)
    else
        let l:newCursorLine = getline('.')
        let l:newCurrFileName = expand('%')
        let l:regex = '^\s*' . l:wordUnderCursor . '\s*\(,\?\|\(:\s*' . l:wordUnderCursor . ',\?\)\)\s*$'
        echom l:regex
        if l:newCurrFileName != l:currFileName && match(l:newCursorLine, '\((\|=\)') < 0 && match(getline('.'), regex ) + 1
            let @/=l:wordUnderCursor
            "we are inside a module.exports, maybe we can get to the line where the function is declared
            echom 'the line: ' . getline('.')
            call search(l:wordUnderCursor . '\s*\((\|=\)')
            " note that i changed this function in python to allow `add_jump_position` argument
            py3 tern_lookupDefinition("edit", add_jump_position=False)
        endif
        normal zz
        call CursorPing()
    endif
endfunction