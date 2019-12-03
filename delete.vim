function s:is_exist_clipboard_window() 
    return get(g:, 'clipboard_wid') != 0 && nvim_win_is_valid(g:clipboard_wid) == v:true
endfunction

function! s:create_clipboard_window()
    if s:is_exist_clipboard_window()
        return g:clipboard_wid
    endif 
    let window_width = nvim_win_get_width(0)
    let window_height = nvim_win_get_height(0)
    let width = float2nr(window_width*0.4)
    let config = { 
        \'relative': 'editor',
        \ 'row': 1,
        \ 'col': window_width - width,
        \ 'width': width,
        \ 'height': float2nr(window_height*0.8),
        \ 'anchor': 'NW',
        \ 'style': 'minimal',
        \}
    let win_id = s:create_window(config)
    hi clipboard guifg=#ffffff guibg=#aff577
    call nvim_win_set_option(win_id, 'winhighlight', 'Normal:clipboard')
    call nvim_win_set_option(win_id, 'winblend', 60)
    call nvim_win_set_config(win_id, config)
    set nowrap
    return win_id
endfunction

function! s:create_window(config)
    let buf = nvim_create_buf(v:false, v:true)
    let win_id = nvim_open_win(buf, v:true, a:config)
    return win_id
endfunction

function! s:move_floating_window(win_id, relative, row, col)
  let newConfig = {'relative': a:relative, 'row': a:row, 'col': a:col,}
  call nvim_win_set_config(a:win_id, newConfig)
  redraw
endfunction

function! s:focus_to_main_window()
    execute "0windo :"
endfunction

function! s:get_col() 
    " when `set nonumber` not need adjustment
    if &number == 0
        return 0
    endif
    " not support over 1000 line file
    return 4
endfunction

function! s:split_words()
    let words = split(getline('.'), '\zs')
    let result = []
    let index = 0
    let i = 0
    let word = ''
    let split_num = 7
    while i < len(words)
        let word = word . words[i]
        if i % (len(words)/split_num)  == 0 && i != 0
            call insert(result, word, index)
            let word = ''
            let index += 1
        endif
        let i += 1
    endwhile
    call insert(result, word, index)
    return result
endfunction

function! s:fall_window(win_id)
    let move_y = line('w$') - line('.')
    let config = nvim_win_get_config(a:win_id)
    for y in range(0, move_y)
        call s:move_floating_window(a:win_id, config.relative, config.row + y + 1, config.col) 
        sleep 4ms
    endfor
endfunction

function! s:set_color_random(win_id)
    let color = '#' . printf("%x", Random(16)) . printf("%05x", Random(69905))
    let hl_name = 'ClipBG' . a:win_id
    execute 'hi' hl_name 'guifg=#ffffff' 'guibg=' . color
    call nvim_win_set_option(a:win_id, 'winhighlight', 'Normal:'.hl_name)
endfunction

function! s:create_words_window()
    let row = line('.') - line('w0')
    let col = s:get_col()
    let win_ids = []
    let words = s:split_words()

    for word in words
        let width = strdisplaywidth(word)
        if width == 0
            continue
        endif
        let config = {
            \'relative': 'editor',
            \ 'row': row,
            \ 'col': col,
            \ 'width': width,
            \ 'height': 1,
            \ 'anchor': 'NW',
            \ 'style': 'minimal',
            \}
        let win_id = s:create_window(config)
        call add(win_ids, win_id)

        call s:set_color_random(win_id)
        " call nvim_win_set_option(win_id, 'winblend', 100)

        call setline('.', word)
        call s:focus_to_main_window()
        let col += width
    endfor
    return win_ids
endfunction

function! s:move_split_window_to_clip_window(win_id)
    let clipboard_config = nvim_win_get_config(g:clipboard_wid)
    let clipboard =  s:winid2tabnr(g:clipboard_wid)
    execute clipboard . 'windo :'
    let clipboard_last_line = line('w$')

    let y = 0
    let is_max = v:false
    let config = nvim_win_get_config(a:win_id)
    let max_y = float2nr(config.row - clipboard_config.row - clipboard_last_line + 1)
    for _ in range(0, float2nr(clipboard_config.col))
        let config = nvim_win_get_config(a:win_id)
        let y += 1
        if is_max
            call s:move_floating_window(a:win_id, config.relative, config.row, config.col + 1) 
        else
            call s:move_floating_window(a:win_id, config.relative, config.row - 1, config.col + 1) 
        endif
        if y == max_y
            let is_max = v:true
        endif
        sleep 1ms
    endfor
endfunction

function! s:get_text(win_id)
    let win =  s:winid2tabnr(a:win_id)
    execute win . 'windo :'
    return getline('.')
endfunction

function! s:winid2tabnr(win_id) abort
  return win_id2tabwin(a:win_id)[1]
endfunction

function Random(max) abort
  return str2nr(matchstr(reltimestr(reltime()), '\v\.@<=\d+')[1:]) % a:max
endfunction

function! s:main() abort
    " create clipboard window
    let win_ids = s:create_words_window()

    " fall current line
    call setline('.', '')
    for win_id in win_ids
        call s:fall_window(win_id)
    endfor
    execute 'normal dd'

    " move window to clipboard window
    let text = ''
    for win_id in win_ids
        call s:move_split_window_to_clip_window(win_id)
        let text .= s:get_text(win_id)
    endfor

    " set current line string to clipboard window
    let clipboard =  s:winid2tabnr(g:clipboard_wid)
    execute clipboard . 'windo :'
    call setline('.', text)
    redraw
    execute 'normal o'
    call s:focus_to_main_window()

    " close each floating window
    for win_id in win_ids
        call nvim_win_close(win_id, v:true)
    endfor
endfunction

let g:clipboard_wid = s:create_clipboard_window()
call s:focus_to_main_window()

nnoremap <silent> T :call <SID>main()<CR>
