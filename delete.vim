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
    hi mycolor guifg=#ffffff guibg=#dd6900
    call nvim_win_set_option(win_id, 'winhighlight', 'Normal:mycolor')
    call nvim_win_set_option(win_id, 'winblend', 10)
    return win_id
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


function! s:main()
    let current_line_text = getline('.')
    let start_row = line('.') - line('w0')
    let col = s:get_col()
    let width = s:get_width()
    let height = s:get_height()
    let config = { 'relative': 'editor', 'row': start_row, 'col': col, 'width': width, 'height': height, 'anchor': 'NW', 'style': 'minimal',}
    if width == 0 || height == 0
        return
    endif

    let win_ids = []
    " 現在行の文字列を分割し、floating windowで表示
    let words = s:split_words()
    let i = 0
    for word in words
        let width = strdisplaywidth(word)
        if width == 0
            continue
        endif
        let config = { 'relative': 'editor', 'row': start_row+1, 'col': col, 'width': width, 'height': 1, 'anchor': 'NW', 'style': 'minimal',}
        let win_id = s:create_window(config)
        call add(win_ids, win_id)

        " ランダムな色を返すようにする
        let color = "#" . printf('%02x', float2nr(Random(255))). printf('%02x', float2nr(Random(255))). printf('%02x', float2nr(Random(255)))
        let hl_name = 'ClipBG' . i
        execute 'hi' hl_name 'guifg=#ffffff' 'guibg=' . color
        call nvim_win_set_option(win_id, 'winhighlight', 'Normal:'.hl_name)

        call setline('.', word)
        execute "0windo " . ":"
        let col += width
        let i += 1
    endfor
    redraw
    " execute 'normal dd'
    sleep 500ms

    " floating windowを上から降らす
    let move_y = line('w$') - line('.')
    let i = 0
    while i <= move_y
        " call s:move_floating_window(win_id, config.relative, config.row + i + 1, config.col) 
        " sleep 20ms
        let i += 1
    endwhile

    " floating windowを透明化
    " call s:transparency_window(win_id)

    sleep 1
    " floating windowを削除
    for win_id in win_ids
        call nvim_win_close(win_id, v:true)
    endfor
endfunction

nnoremap <silent> T :call <SID>main()<CR>

function Random(max) abort
  return str2nr(matchstr(reltimestr(reltime()), '\v\.@<=\d+')[1:]) % a:max
endfunction