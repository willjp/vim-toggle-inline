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
    let l:open_pos = s:FindBracketStartPos()
    let l:open_char = getline(l:open_pos[0])[l:open_pos[1]]
    let l:close_pos = s:FindBracketEndPos(l:open_pos[0], l:open_pos[1], l:open_char, 0)

    if l:open_pos[0] != l:close_pos[0]
        call s:InlineFunction(l:open_pos[0], l:close_pos[0], l:open_char)
    else
        call s:UnInlineFunction(l:open_pos[0], l:open_char)
    endif
endfunction


function! s:InlineFunction(paren_open_ln, paren_close_ln, open_bracket_ch)
    """ If function params span multiple lines, inline them so they only take one.
    "
    " Params:
    "   paren_open_ln: `(ex: 12 )`
    "     line number with start of function definition
    "
    "   paren_close_ln: `(ex: 15 )`
    "     line number with end of function definition
    "
    "   open_bracket_ch: `(ex: '{' )`
    "     the opening bracket character
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
    "   open_bracket_ch: `(ex: '{' )`
    "     the opening bracket character
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
    let l:open_paren_col = s:FindBracketStartCol(a:lineno)
    if l:open_paren_col < 0
        echom "[ERROR] not a function"
        return 0
    endif

    let l:close_paren_col = s:FindBracketEndPos(a:lineno, l:open_paren_col, a:open_bracket_ch, 0)[1]
    let l:paren_comma_cols = s:FindUnInlineNewlineCols(a:lineno, l:open_paren_col, l:close_paren_col, a:open_bracket_ch)

    " split function/collection into 1x line/(param|item)
    let l:lines = []
    let l:last_col = -1
    for col in l:paren_comma_cols
        call add(l:lines, l:line[(l:last_col + 1):col])
        let last_col = col
    endfor
    call add(l:lines, l:line[(l:last_col + 1):])

    " determine indent-lvl of function/collection
    let l:indent_chars = matchend(l:lines[0], '^\s\+')
    if l:indent_chars == -1
        let l:indent_chars = 0
    endif

    " determine tab char
    let l:indent_char = s:IndentChar()

    " set indentation for each l:lines entry
    let l:newlines = []
    call add(l:newlines, l:lines[0])
    if 1 <= len(l:lines) - 2
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


function! s:OpenBracketRegex()
    """ Returns regex for the supported opening-bracket types.
    """
    let l:round_bracket = '[^(]\+' . '\((\)\@='
    let l:square_bracket = '[^\[]\+' . '\(\[\)\@='
    let l:curly_bracket = '[^{]\+' . '\({\)\@='

    let l:matches = [l:round_bracket, l:square_bracket, l:curly_bracket]
    return '\(' . join(l:matches, '\|') . '\)'
endfunc


function! s:ClosingBracketFor(bracket_ch)
    """ Returns closing bracket character for an opening bracket.
    "
    " Example:
    "   call s:ClosingBracketFor('{')  " --> '}'
    "   call s:ClosingBracketFor('[')  " --> ']'
    """
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


function! s:FindBracketStartPos()
    """ Returns (x,y) of opening-bracket.
    """
    let l:lineno = s:FindBracketStartLine()
    let l:col = s:FindBracketStartCol(l:lineno)
    return [l:lineno, l:col]
endfunc


function! s:FindBracketEndPos(line_no, col_no, open_bracket_ch, _parens_depth)
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
        return s:FindBracketEndPos(a:line_no + 1, 0, a:open_bracket_ch, l:parens_depth)
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


function! s:IndentChar()
    if &expandtab
        return ' '
    else
        return '\t'
    endif
endfunc


function! s:FindBracketStartLine()
    """ Returns lineno of nearest function, relative to current cursor position.
    """
    if match(getline('.'), s:OpenBracketRegex()) >= 0
        return line('.')
    else
        return search(s:OpenBracketRegex(), 'b')
    endif
endfunc


function! s:FindBracketStartCol(lineno)
    """ Returns the position of the open-bracket-char.
    "
    " Returns:
    "   12  " column-number of opening-bracket
    """
    let l:line = getline(a:lineno)
    let l:fn_def_start_col = matchend(l:line, s:OpenBracketRegex())
    if l:fn_def_start_col == -1
        return -1
    endif
    return l:fn_def_start_col
endfunc


" ========
" Commands
" ========

command ToggleInline :call s:ToggleInline()
