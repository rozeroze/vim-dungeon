" dungeon


" NOTE: 開発中
"finish

" TODO: {{{
" skeleton の量産を絞る
" wizard の特殊スキルは対象Typeごとに変化後を変える
"   今のままではモンスターばかり増えていて見分けがつかない
" harpy に魅惑のスキルを追加する（対tamer）
"   魅惑スキルを弱体化するか、一定ターン後に解除されるようにする
" lancer の攻撃時の貫通効果がおかしい　貫通対象の位置
" 攻撃時の処理を攻撃側ではなく被害側に実装する
"   gengar に hide を実装する（hide時は攻撃をうけない）
" new monster <<cost tank>> 実装
"   生きている限り cost が増加する　無移動・無攻撃
" rook の弱体化　仲間を呼ぶ特殊スキル追加
" 使役できるモンスターに上限を設ける
" turnlist にユニット以外のフィールド要素を盛り込む
" field に空きが無くなった時の対応
" wizard によって作られた fiary のマナヒーリングが死後も続いている
"   というより、主に wizard が原因のエラー多発？
" 上記の変更を　誰かに押し付ける
" }}}


"if !exists("g:loaded_extension")
"    finish
"endif


""" field
" basic {{{
let s:field = { "map": [
            \     "+-----------+",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "|...........|",
            \     "+-----------+"
            \   ],
            \  "max_x": 0, "max_y": 0
            \ }
" }}}
" reset {{{
function! s:field.reset()
    norm! ggdG
    for ln in self.map
        call append(0, ln)
    endfor
    norm! Gddgg
endfunction
" }}}
" inner range? {{{
function! s:field.innerrange(x, y)
    if a:x < 1 || self.max_x < a:x | return 0 | endif
    if a:y < 1 || self.max_y < a:y | return 0 | endif
    return 1
endfunction
" }}}
" get panel {{{
function! s:field.getpanel(x, y)
    let c = getline(a:y)[a:x - 1]
    return c
endfunction
" }}}
" get panel type {{{
function! s:field.getpaneltype(x, y)
    let c = getline(a:y)[a:x - 1]
    if stridx("+-|", c) != -1
        return "wall"
    endif
    if stridx(".", c) != -1
        return "floor"
    endif
    "if stridx("^3@&!8=~*%$0", c) != -1
    "    return "monster"
    "endif
    "if stridx("FSBKLTRAWMG", c) != -1
    "    return "brave"
    "endif
    let unit = s:turnlist.search(a:x, a:y)
    return unit.type
endfunction
" }}}
" move {{{
function! s:field.movable(x, y)
    if !s:field.innerrange(a:x, a:y) | return 0 | endif
    let panel = self.getpanel(a:x, a:y)
    if panel == '.'
        return 1
    endif
    return 0
endfunction
function! s:field.move(fromx, fromy, tox, toy)
    if self.movable(a:tox, a:toy)
        let from = self.getpanel(a:fromx, a:fromy)
        call self.replace(a:tox, a:toy, from)
        call self.replace(a:fromx, a:fromy, '.')
        return 1
    endif
    return 0
endfunction
" }}}
" set max_x & max_y {{{
function! s:field.setmax()
    for f in self.map
        let self.max_x = self.max_x < len(f) ? len(f) : self.max_x
    endfor
    let self.max_y = len(self.map)
endfunction
" }}}
" replace {{{
function! s:field.replace(x, y, c)
    let line = getline(a:y)
    let line = line[: a:x - 2] . a:c . line[a:x :]
    call setline(a:y, line)
    redraw
endfunction
" }}}
" update {{{
function! s:field.update(newfield)
    let self.map = a:newfield
endfunction
" }}}

" keeper
" basic {{{
let s:keeper = { "name": "keeper", "view": "#", "mana": 100, "manaline": 0 }
function! s:keeper.init(x, y)
    let self.x = a:x
    let self.y = a:y
endfunction
function! s:keeper.setmanaline()
    let self.manaline = line('$') + 1
endfunction
function! s:keeper.setmana(mana)
    let self.mana = a:mana
    call setline(self.manaline, '  mana: ' . self.mana)
endfunction
function! s:keeper.getpos()
    return { "x": self.x, "y": self.y }
endfunction
" }}}
" mana charge lost {{{
function! s:keeper.manacharge(m)
    let self.mana += a:m
    call setline(self.manaline, '  mana: ' . self.mana)
endfunction
function! s:keeper.manalost(m)
    let self.mana -= a:m
    call setline(self.manaline, '  mana: ' . self.mana)
endfunction
" }}}
" move up down left right {{{
function! s:keeper.up()
    if s:field.move(self.x, self.y, self.x, self.y -1)
        let self.y -= 1
    endif
endfunction
function! s:keeper.down()
    if s:field.move(self.x, self.y, self.x, self.y +1)
        let self.y += 1
    endif
endfunction
function! s:keeper.left()
    if s:field.move(self.x, self.y, self.x -1, self.y)
        let self.x -= 1
    endif
endfunction
function! s:keeper.right()
    if s:field.move(self.x, self.y, self.x +1, self.y)
        let self.x += 1
    endif
endfunction
function! s:keepermove(aim)
    " 辞書関数を呼ぶための中継
    call s:keeper[a:aim]()
    redraw
endfunction
" }}}
" create monster {{{
function! s:keeper.createmonster()
    let [aimx, aimy] = s:util.getaim(self.x, self.y)
    if s:field.movable(aimx, aimy)
        let mname = s:monster.select()
        let monster = s:monster.create(mname, aimx, aimy)
        if self.mana < monster.cost
            echohl Error
            echo 'shortage mana'
            echohl None
            return
        endif
        call self.manalost(monster.cost)
        call s:field.replace(aimx, aimy, monster.view)
        call s:turnlist.add(monster)
    endif
    echo ''
endfunction
function! s:createmonster()
    " 辞書関数を呼ぶための中継
    call s:keeper.createmonster()
endfunction
" }}}
" destroy monster {{{
function! s:keeper.destroymonster()
    let [aimx, aimy] = s:util.getaim(self.x, self.y)
    let type = s:field.getpaneltype(aimx, aimy)
    if type == "monster"
        let midx = s:turnlist.searchidx(aimx, aimy)
        call self.manacharge(s:turnlist.list[midx].cost / 2)
        call s:turnlist.remove(midx)
        call s:field.replace(aimx, aimy, '.')
    endif
    echo ''
endfunction
function! s:destroymonster()
    " 辞書関数を呼ぶための中継
    call s:keeper.destroymonster()
endfunction
" }}}

" util
" basic {{{
let s:util = {}
let s:util.sleeptime = 100
" }}}
" get aim {{{
function! s:util.getaim(posx, posy) abort
    " ex: let [x, y] = s:util.getaim(self.x, self.y)
    echo '[input aim] select aim <h, j, k, l>'
    let [aimx, aimy] = [a:posx, a:posy]
    let aim = nr2char(getchar())
    if aim == 'h' | let aimx -= 1 | endif
    if aim == 'j' | let aimy += 1 | endif
    if aim == 'k' | let aimy -= 1 | endif
    if aim == 'l' | let aimx += 1 | endif
    echo ''
    return [aimx, aimy]
endfunction
" }}}
" floor {{{
let s:util.floor = { "name": "floor", "view": "." }
function! s:util.getfloor() abort
    return { "name": "floor", "view": "." }
endfunction
" }}}
" getpos(x, y, direction) {{{
function! s:util.getpos(x, y, direction)
    if     a:direction == 0 | return [a:x, a:y - 1]
    elseif a:direction == 1 | return [a:x + 1, a:y]
    elseif a:direction == 2 | return [a:x, a:y + 1]
    elseif a:direction == 3 | return [a:x - 1, a:y]
    else                    | return [a:x, a:y]
    endif
endfunction
" }}}
" who is my near {{{
function! s:util.whonear(x, y)
    let nearlist = []
    let up = s:field.getpaneltype(a:x, a:y - 1)
    let right = s:field.getpaneltype(a:x + 1, a:y)
    let down = s:field.getpaneltype(a:x, a:y + 1)
    let left = s:field.getpaneltype(a:x - 1, a:y)
    if up != 'floor' && up != 'wall'
        call add(nearlist, { "dire": "up", "x": a:x, "y": a:y - 1, "type": up })
    endif
    if right != 'floor' && right != 'wall'
        call add(nearlist, { "dire": "right", "x": a:x + 1, "y": a:y, "type": right })
    endif
    if down != 'floor' && down != 'wall'
        call add(nearlist, { "dire": "down", "x": a:x, "y": a:y + 1, "type": down })
    endif
    if left != 'floor' && left != 'wall'
        call add(nearlist, { "dire": "left", "x": a:x - 1, "y": a:y, "type": left })
    endif
    return nearlist
endfunction
" }}}
" history {{{
let s:util.history = { "hisstart": 0, "hisend": 0, "hisnum": 0, "histories": {} }
function! s:util.history.wherehistoryline(hisnum)
    let self.hisstart = line('$') + 1
    let self.hisend = self.hisstart + a:hisnum + 1
    let self.hisnum = a:hisnum
    let self.histories = Circularly()
    call self.hisredraw()
endfunction
function! s:util.history.newhistory(actor, target, how)
    let hisline = a:actor . ': ' . a:how . ' ' . a:target
    call self.histories.add(hisline)
    call s:allhistories.add(hisline)
    if len(self.histories.list) > self.hisnum
        call self.histories.remove(0)
    endif
    call self.hisredraw()
endfunction
function! s:util.history.hisredraw()
    call setline(self.hisstart, repeat('=', 10) . ' history ' . repeat('=', 10))
    for n in [0, 1, 2]
        let hl = get(self.histories.list, n, '')
        call setline(self.hisstart + 1 + n, hl)
    endfor
    call setline(self.hisend, repeat('=', 29))
    redraw
endfunction
" }}}
" all history <<debug>> {{{
let s:allhistories = { "histories": [] }
function! s:allhistories.add(hist)
    call add(self.histories, a:hist)
endfunction
function! s:allhistories.show()
    silent vnew all-histories
    setl bh=delete bt=nofile nobl noro noswapfile nolist nu nornu cul nocuc
    nnoremap <buffer><silent> q :<C-u>quit<CR>
    for h in self.histories
        call append(0, string(h))
    endfor
endfunction
function! s:histbuffshow()
    call s:allhistories.show()
endfunction
" }}}



""" turn-list {{{
let s:turnlist = Circularly()
function! s:turnlist.search(x, y)
    for s in self.list
        if s.x == a:x && s.y == a:y
            return s
        endif
    endfor
    return 0
endfunction
function! s:turnlist.searchidx(x, y)
    let idx = 0
    for s in self.list
        if s.x == a:x && s.y == a:y
            return idx
        endif
        let idx += 1
    endfor
    return 0
endfunction
" }}}

" TODO: develop
" TEST: use goblin
" unit default actions {{{
let s:default = {}
" default attack {{{
function! s:default.attack()
    let nearlist = s:util.whonear(self.x, self.y)
    let nears = len(nearlist)
    if nears > 0
        let rand = Random(nears)
        let atkx = nearlist[rand].x
        let atky = nearlist[rand].y
        let atktgtidx = s:turnlist.searchidx(atkx, atky)
        let atktgt = s:turnlist.search(atkx, atky)
        if type(atktgt) != v:t_dict | return | endif
        if atktgt.type == self.type | return | endif
        call s:field.replace(atkx, atky, '/')
        call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
        execute('sleep ' . string(s:util.sleeptime) . 'ms')
        let atktgt.life -= 1
        if atktgt.life < 1
            call s:turnlist.remove(atktgtidx)
            call s:keeper.manacharge(atktgt.cost / 2)
            call s:field.replace(atkx, atky, '.')
            call s:util.history.newhistory(atktgt.name, '', 'death')
        else
            let s:turnlist.list[atktgtidx] = atktgt
            call s:field.replace(atkx, atky, atktgt.view)
        endif
        let self.direction = Random(4)
        return 1
    endif
endfunction
" }}}
" default attack without distinction {{{
function! s:default.attack_without_distinction()
    let nearlist = s:util.whonear(self.x, self.y)
    let nears = len(nearlist)
    if nears > 0
        let rand = Random(nears)
        let atkx = nearlist[rand].x
        let atky = nearlist[rand].y
        let atktgtidx = s:turnlist.searchidx(atkx, atky)
        let atktgt = s:turnlist.search(atkx, atky)
        if type(atktgt) != v:t_dict | return | endif
        " without distinction
        "if atktgt.type == self.type | return | endif
        call s:field.replace(atkx, atky, '/')
        call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
        execute('sleep ' . string(s:util.sleeptime) . 'ms')
        let atktgt.life -= 1
        if atktgt.life < 1
            call s:turnlist.remove(atktgtidx)
            call s:keeper.manacharge(atktgt.cost / 2)
            call s:field.replace(atkx, atky, '.')
            call s:util.history.newhistory(atktgt.name, '', 'death')
        else
            let s:turnlist.list[atktgtidx] = atktgt
            call s:field.replace(atkx, atky, atktgt.view)
        endif
        let self.direction = Random(4)
        return 1
    endif
endfunction
" }}}
" attack on confusion {{{
function! s:default.attack_on_confusion()
    let nearlist = s:util.whonear(self.x, self.y)
    let nears = len(nearlist)
    if nears > 0
        let [atkx, atky] = s:util.getpos(self.x, self.y, Random(4))
        let atktgtidx = s:turnlist.searchidx(atkx, atky)
        let atktgt = s:turnlist.search(atkx, atky)
        if type(atktgt) == v:t_dict
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
        else
            " miss attack
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, '', 'attack missed')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            call s:field.replace(atkx, atky, '.')
        endif
        return 1
    endif
endfunction
" }}}
" default move {{{
function! s:default.move()
    let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
    if s:field.move(self.x, self.y, posx, posy)
        let self.x = posx
        let self.y = posy
    else
        let self.direction = Random(4)
    endif
endfunction
" }}}
" default move bound {{{
function! s:default.move_bound()
    let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
    if s:field.move(self.x, self.y, posx, posy)
        let self.x = posx
        let self.y = posy
    else
        let self.direction = (self.direction + 2) % 4
    endif
endfunction
" }}}
" default move clockwise {{{
function! s:default.move_clockwise()
    let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
    if s:field.move(self.x, self.y, posx, posy)
        let self.x = posx
        let self.y = posy
    else
        let self.direction = (self.direction + 1) % 4
    endif
endfunction
" }}}
" default move counter clockwise {{{
function! s:default.move_counter_clockwise()
    let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
    if s:field.move(self.x, self.y, posx, posy)
        let self.x = posx
        let self.y = posy
    else
        let self.direction = (self.direction + 3) % 4
    endif
endfunction
" }}}
" default move randomly {{{
function! s:default.move_randomly()
    let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
    if s:field.move(self.x, self.y, posx, posy)
        let self.x = posx
        let self.y = posy
    endif
    let self.direction = Random(4)
endfunction
" }}}
" default damage {{{
function! s:default.damage()
    " TODO: develop
    echo self
endfunction
" }}}
" default cure {{{
function! s:default.cure()
    " TODO: develop priority-low
    echo self
endfunction
" }}}
" }}}


""" monsters
" monster basic {{{
let s:monster = {}
let s:monster.view = { "bat": "^", "goblin": "@", "fiary": "*", "harpy": "~", "skeleton": "!", "armor": "=",
            \ "witch": "$", "golem": "%", "gengar": "&", "slime": "3", "element": "8", "unknown": "0" }
function! s:monster.select()
    silent vnew select-monster
    setl bh=delete bt=nofile nobl noro noswapfile nolist nu nornu cul nocuc
    for v in keys(self.view)
        call append(0, v)
    endfor
    normal! Gddgg
    redraw
    let m = ''
    let loop = 1
    while loop
        let c = getchar(0)
        if c == 13
            " carriage return
            let m = getline('.')
            let loop = 0
        elseif c == 106
            " j
            call cursor(line('.') + 1, 0)
        elseif c == 107
            " k
            call cursor(line('.') - 1, 0)
        endif
        redraw
    endwhile
    quit
    return m
endfunction
function! s:monster.create(name, x, y)
    let monster = {}
    let mname = 'unknown'
    if has_key(self.view, a:name)
        let mname = a:name
    endif
    let monster = self[mname].create()
    let monster.type = 'monster'
    let monster.x = a:x
    let monster.y = a:y
    let monster.direction = Random(4)
    return monster
endfunction
" }}}
" bat {{{
let s:monster.bat = { "name": "bat", "view": "^", "life": 1, "direction": 0, "cost": 2 }
function! s:monster.bat.create()
    let bat = deepcopy(self)
    function! bat.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    let bat.move = default.move_without_distinction
    let bat.attack = default.attack_on_confusion
    return bat
endfunction
" }}}
" goblin {{{
let s:monster.goblin = { "name": "goblin", "view": "@", "life": 3, "direction": 0, "cost": 6 }
function! s:monster.goblin.create()
    let goblin = deepcopy(self)
    function! goblin.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    let goblin.move = default.move
    let goblin.attack = default.attack
    return goblin
endfunction
" }}}
" fiary {{{
let s:monster.fiary = { "name": "fiary", "view": "*", "life": 2, "direction": 0, "cost": 11 }
function! s:monster.fiary.create()
    let fiary = deepcopy(self)
    function! fiary.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    let fiary.move = default.move_bound
    function! fiary.attack() " unique
        if self.life > 1
            if Random(4) == 0
                call s:keeper.manacharge(1)
                call s:util.history.newhistory(self.name, '', 'mana healing')
            endif
            return 1
        elseif self.life == 1
            if Random(8) == 0
                let self.life += 1
                call s:util.history.newhistory(self.name, '', 'life healing')
                return 1
            endif
        endif
        return 0
    endfunction
    return fiary
endfunction
" }}}
" harpy {{{
let s:monster.harpy = { "name": "harpy", "view": "~", "life": 3, "direction": 0, "cost": 5 }
function! s:monster.harpy.create()
    let harpy = deepcopy(self)
    function! harpy.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    let harpy.move = default.move_randomly
    function! harpy.attack() " unique
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let [atkx, atky] = s:util.getpos(self.x, self.y, Random(4))
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) == v:t_dict
                call s:field.replace(atkx, atky, '/')
                call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
                execute('sleep ' . string(s:util.sleeptime) . 'ms')
                let atktgt.life -= 1
                if atktgt.life < 1
                    call s:turnlist.remove(atktgtidx)
                    call s:keeper.manacharge(atktgt.cost / 2)
                    call s:field.replace(atkx, atky, '.')
                    call s:util.history.newhistory(atktgt.name, '', 'death')
                else
                    let s:turnlist.list[atktgtidx] = atktgt
                    call s:field.replace(atkx, atky, atktgt.view)
                endif
            endif
            return 1
        endif
    endfunction
    return harpy
endfunction
" }}}
" skeleton {{{
let s:monster.skeleton = { "name": "skeleton", "view": "!", "life": 3, "direction": 0, "cost": 7, "rest": 0, "reborn": 11 }
function! s:monster.skeleton.create()
    let skeleton = deepcopy(self)
    function! skeleton.action()
        " uniq skill
        let self.reborn -= 1
        if self.reborn == 0
            let randx = Random(s:field.max_x - 2) + 1
            let randy = Random(s:field.max_y - 2) + 1
            if s:field.getpaneltype(randx, randy) == 'floor'
                let newskel = s:monster.create('skeleton', randx, randy)
                if s:keeper.mana >= newskel.cost
                    call s:keeper.manalost(newskel.cost)
                    call s:field.replace(randx, randy, newskel.view)
                    call s:turnlist.add(newskel)
                    call s:util.history.newhistory(self.name, '', 'reborn')
                endif
            endif
            let self.reborn = (self.life + Random(4)) * 3
        endif
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! skeleton.move()
        if self.rest
            let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
            if s:field.move(self.x, self.y, posx, posy)
                let self.x = posx
                let self.y = posy
            else
                let self.direction = (self.direction + 1) % 4
            endif
        endif
        let self.rest = !self.rest
    endfunction
    function! skeleton.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                let newskel = s:monster.create('skeleton', atkx, atky)
                call s:turnlist.add(newskel)
                call s:field.replace(atkx, atky, newskel.view)
                call s:util.history.newhistory(atktgt.name, newskel.name, 'death & reborn as')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return skeleton
endfunction
" }}}
" armor {{{
let s:monster.armor = { "name": "armor", "view": "=", "life": 9, "direction": 0, "cost": 17 }
function! s:monster.armor.create()
    let armor = deepcopy(self)
    function! armor.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! armor.move()
        if self.life > 3
            let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
            if s:field.move(self.x, self.y, posx, posy)
                let self.x = posx
                let self.y = posy
            else
                let self.direction = (self.direction + 1) % 4
            endif
        endif
    endfunction
    function! armor.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return armor
endfunction
" }}}
" witch {{{
let s:monster.witch = { "name": "witch", "view": "$", "life": 3, "direction": 0, "cost": 8, "rest": 0 }
function! s:monster.witch.create()
    let witch = deepcopy(self)
    function! witch.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! witch.move()
        if self.rest
            if Random(6) == 0
                let self.rest = !self.rest
                let [unkx, unky] = s:util.getpos(self.x, self.y, Random(4))
                if s:field.getpaneltype(unkx, unky) == 'floor'
                    let unk = s:monster.create('unknown', unkx, unky)
                    if s:keeper.mana < unk.cost
                        return
                    endif
                    call s:keeper.manalost(unk.cost)
                    call s:field.replace(unkx, unky, unk.view)
                    call s:turnlist.add(unk)
                    call s:util.history.newhistory(self.name, 'unknown', 'create')
                endif
                return
            endif
            let randx = Random(5) - 2
            let randy = Random(5) - 2
            if randx == 0 && randy == 0
                let self.rest = !self.rest
                return
            endif
            let [posx, posy] = [self.x + randx, self.y + randy]
            if s:field.move(self.x, self.y, posx, posy)
                let self.x = posx
                let self.y = posy
            endif
        endif
        let self.rest = !self.rest
    endfunction
    function! witch.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return witch
endfunction
" }}}
" golem {{{
let s:monster.golem = { "name": "golem", "view": "%", "life": 13, "direction": 0, "cost": 21, "rest": 0 }
function! s:monster.golem.create()
    let golem = deepcopy(self)
    function! golem.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! golem.move()
        " not move
    endfunction
    function! golem.attack()
        if self.rest
            let self.rest = !self.rest
            return
        endif
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 2
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            let self.rest = !self.rest
            return 1
        endif
    endfunction
    return golem
endfunction
" }}}
" gengar {{{
let s:monster.gengar = { "name": "gengar", "view": "&", "life": 7, "direction": 0, "cost": 14 }
function! s:monster.gengar.create()
    let gengar = deepcopy(self)
    function! gengar.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! gengar.move()
        let randx = Random(3) - 1
        let randy = Random(3) - 1
        if randx == 0 && randy == 0
            return
        endif
        let [posx, posy] = [self.x + randx, self.y + randy]
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        endif
    endfunction
    function! gengar.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return Random(2)
        endif
    endfunction
    return gengar
endfunction
" }}}
" slime {{{
let s:monster.slime = { "name": "slime", "view": "3", "life": 2, "direction": 0, "cost": 4 }
function! s:monster.slime.create()
    let slime = deepcopy(self)
    function! slime.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! slime.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = (self.direction + 1) % 4
        endif
    endfunction
    function! slime.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            " not distinction
            "if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
                " uniq skill
                if Random(4) != 0 | return | endif
                let [divx, divy] = s:util.getpos(atkx, atky, Random(4))
                if s:field.getpaneltype(divx, divy) == 'floor'
                    let division = s:monster.create('slime', divx, divy)
                    let division.cost = division.cost / 2
                    if s:keeper.mana < division.cost
                        return
                    endif
                    call s:keeper.manalost(division.cost)
                    call s:field.replace(divx, divy, division.view)
                    call s:turnlist.add(division)
                    call s:util.history.newhistory(self.name, '', 'divisioned')
                endif
            endif
            return 1
        endif
    endfunction
    return slime
endfunction
" }}}
" element {{{
let s:monster.element = { "name": "element", "view": "8", "life": 5, "direction": 0, "cost": 10 }
function! s:monster.element.create()
    let element = deepcopy(self)
    function! element.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! element.move()
        let elex = Random(s:field.max_x - 2) + 1
        let eley = Random(s:field.max_y - 2) + 1
        if s:field.move(self.x, self.y, elex, eley)
            let self.x = elex
            let self.y = eley
        endif
    endfunction
    function! element.attack()
        let rand3 = Random(3)
        let rand7 = Random(7)
        let ret = 0
        if rand3 == 0
            let unitnum = len(s:turnlist.list)
            let unitidx = Random(unitnum)
            let unit = s:turnlist.list[unitidx]
            if unit.type == self.type
                let s:turnlist.list[unitidx].life += 1
                call s:util.history.newhistory(self.name, unit.name, 'life heal to')
            endif
            let ret = 1
        endif
        if rand7 == 0
            let unitnum = len(s:turnlist.list)
            let unitidx = Random(unitnum)
            let unit = s:turnlist.list[unitidx]
            if unit.type != self.type
                call s:field.replace(unit.x, unit.y, '/')
                call s:util.history.newhistory(self.name, unit.name, 'attack to')
                execute('sleep ' . string(s:util.sleeptime) . 'ms')
                let unit.life -= 1
                if unit.life < 1
                    call s:turnlist.remove(unitidx)
                    call s:keeper.manacharge(unit.cost / 2)
                    call s:field.replace(unit.x, unit.y, '.')
                    call s:util.history.newhistory(unit.name, '', 'death')
                else
                    call s:field.replace(unit.x, unit.y, unit.view)
                endif
            endif
            let ret = 1
        endif
        return ret
    endfunction
    return element
endfunction
" }}}
" unknown {{{
let s:monster.unknown = { "name": "unknown", "view": "0", "life": 1, "direction": 0, "cost": 7, "promotion": 0 }
function! s:monster.unknown.create()
    let unknown = deepcopy(self)
    let unknown.promotion = Random(8) + 4
    function! unknown.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! unknown.move()
        " undecided
    endfunction
    function! unknown.attack()
        let self.promotion -= 1
        if self.promotion == 0
            let mlist = keys(s:monster.view)
            let mlistnum = len(mlist)
            let mname = mlist[Random(mlistnum)]
            let m = s:monster[mname].create()
            let m.type = self.type
            let m.direction = Random(4)
            let m.x = self.x
            let m.y = self.y
            let myidx = s:turnlist.searchidx(self.x, self.y)
            call s:turnlist.remove(myidx)
            call s:turnlist.add(m)
            call s:field.replace(self.x, self.y, m.view)
            call s:util.history.newhistory(self.name, m.name, 'promotion to')
        endif
    endfunction
    return unknown
endfunction
" }}}


""" braves
" brave basic {{{
let s:brave = {}
let s:brave.view = { "fighter": "F", "sword": "S", "bishop": "B", "kid": "K", "lancer": "L", "tamer": "T",
            \ "rook": "R", "assassin": "A", "wizard": "W", "magician": "M", "criminal": "C" }
function! s:brave.create()
    let blist = keys(self.view)
    let blistnum = len(blist)
    let bname = blist[Random(blistnum)]
    let b = self[bname].create()
    let b.type = 'brave'
    let b.direction = Random(4)
    return b
endfunction
" }}}
" fighter {{{
let s:brave.fighter = { "name": "fighter", "view": "F", "life": 4, "direction": 0, "cost": 4 }
function! s:brave.fighter.create()
    let fighter = deepcopy(self)
    function! fighter.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! fighter.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! fighter.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            return Random(2)
        endif
    endfunction
    return fighter
endfunction
" }}}
" sword {{{
let s:brave.sword = { "name": "sword", "view": "S", "life": 5, "direction": 0, "cost": 4 }
function! s:brave.sword.create()
    let sword = deepcopy(self)
    function! sword.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! sword.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! sword.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return sword
endfunction
" }}}
" bishop {{{
let s:brave.bishop = { "name": "bishop", "view": "B", "life": 3, "direction": 0, "cost": 4 }
function! s:brave.bishop.create()
    let bishop = deepcopy(self)
    function! bishop.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! bishop.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! bishop.attack()
        let rand4 = Random(4)
        let rand5 = Random(5)
        if rand4 == 0
            let unitnum = len(s:turnlist.list)
            let unitidx = Random(unitnum)
            let unit = s:turnlist.list[unitidx]
            if unit.type == self.type
                let s:turnlist.list[unitidx].life += 1
                call s:util.history.newhistory(self.name, unit.name, 'life heal to')
            endif
            return 1
        endif
        if rand5 == 0
            let nearlist = s:util.whonear(self.x, self.y)
            let nears = len(nearlist)
            if nears > 0
                let rand = Random(nears)
                let atkx = nearlist[rand].x
                let atky = nearlist[rand].y
                let atktgtidx = s:turnlist.searchidx(atkx, atky)
                let atktgt = s:turnlist.search(atkx, atky)
                if type(atktgt) != v:t_dict | return | endif
                if atktgt.type == self.type | return | endif
                call s:field.replace(atkx, atky, '/')
                call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
                execute('sleep ' . string(s:util.sleeptime) . 'ms')
                " uniq skill
                if atktgt.name == 'skeleton' || atktgt.name == 'armor'
                    let atktgt.life -= 3
                elseif atktgt.name == 'gengar' || atktgt.name == 'witch'
                    let atktgt.life -= 2
                elseif atktgt.name == 'fiary' || atktgt.name == 'element'
                    let atktgt.life += 1
                else
                    let atktgt.life -= 1
                endif
                if atktgt.life < 1
                    call s:turnlist.remove(atktgtidx)
                    call s:keeper.manacharge(atktgt.cost / 2)
                    call s:field.replace(atkx, atky, '.')
                    call s:util.history.newhistory(atktgt.name, '', 'death')
                else
                    let s:turnlist.list[atktgtidx] = atktgt
                    call s:field.replace(atkx, atky, atktgt.view)
                endif
                let self.direction = Random(4)
                return 1
            endif
        endif
        return 0
    endfunction
    return bishop
endfunction
" }}}
" kid {{{
let s:brave.kid = { "name": "kid", "view": "K", "life": 1, "direction": 0, "cost": 2, "step": 3 }
function! s:brave.kid.create()
    let kid = deepcopy(self)
    function! kid.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! kid.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
            let self.step -= 1
            if self.step == 0
                let self.direction = Random(4)
                let self.step = 3
            endif
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! kid.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            " not distinction
            "if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= Random(2)
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            return 1
        endif
    endfunction
    return kid
endfunction
" }}}
" lancer {{{
let s:brave.lancer = { "name": "lancer", "view": "L", "life": 6, "direction": 0, "cost": 6 }
function! s:brave.lancer.create()
    let lancer = deepcopy(self)
    function! lancer.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! lancer.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! lancer.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            " uniq skill
            let [atkx2, atky2] = s:util.getpos(atkx, atky, self.direction)
            if s:field.getpaneltype(atkx2, atky2) != self.type
                let atktgtidx2 = s:turnlist.searchidx(atkx2, atky2)
                let atktgt2 = s:turnlist.search(atkx2, atky2)
                if type(atktgt2) != v:t_dict | return | endif
                if atktgt2.type == self.type | return | endif
                call s:field.replace(atkx2, atky2, '/')
                call s:util.history.newhistory(self.name, atktgt2.name, 'attack to')
                execute('sleep ' . string(s:util.sleeptime) . 'ms')
                let atktgt2.life -= 1
                if atktgt2.life < 1
                    call s:turnlist.remove(atktgtidx2)
                    call s:keeper.manacharge(atktgt2.cost / 2)
                    call s:field.replace(atkx2, atky2, '.')
                    call s:util.history.newhistory(atktgt2.name, '', 'death')
                else
                    let s:turnlist.list[atktgtidx2] = atktgt2
                    call s:field.replace(atkx2, atky2, atktgt2.view)
                endif
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return lancer
endfunction
" }}}
" tamer {{{
let s:brave.tamer = { "name": "tamer", "view": "T", "life": 3, "direction": 0, "cost": 7 }
function! s:brave.tamer.create()
    let tamer = deepcopy(self)
    function! tamer.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! tamer.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! tamer.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            " uniq skill
            let rand3 = Random(3)
            let rand5 = Random(5)
            let rand7 = Random(7)
            if (rand3 + rand7) < 2
                let s:turnlist.list[atktgtidx].type = self.type
                call s:util.history.newhistory(self.name, atktgt.name, 'tame to')
                return 1
            endif
            if (rand3 + rand5) < 3
                return 1
            endif
            if (rand3 + rand5 + rand7) < 7
                call s:field.replace(atkx, atky, '/')
                call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
                execute('sleep ' . string(s:util.sleeptime) . 'ms')
                let atktgt.life -= 1
                if atktgt.life < 1
                    call s:turnlist.remove(atktgtidx)
                    call s:keeper.manacharge(atktgt.cost / 2)
                    call s:field.replace(atkx, atky, '.')
                    call s:util.history.newhistory(atktgt.name, '', 'death')
                else
                    let s:turnlist.list[atktgtidx] = atktgt
                    call s:field.replace(atkx, atky, atktgt.view)
                endif
                let self.direction = Random(4)
                return 1
            endif
            return 0
        endif
    endfunction
    return tamer
endfunction
" }}}
" rook {{{
let s:brave.rook = { "name": "rook", "view": "R", "life": 4, "direction": 0, "cost": 3 }
function! s:brave.rook.create()
    let rook = deepcopy(self)
    function! rook.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! rook.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! rook.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return rook
endfunction
" }}}
" assassin {{{
let s:brave.assassin = { "name": "assassin", "view": "A", "life": 3, "direction": 0, "cost": 5 }
function! s:brave.assassin.create()
    let assassin = deepcopy(self)
    function! assassin.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! assassin.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! assassin.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= Random(3)
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return assassin
endfunction
" }}}
" wizard {{{
let s:brave.wizard = { "name": "wizard", "view": "W", "life": 3, "direction": 0, "cost": 5 }
function! s:brave.wizard.create()
    let wizard = deepcopy(self)
    function! wizard.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! wizard.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! wizard.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears == 0
            " uniq skill
            let rand = Random(3)
            if rand == 1
                if Random(2)
                    let self.life += 1
                    let self.cost += 1
                    return 1
                endif
            endif
            if rand == 2
                let manadamage = Random(self.life)
                call s:keeper.manalost(manadamage)
                if s:keeper.mana < 0
                    call s:keeper.setmana(0)
                endif
                call s:util.history.newhistory(self.name, '', 'mana attack')
                return 1
            endif
            return 0
        endif
        if Random(3)
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            " not distinction
            "if atktgt.type == self.type | return | endif
            let self.direction = Random(4)
            " uniq skill
            let lifebuf = atktgt.life
            let costbuf = atktgt.cost
            let typebuf = atktgt.type
            let mlist = keys(s:monster.view)
            let mlistnum = len(mlist)
            let mname = mlist[Random(mlistnum)]
            let m = s:monster[mname].create()
            let m.life = lifebuf
            let m.cost = costbuf
            let m.type = typebuf
            let m.direction = Random(4)
            let m.x = atkx
            let m.y = atky
            call s:turnlist.remove(atktgtidx)
            call s:turnlist.add(m)
            call s:field.replace(atkx, atky, m.view)
            call s:util.history.newhistory(self.name, '', 'transform magic')
            return 1
        endif
    endfunction
    return wizard
endfunction
" }}}
" magician {{{
let s:brave.magician = { "name": "magician", "view": "M", "life": 2, "direction": 0, "cost": 4 }
function! s:brave.magician.create()
    let magician = deepcopy(self)
    function! magician.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! magician.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        else
            let self.direction = Random(4)
        endif
    endfunction
    function! magician.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return magician
endfunction
" }}}
" criminal {{{
let s:brave.criminal = { "name": "criminal", "view": "C", "life": 5, "direction": 0, "cost": 6 }
function! s:brave.criminal.create()
    let criminal = deepcopy(self)
    function! criminal.action()
        if !self.attack()
            call self.move()
        endif
    endfunction
    function! criminal.move()
        let [posx, posy] = s:util.getpos(self.x, self.y, self.direction)
        if s:field.move(self.x, self.y, posx, posy)
            let self.x = posx
            let self.y = posy
        endif
        let self.direction = Random(4)
    endfunction
    function! criminal.attack()
        let nearlist = s:util.whonear(self.x, self.y)
        let nears = len(nearlist)
        if nears > 0
            let rand = Random(nears)
            let atkx = nearlist[rand].x
            let atky = nearlist[rand].y
            let atktgtidx = s:turnlist.searchidx(atkx, atky)
            let atktgt = s:turnlist.search(atkx, atky)
            if type(atktgt) != v:t_dict | return | endif
            if atktgt.type == self.type | return | endif
            if Random(3)
                " uniq skill
                let self.type = atktgt.type
                return 1
            endif
            call s:field.replace(atkx, atky, '/')
            call s:util.history.newhistory(self.name, atktgt.name, 'attack to')
            execute('sleep ' . string(s:util.sleeptime) . 'ms')
            let atktgt.life -= 1
            if atktgt.life < 1
                call s:turnlist.remove(atktgtidx)
                call s:keeper.manacharge(atktgt.cost / 2)
                call s:field.replace(atkx, atky, '.')
                call s:util.history.newhistory(atktgt.name, '', 'death')
            else
                let s:turnlist.list[atktgtidx] = atktgt
                call s:field.replace(atkx, atky, atktgt.view)
            endif
            let self.direction = Random(4)
            return 1
        endif
    endfunction
    return criminal
endfunction
" }}}

" dungeon make {{{
command! DungeonMake call s:dungeon_make()
function! s:dungeon_make() abort
    tabnew dungeon

    " setlocal {{{
    setlocal bufhidden=delete
    setlocal buftype=nofile
    setlocal nobuflisted
    setlocal noreadonly
    setlocal noswapfile
    setlocal nolist
    setlocal number norelativenumber
    setlocal nocursorline nocursorcolumn
    " }}}

    call s:field.setmax()
    call s:field.reset()
    call s:keeper.init(3, 5)
    call s:keeper.setmanaline()
    call s:keeper.setmana(100)
    call s:util.history.wherehistoryline(3)
    call s:field.replace(3, 5, '#')

    " high light {{{
    syntax match dungeonWall /[+-|]/
    syntax match dungeonFloor /\./
    syntax match dungeonKeeper /#/
    syntax match dungeonMonster /[\^3\@\&\!8\=\~\*\%\$]/
    syntax match dungeonBrave /[FSBKLTRAWMC]/
    syntax match dungeonAttack /\//
    hi link dungeonWall String
    hi link dungeonFloor Normal
    hi link dungeonKeeper Boolean
    hi link dungeonMonster String
    hi link dungeonBrave Number
    hi link dungeonAttack Error
    " }}}

    """ mapping
    " keeper move {{{
    nnoremap <buffer><silent> h :call <SID>keepermove('left')<CR>
    nnoremap <buffer><silent> j :call <SID>keepermove('down')<CR>
    nnoremap <buffer><silent> k :call <SID>keepermove('up')<CR>
    nnoremap <buffer><silent> l :call <SID>keepermove('right')<CR>
    nnoremap <buffer><silent> <LEFT> :call <SID>keepermove('left')<CR>
    nnoremap <buffer><silent> <DOWN> :call <SID>keepermove('down')<CR>
    nnoremap <buffer><silent> <UP> :call <SID>keepermove('up')<CR>
    nnoremap <buffer><silent> <RIGHT> :call <SID>keepermove('right')<CR>
    " }}}

    " monster create {{{
    nnoremap <buffer><silent> c :call <SID>createmonster()<CR>
    " }}}
    " monster destroy {{{
    nnoremap <buffer><silent> d :call <SID>destroymonster()<CR>
    " }}}

    " brave turn {{{
    nnoremap <buffer><silent> e :call <SID>braveturn()<CR>
    " }}}

    " turn list appear {{{
    nnoremap <buffer><silent> t :call <SID>turnlistappear()<CR>
    " }}}

    " sleep time fasten or slowen {{{
    nnoremap <buffer><silent> f :call <SID>sleeptimefasten()<CR>
    nnoremap <buffer><silent> s :call <SID>slleptimeslowen()<CR>
    " }}}

    " history {{{
    nnoremap <buffer><silent> b :call <SID>histbuffshow()<CR>
    " }}}

endfunction
" }}}


" brave turn {{{
function! s:braveturn()
    " keeper hide
    call s:field.replace(s:keeper.x, s:keeper.y, '.')

    " brave appear
    let bravenum = (len(s:turnlist.list) / 2) + Random(3)
    let b_x = Random(s:field.max_x - 2) + 1
    let b_y = Random(s:field.max_y - 2) + 1
    for bn in range(1, bravenum)
        let b = s:brave.create()
        let bloop = 1
        while bloop
            if s:field.getpaneltype(b_x, b_y) == 'floor'
                let b.x = b_x
                let b.y = b_y
                call s:field.replace(b_x, b_y, b.view)
                call s:turnlist.add(b)
                let bloop = 0
            endif
            let b_x += Random(3) - 1
            let b_y += Random(3) - 1
            if b_x < 2 | let b_x += 3 | endif
            if b_y < 2 | let b_y += 3 | endif
            if s:field.max_x < b_x | let b_x -= 3 | endif
            if s:field.max_y < b_y | let b_y -= 3 | endif
        endwhile
    endfor

    " turnlist random sort
    let s:turnlist.list = Shuffle(s:turnlist.list)

    " battle start
    let loop = 1
    while loop
        let order = nr2char(getchar(0))
        if order == 'q' | let loop = 0 | endif
        if order == 'f' | call s:sleeptimefasten() | endif
        if order == 's' | call s:sleeptimeslowen() | endif
        call s:turnlist.list[0].action()
        call s:turnlist.next()
        execute('sleep ' . string(s:util.sleeptime) . 'ms')
    endwhile

    " keeper appear
    let loop = 1
    while loop
        if s:field.getpaneltype(s:keeper.x, s:keeper.y) == 'floor'
            call s:field.replace(s:keeper.x, s:keeper.y, s:keeper.view)
            let loop = 0
        else
            let s:keeper.x += Random(3) - 1
            let s:keeper.y += Random(3) - 1
        endif
    endwhile
endfunction
" }}}

" turn list appear {{{
function! s:turnlistappear()
    silent vnew turn-list
    setl bh=delete bt=nofile nobl noro noswapfile nolist nu nornu cul nocuc
    nnoremap <buffer><silent> q :<C-u>quit<CR>
    let line = ''
    for t in s:turnlist.list
        let line = '<< ' . t.type . ' >>' . repeat(' ', 10)
        let line = line[: 15] . t.name . repeat(' ', 10)
        let line = line[: 25] . '[' . t.view . '] ' . repeat(' ', 5)
        let line = line[: 30] . 'x: ' . t.x . repeat(' ', 10)
        let line = line[: 40] . 'y: ' . t.y . repeat(' ', 10)
        let line = line[: 50] . 'life: ' . t.life
        call append(0, line)
    endfor
endfunction
" }}}

" fast and slow {{{
function! s:sleeptimefasten()
    let s:util.sleeptime -= 10
    if s:util.sleeptime < 10
        let s:util.sleeptime = 10
    endif
endfunction
function! s:sleeptimeslowen()
    let s:util.sleeptime += 10
    if s:util.sleeptime > 200
        let s:util.sleeptime = 200
    endif
endfunction
" }}}


