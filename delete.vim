function! s:move_floating_window(win_id, relative, row, col)
  let newConfig = {
    \ 'relative': a:relative,
    \ 'row': a:row,
    \ 'col': a:col,
    \}
  call nvim_win_set_config(a:win_id, newConfig)
  redraw
endfunction

function! s:create_window(config)
    let buf = nvim_create_buf(v:false, v:true)
    let win_id = nvim_open_win(buf, v:true, a:config)
    hi window_color guifg=#ffffff guibg=#dd6900
    call nvim_win_set_option(win_id, 'winhighlight', 'Normal:window_color')
    call nvim_win_set_option(win_id, 'winblend', 10)
    return win_id
endfunction

function! s:focus_to_main_window()
    execute "0windo :"
endfunction

function! s:transparency_window(win_id)
    let i = 0
    while i <= 50
        call nvim_win_set_option(a:win_id, 'winblend', i*2)
        let i += 1
        " 毎回redrawするとカクつくため
        if i % 2 == 0
            redraw
        endif
    endwhile
endfunction

function! s:get_col() 
    " 行番号を非表示にしている場合は調整不要なので0を返す
    if &number == 0
        return 0
    endif
    " 1000行超えのファイルは未対応。1000行超えの場合ズレる。
    return 4
endfunction

function! s:get_width() 
    return strlen(getline('.'))
endfunction

function! s:get_height() 
    let contents = split(getline('.'), '\n')
    return len(contents)
endfunction

function! s:split_words()
    let words = split(getline('.'), '\zs')
    let result = []
    let index = 0
    let i = 0
    let word = ''
    while i < len(words)
        let word = word . words[i]
        if i % 4  == 0 && i != 0
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
    let i = 0
    let config = nvim_win_get_config(a:win_id)
    while i <= move_y
        call s:move_floating_window(a:win_id, config.relative, config.row + i + 1, config.col) 
        sleep 5ms
        let i += 1
    endwhile
endfunction

function! s:set_color_random(win_id)
    let color = "#" . printf('%02x', float2nr(Random(255))). printf('%02x', float2nr(Random(255))). printf('%02x', float2nr(Random(255)))
    let hl_name = 'ClipBG' . a:win_id
    execute 'hi' hl_name 'guifg=#ffffff' 'guibg=' . color
    call nvim_win_set_option(a:win_id, 'winhighlight', 'Normal:'.hl_name)
endfunction

" 現在行の文字列を分割し、floating windowを作成
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
        let config = { 'relative': 'editor', 'row': row, 'col': col, 'width': width, 'height': 1, 'anchor': 'NW', 'style': 'minimal',}
        let win_id = s:create_window(config)
        call nvim_win_set_option(win_id, 'winblend', 100)
        call add(win_ids, win_id)

        " ランダムな色をつける
        call s:set_color_random(win_id)

        call setline('.', word)
        execute "0windo " . ":"
        let col += width
    endfor
    return win_ids
endfunction

function! s:move_split_window_to_clip_window(win_id)
    let clipboard_config = nvim_win_get_config(g:clipboard_wid)
    let clipboard_col = clipboard_config.col
    let clipboard_row = clipboard_config.row
    let clipboard_text = s:get_text(g:clipboard_wid)
    let clipboard =  s:winid2tabnr(g:clipboard_wid)
    execute clipboard . 'windo :'
    let clipboard_last_line = line('w$')

    let i = 0
    let y = 0
    let is_max = v:false
    let config = nvim_win_get_config(a:win_id)
    let max_y = float2nr(config.row - clipboard_row - clipboard_last_line + 1)
    while i <= clipboard_col
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

        let i += 1
    endwhile
endfunction

function! s:get_text(win_id)
    let win =  s:winid2tabnr(a:win_id)
    execute win . 'windo :'
    return getline('.')
endfunction

function s:is_exist_clipboard_window() 
    return get(g:, 'clipboard_wid') != 0 && nvim_win_is_valid(g:clipboard_wid) == v:true
endfunction

function! s:create_clipboard_window()
    if s:is_exist_clipboard_window()
        return g:clipboard_wid
    endif 
    let config = { 'relative': 'editor', 'row': 10, 'col': 120, 'width': 50, 'height': 30, 'anchor': 'NW', 'style': 'minimal',}
    let win_id = s:create_window(config)
    call nvim_win_set_config(win_id, config)
    call nvim_win_set_option(win_id, 'winblend', 10)
    set nowrap
    return win_id
endfunction

function! s:winid2tabnr(win_id) abort
  return win_id2tabwin(a:win_id)[1]
endfunction

function! s:main()
    " 現在行の文字列をfloating windowで作成
    let win_ids = s:create_words_window()

    " 現在行を空行にする
    call setline('.', '')

    " 各floating windowを下に落とす
    for win_id in win_ids
        call s:fall_window(win_id)
    endfor

    " 空行を削除
    execute 'normal dd'

    " 各floating windowを移動
    let text = ''
    for win_id in win_ids
        call s:move_split_window_to_clip_window(win_id)
        let text .= s:get_text(win_id)
    endfor

    " クリップボードwindowにテキストを挿入
    let clipboard =  s:winid2tabnr(g:clipboard_wid)
    execute clipboard . 'windo :'
    call setline('.', text)

    " クリップボードwindowに改行を挿入
    execute 'normal o'

    call s:focus_to_main_window()

    " 各floating windowを削除
    for win_id in win_ids
        call nvim_win_close(win_id, v:true)
    endfor
endfunction

" クリップボードウィンドウを生成
let g:clipboard_wid = s:create_clipboard_window()
call s:focus_to_main_window()

nnoremap <silent> T :call <SID>main()<CR>

function Random(max) abort
  return str2nr(matchstr(reltimestr(reltime()), '\v\.@<=\d+')[1:]) % a:max
endfunction
