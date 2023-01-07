if exists('toggle_inline_plugin_loaded') || &cp
    finish
endif
let toggle_inline_plugin_loaded=1


function! s:ToggleInline()
    """ Toggle inlining function params or one-param-per-line,
    " for function at current cursor position.
    "
    " Example:
    "   Toggle between:
    "
    "   A:
    "     def abc(
    "       a,
    "       b = nil,
    "       c: bar,
    "       d: foo()
    "     )
    "
    "   B:
    "     def abc(a, b = nil, c: bar, d: foo())
    """
    let l:def_start_lineno = s:FindDefStartLine()
    let l:def_start_line = getline(l:def_start_lineno)
    let l:paren_open_col = matchend(l:def_start_line, s:OpenBracketRegex())
    let l:open_bracket_ch = l:def_start_line[l:paren_open_col]

    let l:paren_open_coord  = [l:def_start_lineno, l:paren_open_col]
    let l:paren_close_coord = s:FindFunctionDefEnd(l:def_start_lineno, l:paren_open_col, l:open_bracket_ch, 0)

    if l:paren_open_coord[0] != l:paren_close_coord[0]
        call s:InlineFunction(l:paren_open_coord[0], l:paren_close_coord[0], l:open_bracket_ch)
    else
        call s:UnInlineFunction(l:paren_open_coord[0], l:open_bracket_ch)
    endif
endfunction


function! s:OpenBracketRegex()
    " let l:fn_start_regex = ''
    "     \ . '\([a-zA-Z0-9]\)\@<!'
    "     \ . 'def [^(]\+'

    " let l:fn_call_regex = ''
    "   \ . '\([a-zA-Z0-9]\+\)'
    "   \ . '\((\)\@='

    " let l:def_start_regex = ''
    "     \ . '\('
    "     \ . l:fn_start_regex
    "     \ . '\|'
    "     \ . l:fn_call_regex
    "     \ . '\)'
    " return l:def_start_regex

    " let l:open_brackets = ['(', '[']
    " return '.' . '\(' . join(l:open_brackets, '\|') . '\)\@='

    let l:round_bracket = '[^(]\+' . '\((\)\@='
    let l:square_bracket = '[^\[]\+' . '\(\[\)\@='
    let l:curly_bracket = '[^{]\+' . '\({\)\@='
    let l:matches = [l:round_bracket, l:square_bracket, l:curly_bracket]
    " return '[^(]\+' . '\((\)\@='
    return '\(' . join(l:matches, '\|') . '\)'
endfunc


function! s:InlineFunction(paren_open_ln, paren_close_ln, open_bracket_ch)
    """ If function params span multiple lines, inline them so they only take one.
    "
    " Params:
    "   paren_open_ln: `(ex. 12)`
    "     line number with start of function definition
    "
    "   paren_close_ln `(ex: 15)`
    "     line number with end of function definition
    "
    " Example:
    "   FROM:
    "     def abc(
    "       a,
    "       b = nil,
    "       c: bar,
    "       d: foo()
    "     )
    "
    "   TO:
    "     def abc(a, b = nil, c: bar, d: foo())
    """
    let l:closing_bracket_ch = s:ClosingBracketFor(a:open_bracket_ch)

    " inline params
    let l:newline = getline(a:paren_open_ln)
    for l:lineno in range(a:paren_open_ln + 1, a:paren_close_ln)
        let l:ln = trim(getline(lineno))
        if l:ln[-1:-1] == ','
            let l:ln .= ' '
        endif
        let l:newline .= l:ln
    endfor

    " ditch trailing comma, if present
    if l:newline[-3:-1] == ', '. l:closing_bracket_ch
        let l:newline = l:newline[:-4] . l:closing_bracket_ch
    endif

    " replace first line in function, and delete lines after it
    call setline(a:paren_open_ln, l:newline)
    call deletebufline(bufnr(), a:paren_open_ln + 1, a:paren_close_ln)
endfunc


function! s:UnInlineFunction(lineno, open_bracket_ch)
    """ If function params are all on single line,
    " split them so one param per line,
    " using configured tab settings.
    "
    " Params:
    "   lineno: `(ex. 123)`
    "     line number of function declaration
    "
    " Example:
    "   FROM:
    "     def abc(a, b = nil, c: bar, d: foo())
    "
    "   TO:
    "     def abc(
    "       a,
    "       b = nil,
    "       c: bar,
    "       d: foo()
    "     )
    """
    let l:line = getline(a:lineno)
    let l:open_paren_col = s:FindDefParenStartCol(a:lineno)
    if l:open_paren_col < 0
        echom "[ERROR] not a function"
        return 0
    endif

    let l:close_paren_col = s:FindFunctionDefEnd(a:lineno, l:open_paren_col, a:open_bracket_ch, 0)[1]
    let l:paren_comma_cols = s:FindUnInlineNewlineCols(a:lineno, l:open_paren_col, l:close_paren_col, a:open_bracket_ch)

    " split function into 1x line/param
    let l:lines = []
    let l:last_col = -1
    for col in l:paren_comma_cols
        call add(l:lines, l:line[(l:last_col + 1):col])
        let last_col = col
    endfor
    call add(l:lines, l:line[(l:last_col + 1):])

    " determine indent-lvl of function
    let l:indent_chars = matchend(l:lines[0], '^\s\+')
    if l:indent_chars == -1
        let l:indent_chars = 0
    endif

    " determine tab char
    if &expandtab
        let l:indent_char = ' '
    else
        let l:indent_char = '\t'
    endif

    " set indentation for each l:lines entry
    let l:newlines = []
    call add(l:newlines, l:lines[0])
    if 1 < len(l:lines) - 2
        for i in range(1, len(l:lines) - 2)
            let indent = repeat(l:indent_char, l:indent_chars + &softtabstop)
            call add(l:newlines, indent . trim(l:lines[i]))
        endfor
        call add(l:newlines, repeat(l:indent_char, l:indent_chars) . l:lines[-1])
    endif

    " change buffer contents
    for ln in reverse(l:newlines)
        call appendbufline(bufnr(), a:lineno, ln)
    endfor
    call deletebufline(bufnr(), a:lineno)
endfunc


function! s:FindDefStartLine()
    """ Returns lineno of nearest function, relative to current cursor position.
    """
    if match(getline('.'), s:OpenBracketRegex()) >= 0
        return line('.')
    else
        return search(s:OpenBracketRegex(), 'b')
    endif
endfunc


function! s:FindDefParenStartCol(lineno)
    """ Returns the position of the '(' char in a function def (start of params)
    """
    let l:line = getline(a:lineno)
    let l:fn_def_start_col = matchend(l:line, s:OpenBracketRegex())
    if l:fn_def_start_col == -1
        return -1
    endif
    return l:fn_def_start_col
endfunc


function! s:FindFunctionDefEnd(line_no, col_no, open_bracket_ch, _parens_depth)
    """ Finds end of function declaration, from `line_no`, `col_no` onwards (even if it is on a lower line).
    " Typically `line_no, col_no` indicates the opening `(` of the function declaration.
    "
    " Params:
    "   line_no: `(ex. 123)`
    "     line number to start searching for 'end' from.
    "
    "   col_no: `(ex. 0)`
    "     character's column number to start searching for 'end' from.
    "
    "   open_bracket_ch: `(ex. '{')`
    "     bracket whose complementing closing bracket we are looking for.
    "
    "   _parens_depth: `(ex. 0)`
    "     Internal only, set to `0` unless you know what you are doing.
    "     Keeps track of the current `()` bracket nesting depth.
    "     Incremented by 1 for each opened bracket, decremented for closing.
    "
    " Returns: `[line_no, col_no]`
    "   with end of function params
    """
    let l:closing_bracket_ch = s:ClosingBracketFor(a:open_bracket_ch)
    let l:line = getline(a:line_no)[a:col_no:]

    let l:parens_depth = a:_parens_depth
    let l:double_quote_active = 0
    let l:single_quote_active = 0

    for i in range(0, len(l:line))
        let l:char = l:line[i]
        if l:double_quote_active == 0 && l:single_quote_active == 0
            if l:char == a:open_bracket_ch
                let l:parens_depth += 1
            elseif l:char == l:closing_bracket_ch
                let l:parens_depth -= 1
                if l:parens_depth == 0
                    return [a:line_no, a:col_no + i]
                endif
            endif
        elseif l:char == '"'
            if l:double_quote_active == 1
                let l:double_quote_active = 0
            else
                let l:double_quote_active = 1
            endif
        elseif l:char == "'"
            if l:single_quote_active == 1
                let l:single_quote_active = 0
            else
                let l:single_quote_active = 1
            endif
        endif
    endfor

    " if parens still open, recurse
    if l:parens_depth > 0
        return s:FindFunctionDefEnd(a:line_no + 1, 0, a:open_bracket_ch, l:parens_depth)
    else
        return [a:line_no, a:col_no]
    endif
endfunction


function! s:FindUnInlineNewlineCols(lineno, open_paren_col, close_paren_col, open_bracket_ch)
    """ Finds col positions within an inlined function where a newline should be added.
    "
    " Params:
    "   lineno: `(ex. 123)`
    "     line number with inlined function
    "
    "   open_paren_col `(ex: 3)`
    "     column of '(' where params start being defined
    "
    "   close_paren_col `(ex: 8)`
    "     column of ')' where params stop being defined
    """
    let l:line = getline(a:lineno)
    let l:parens_depth = 0
    let l:double_quote_active = 0
    let l:single_quote_active = 0
    let l:paren_sep_positions = []
    let l:closing_bracket_ch = s:ClosingBracketFor(a:open_bracket_ch)

    for i in range(a:open_paren_col, a:close_paren_col)
        let l:char = l:line[i]
        if l:double_quote_active == 0 && l:single_quote_active == 0
            if l:char == a:open_bracket_ch
                let l:parens_depth += 1
                if l:parens_depth == 1
                    call add(l:paren_sep_positions, i)
                endif
            elseif l:char == l:closing_bracket_ch
                let l:parens_depth -= 1
                if l:parens_depth == 0
                    call add(l:paren_sep_positions, i - 1)
                endif
            elseif l:char == ',' && l:parens_depth == 1
                call add(l:paren_sep_positions, i)
            endif
        elseif l:char == '"'
            if l:double_quote_active == 1
                let l:double_quote_active = 0
            else
                let l:double_quote_active = 1
            endif
        elseif l:char == "'"
            if l:single_quote_active == 1
                let l:single_quote_active = 0
            else
                let l:single_quote_active = 1
            endif
        endif
    endfor

    return l:paren_sep_positions
endfunc


function! s:ClosingBracketFor(bracket_ch)
    if a:bracket_ch == '('
        return ')'
    elseif a:bracket_ch == '['
        return ']'
    elseif a:bracket_ch == '{'
        return '}'
    else
        throw E:570 " Internal Error: {function}
    endif
endfunc

" ========
" Commands
" ========

command ToggleInline :call s:ToggleInline()
