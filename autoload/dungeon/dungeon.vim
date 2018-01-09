" Vim plugin script
" File: dungeon/dungeon.vim
" Summary: dungeon keeper on Vim
" Authors: rozeroze <rosettastone1886@gmail.com>
" License: undecided
" Version: 2018-1-1


" dungeon#dungeon#make(...) {{{
function! dungeon#dungeon#make(...)
   let init = g:dungeon#dungeon#getstarter(a:000)
   call g:dungeon#dungeon#field.tabopen()
   call g:dungeon#dungeon#field.mapmake()
   call g:dungeon#dungeon#field.setmax()
   call g:dungeon#dungeon#field.reset()
   call g:dungeon#dungeon#keeper.init(init.keeper_x, init.keeper_y)
   call g:dungeon#dungeon#field.replace(init.keeper_x, init.keeper_y, g:dungeon#dungeon#keeper.view)
   call g:dungeon#dungeon#mana.init()
   call g:dungeon#dungeon#mana.setmana(init.mana)
   call g:dungeon#dungeon#history.init(init.history_line)
   "call g:dungeon#dungeon#config.command()
endfunction
" }}}


""" starter
" dungeon#dungeon#getstarter{{{
function dungeon#dungeon#getstarter(...)
   let starter = {}
   let starter.keeper_x = 3
   let starter.keeper_y = 5
   let starter.mana = 100
   let starter.history_line = 3
   if a:0 > 0 && type(a:1) == v:t_dict
      if has_key(a:1, 'keeper_x')
         let starter.keeper_x = a:1['keeper_x']
      endif
      if has_key(a:1, 'keeper_y')
         let starter.keeper_y = a:1['keeper_y']
      endif
      if has_key(a:1, 'mana')
         let starter.mana = a:1['mana']
      endif
      if has_key(a:1, 'history_line')
         let starter.history_line = a:1['history_line']
      endif
   endif
   return starter
endfunction
" }}}


""" field
" let g:dungeon#dungeon#field {{{
let g:dungeon#dungeon#field = {}
let g:dungeon#dungeon#field.map = []
let g:dungeon#dungeon#field.max_x = 0
let g:dungeon#dungeon#field.max_y = 0
" }}}
" dungeon#dungeon#field.tabopen() {{{
function! dungeon#dungeon#field.tabopen()
   tabnew dungeon
   setlocal filetype=dungeon
   setlocal bufhidden=delete
   setlocal buftype=nofile
   setlocal nobuflisted
   setlocal noreadonly
   setlocal noswapfile
   setlocal nolist
   setlocal number norelativenumber
   setlocal nocursorline nocursorcolumn
endfunction
" }}}
" dungeon#dungeon#field.mapmake() {{{
function! dungeon#dungeon#field.mapmake()
   let g:dungeon#dungeon#field.map = [
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
            \   ]
   " Supplement: the panel where is left top. character is '+'
   " +------+      parameter:  x => 1,  y => 1
   " |......|    the keeper whoes character is '#'
   " |..#...|      parameter:  x => 4,  y => 3
   " |......|
   " +------+
endfunction
" }}}
" dungeon#dungeon#field.setmax() {{{
function! dungeon#dungeon#field.setmax()
   let x = 0
   for row in g:dungeon#dungeon#field.map
      let x = x < len(row) ? len(row) : x
   endfor
   let g:dungeon#dungeon#field.max_x = x
   let g:dungeon#dungeon#field.max_y = len(g:dungeon#dungeon#field.map)
endfunction
" }}}
" dungeon#dungeon#field.reset() {{{
function! dungeon#dungeon#field.reset()
   normal! ggdG
   for row in g:dungeon#dungeon#field.map
      call append(0, row)
   endfor
   normal! Gddgg
endfunction
" }}}
" dungeon#dungeon#field.getpanel(x, y) {{{
function! dungeon#dungeon#field.getpanel(x, y)
   let exists = g:dungeon#dungeon#turnlist.exists(a:x, a:y)
   if exists
      let unit = g:dungeon#dungeon#turnlist.search(a:x, a:y)
      return unit
   endif
   let c = g:dungeon#dungeon#field.getpanelview(a:x, a:y)
   if stridx("+-|", c) != -1
      return g:dungeon#dungeon#config.getwall()
   endif
   if stridx(".", c) != -1
      return g:dungeon#dungeon#config.getfloor()
   endif
   return g:dungeon#dungeon#config.getunknown()
endfunction
" }}}
" dungeon#dungeon#field.getpanelview(x, y) {{{
function! dungeon#dungeon#field.getpanelview(x, y)
   return getline(a:y)[a:x - 1]
endfunction
" }}}
" dungeon#dungeon#field.getpaneltype(x, y) {{{
function! dungeon#dungeon#field.getpaneltype(x, y)
   let exists = g:dungeon#dungeon#turnlist.exists(a:x, a:y)
   if exists
      let unit = g:dungeon#dungeon#turnlist.search(a:x, a:y)
      return unit.type
   endif
   let c = g:dungeon#dungeon#field.getpanelview(a:x, a:y)
   if stridx("+-|", c) != -1
      return "wall"
   endif
   if stridx(".", c) != -1
      return "floor"
   endif
   return "unknown"
endfunction
" }}}
" dungeon#dungeon#field.replace(x, y, c) {{{
function! dungeon#dungeon#field.replace(x, y, c)
   " map変数の更新
   let maprow = g:dungeon#dungeon#field.map[a:y - 1]
   let maprow = maprow[:a:x - 2] . a:c . maprow[a:x :]
   let g:dungeon#dungeon#field.map[a:y - 1] = maprow
   " 実際の表示部分の更新
   let line = getline(a:y)
   let line = line[: a:x - 2] . a:c . line[a:x :]
   call setline(a:y, line)
   redraw
endfunction
" }}}
" dungeon#dungeon#field.inner(x, y) {{{
function! dungeon#dungeon#field.inner(x, y)
   if a:x < 1 || g:dungeon#dungeon#field.max_x < a:x | return 0 | endif
   if a:y < 1 || g:dungeon#dungeon#field.max_y < a:y | return 0 | endif
   return 1
endfunction
" }}}
" dungeon#dungeon#field.isfloor(x, y) {{{
function! dungeon#dungeon#field.isfloor(x, y)
   if g:dungeon#dungeon#field.inner(a:x, a:y)
      let panel = g:dungeon#dungeon#field.getpaneltype(a:x, a:y)
      return panel == "floor"
   endif
   return 0
endfunction
" }}}
" dungeon#dungeon#field.interchange(fromx, fromy, tox, toy) {{{
function! dungeon#dungeon#field.interchange(fromx, fromy, tox, toy)
   let from = g:dungeon#dungeon#field.getpanelview(fromx, fromy)
   let to = g:dungeon#dungeon#field.getpanelview(tox, toy)
   call g:dungeon#dungeon#field.replace(fromx, fromy, to)
   call g:dungeon#dungeon#field.replace(tox, toy, from)
   redraw
endfunction
" }}}


""" turnlist
" let g:dungeon#dungeon#turnlist {{{
let g:dungeon#dungeon#turnlist = {}
let g:dungeon#dungeon#turnlist.list = []
" }}}
" dungeon#dungeon#turnlist.list(...) {{{
function! dungeon#dungeon#turnlist.init(...)
   if a:0 == 0
      let g:dungeon#dungeon#turnlist.list = []
      return
   endif
   if type(a:1) == v:t_list
      let g:dungeon#dungeon#turnlist.list = a:1
   else
      let g:dungeon#dungeon#turnlist.list = a:000
   endif
endfunction
" }}}
" dungeon#dungeon#turnlist.append(who) {{{
" リストの末尾に追加
function! dungeon#dungeon#turnlist.append(who)
   call add(g:dungeon#dungeon#turnlist.list, a:who)
endfunction
" }}}
" dungeon#dungeon#turnlist.interrupt(who, where) {{{
" リストの任意の場所に追加
function! dungeon#dungeon#turnlist.interrupt(who, where)
   call insert(g:dungeon#dungeon#turnlist.list, a:who, a:where)
endfunction
" }}}
" dungeon#dungeon#turnlist.remove(what) {{{
" リストから削除
function! dungeon#dungeon#turnlist.remove(what)
   let type = type(a:what)
   if type == v:t_number
      call g:dungeon#dungeon#turnlist.dropout(a:what)
   elseif type == v:t_dict
      call g:dungeon#dungeon#turnlist.death(a:what)
   else
      "throw 'g:dungeon#dungeon#turnlist.remove argument error'
   endif
endfunction
" }}}
" dungeon#dungeon#turnlist.death(who) {{{
" リストから対象を削除
function! dungeon#dungeon#turnlist.death(who)
   " TODO:
endfunction
" }}}
" dungeon#dungeon#turnlist.dropout(where) {{{
" リストの任意の場所の対象を削除
function! dungeon#dungeon#turnlist.dropout(where)
   call remove(g:dungeon#dungeon#turnlist.list, a:where)
endfunction
" }}}
" dungeon#dungeon#turnlist.get(where) {{{
" リストの任意の場所の対象を取得
function! dungeon#dungeon#turnlist.get(where)
   return g:dungeon#dungeon#turnlist.list[a:where]
endfunction
" }}}
" dungeon#dungeon#turnlist.first() {{{
" リストの最初の要素を取得
function! dungeon#dungeon#turnlist.first()
   return g:dungeon#dungeon#turnlist.get(0)
endfunction
" }}}
" dungeon#dungeon#turnlist.last() {{{
" リストの最後の要素を取得
function! dungeon#dungeon#turnlist.last()
   return g:dungeon#dungeon#turnlist.get(-1)
endfunction
" }}}
" dungeon#dungeon#turnlist.exists(x, y) {{{
" リストに条件の要素があるか
function! dungeon#dungeon#turnlist.exists(x, y)
   let unit = g:dungeon#dungeon#turnlist.search(a:x, a:y)
   return type(unit) == v:t_dict
endfunction
" }}}
" dungeon#dungeon#turnlist.search(x, y) {{{
" リストの要素を検索
function! dungeon#dungeon#turnlist.search(x, y)
   for u in g:dungeon#dungeon#turnlist.list
      if u.x == a:x && u.y == a:y
         return u
      endif
   endfor
   return v:false
endfunction
" }}}
" dungeon#dungeon#turnlist.identify(id) {{{
function! dungeon#dungeon#turnlist.identify(id)
   for u in g:dungeon#dungeon#turnlist.list
      if u.id == a:id
         return u
      endif
   endfor
   return v:false
endfunction
" }}}
" dungeon#dungeon#turnlist.move(num) {{{
" リストを動かす
function! dungeon#dungeon#turnlist.move(num)
   if type(a:num) != v:t_number
      "throw 'g:dungeon#dungeon#turnlist.move argument error'
   endif
   if a:num == 0
      " not move
      return
   endif
   if a:num > 0
      call g:dungeon#dungeon#turnlist.next(a:num)
   else
      call g:dungeon#dungeon#turnlist.prev(a:num * -1)
   endif
endfunction
" }}}
" dungeon#dungeon#turnlist.next(loop) {{{
" リストを進める(最初の要素を最後に移動)
function! dungeon#dungeon#turnlist.next(loop)
   if a:loop == 0 | return | endif
   let who = g:dungeon#dungeon#turnlist.first()
   call g:dungeon#dungeon#turnlist.dropout(0)
   call g:dungeon#dungeon#turnlist.append(who)
   call g:dungeon#dungeon#turnlist.next(a:loop - 1)
endfunction
" }}}
" dungeon#dungeon#turnlist.prev(loop) {{{
" リストを戻す(最後の要素を最初に移動)
function! dungeon#dungeon#turnlist.prev(loop)
   if a:loop == 0 | return | endif
   let who = g:dungeon#dungeon#turnlist.last()
   call g:dungeon#dungeon#turnlist.dropout(-1)
   call g:dungeon#dungeon#turnlist.append(who)
   call g:dungeon#dungeon#turnlist.next(a:loop - 1)
endfunction
" }}}
" dungeon#dungeon#turnlist.shuffle() {{{
" リストをシャッフル
function! dungeon#dungeon#turnlist.shuffle()
   let len = len(g:dungeon#dungeon#turnlist.list)
   let sqrt = float2nr(ceil(sqrt(len)))
   while sqrt
      call g:dungeon#dungeon#turnlist.next(sqrt)
      call sort(g:dungeon#dungeon#turnlist.list, 'g:dungeon#dungeon#turnlist.shufflefunc')
      let sqrt -= 1
   endwhile
endfunction
" }}}
" dungeon#dungeon#turnlist.shufflefunc(a, b) {{{
function! dungeon#dungeon#turnlist.shufflefunc(a, b)
   let len = len(g:dungeon#dungeon#turnlist.list)
   return (reltimestr(reltime())[-2:] % len) - (len / 2)
endfunction
" }}}


""" unit
" let g:dungeon#dungeon#unit {{{
let g:dungeon#dungeon#unit = {}
let g:dungeon#dungeon#unit.id = 1
let g:dungeon#dungeon#unit.name = 'default-unit'
let g:dungeon#dungeon#unit.view = 'u'
let g:dungeon#dungeon#unit.side = 'monster or brave'
let g:dungeon#dungeon#unit.life = 0
let g:dungeon#dungeon#unit.direction = 0
let g:dungeon#dungeon#unit.cost = 0
let g:dungeon#dungeon#unit.x = 0
let g:dungeon#dungeon#unit.y = 0
" }}}
" dungeon#dungeon#unit.new() {{{
function dungeon#dungeon#unit.new()
   let unit = deepcopy(g:dungeon#dungeon#unit)
   let g:dungeon#dungeon#unit.id = g:dungeon#dungeon#unit.id + 1
   return unit
endfunction
" }}}


""" util
" let g:dungeon#dungeon#util {{{
let g:dungeon#dungeon#util = {}
" }}}
" dungeon#dungeon#util.func() {{{
function dungeon#dungeon#util.func()
endfunction
" }}}


""" default
" let g:dungeon#dungeon#default {{{
let g:dungeon#dungeon#default = {}
" }}}
" dungeon#dungeon#default.action() {{{
function dungeon#dungeon#default.action()
   if !self.attack()
      call self.move()
   endif
endfunction
" }}}
" dungeon#dungeon#default.attack() {{{
function dungeon#dungeon#default.attack()
   "call g:dungeon#dungeon#history.new('default attack')
   "return 1
   return 0
endfunction
" }}}
" dungeon#dungeon#default.aim_withconfirm(who) {{{
function dungeon#dungeon#default.aim_withconfirm(who)
   let loop = v:true
   while loop
      let aim = input('input aim <h, j, k, l> or <ESC>: ')
      if aim == ''
         return v:false
      endif
      if aim == 'h'
         return { 'x': who.x - 1, 'y': who.y }
      endif
      if aim == 'j'
         return { 'x': who.x, 'y': who.y + 1 }
      endif
      if aim == 'k'
         return { 'x': who.x, 'y': who.y - 1 }
      endif
      if aim == 'l'
         return { 'x': who.x + 1, 'y': who.y }
      endif
   endwhile
endfunction
" }}}
" dungeon#dungeon#default.aim(who, direction) {{{
function! dungeon#dungeon#default.aim(who, direction)
   if a:direction == 'h' || a:direction == 'left'
      return { 'x': a:who.x - 1, 'y': a:who.y }
   endif
   if a:direction == 'j' || a:direction == 'down'
      return { 'x': a:who.x, 'y': a:who.y + 1 }
   endif
   if a:direction == 'k' || a:direction == 'up'
      return { 'x': a:who.x, 'y': a:who.y - 1 }
   endif
   if a:direction == 'l' || a:direction == 'right'
      return { 'x': a:who.x + 1, 'y': a:who.y }
   endif
   return v:false
endfunction
" }}}
" dungeon#dungeon#default.move() {{{
function dungeon#dungeon#default.move() dict
   call g:dungeon#dungeon#history.new('default move')
   call g:dungeon#dungeon#history.new(self.name . ' <' . self.x . ', ' . self.y . '>')
   return 0

   let go = g:dungeon#dungeon#default.aim(a:who, a:direction)
   let movable = g:dungeon#dungeon#field.isfloor(go.x, go.y)
   if !movable
      return v:false
   endif
   if has_key(a:who, 'move_' . a:direction)
      call a:who['move_' . a:direction]()
   else
      call self['move_' . a:direction](a:who)
   endif
endfunction
function dungeon#dungeon#default.move_left(who)
   call g:dungeon#dungeon#history.new('default move to left: ' . a:who.name )
endfunction
function dungeon#dungeon#default.move_down(who)
   call g:dungeon#dungeon#history.new('default move to down: ' . a:who.name)
endfunction
function dungeon#dungeon#default.move_up(who)
   call g:dungeon#dungeon#history.new('default move to up: ' . a:who.name)
endfunction
function dungeon#dungeon#default.move_right(who)
   call g:dungeon#dungeon#history.new('default move to right: ' . a:who.name)
endfunction
" }}}


""" keeper
" let g:dungeon#dungeon#keeper {{{
let g:dungeon#dungeon#keeper = {}
let g:dungeon#dungeon#keeper.name = "keeper"
let g:dungeon#dungeon#keeper.view = "#"
let g:dungeon#dungeon#keeper.sile = 'monster'
let g:dungeon#dungeon#keeper.life = 20
let g:dungeon#dungeon#keeper.x = 0
let g:dungeon#dungeon#keeper.y = 0
" }}}
" dungeon#dungeon#keeper.init(x, y) {{{
function! dungeon#dungeon#keeper.init(x, y)
   "let g:dungeon#dungeon#keeper.x = a:x
   "let g:dungeon#dungeon#keeper.y = a:y
   let keeper = deepcopy(self)
   let keeper.x = a:x
   let keeper.y = a:y
   function keeper.action()
      call g:dungeon#dungeon#history.new('keeper action')
   endfunction
   call g:dungeon#dungeon#turnlist.append(keeper)
endfunction
" }}}
" dungeon#dungeon#keeper.getpos() {{{
function! dungeon#dungeon#keeper.getpos()
endfunction
" }}}
" dungeon#dungeon#keeper.aim() {{{
" }}}
" dungeon#dungeon#keeper.move() {{{
function dungeon#dungeon#keeper.move(direction)
   let go = g:dungeon#dungeon#default.aim(g:dungeon#dungeon#keeper, a:direction)
   let movable = g:dungeon#dungeon#field.isfloor(go.x, go.y)
   if !movable
      return v:false
   endif
   call g:dungeon#dungeon#keeper['move_' . a:direction]()
endfunction
function dungeon#dungeon#keeper.move_left()
   call g:dungeon#dungeon#history.new('keeper move to left')
endfunction
function dungeon#dungeon#keeper.move_down()
   call g:dungeon#dungeon#history.new('keeper move to down')
endfunction
function dungeon#dungeon#keeper.move_up()
   call g:dungeon#dungeon#history.new('keeper move to up')
endfunction
function dungeon#dungeon#keeper.move_right()
   call g:dungeon#dungeon#history.new('keeper move to right')
endfunction
" }}}
" dungeon#dungeon#keeper.monster() {{{
function! dungeon#dungeon#keeper.monster()
endfunction
" }}}
" dungeon#dungeon#keeper.sacrifice() {{{
function! dungeon#dungeon#keeper.sacrifice()
endfunction
" }}}


""" monster
" let g:dungeon#dungeon#monster {{{
let g:dungeon#dungeon#monster = {}
let g:dungeon#dungeon#monster.name = 'monster'
let g:dungeon#dungeon#monster.view = 'm'
let g:dungeon#dungeon#monster.side = 'monster'
let g:dungeon#dungeon#monster.life = 0
let g:dungeon#dungeon#monster.direction = 0
let g:dungeon#dungeon#monster.cost = 0
let g:dungeon#dungeon#monster.x = 0
let g:dungeon#dungeon#monster.y = 0
let g:dungeon#dungeon#monster.dictionary = {}
" }}}
" dungeon#dungeon#monster.new() {{{
function dungeon#dungeon#monster.new()
   let monster = g:dungeon#dungeon#unit.new()
   let monster.side = 'monster'
endfunction
" }}}
" dungeon#dungeon#monster.goblin {{{
let g:dungeon#dungeon#monster.dictionary.goblin = '@'
let g:dungeon#dungeon#monster.goblin = {}
let g:dungeon#dungeon#monster.goblin.name = 'goblin'
let g:dungeon#dungeon#monster.goblin.view = '@'
let g:dungeon#dungeon#monster.goblin.life = 3
let g:dungeon#dungeon#monster.goblin.cost = 6
function dungeon#dungeon#monster.goblin.create(x, y)
   let goblin = deepcopy(self)
   let goblin.x = a:x
   let goblin.y = a:y
   let goblin.action = g:dungeon#dungeon#default.action
   let goblin.attack = g:dungeon#dungeon#default.attack
   let goblin.move = g:dungeon#dungeon#default.move
   "return goblin
   call g:dungeon#dungeon#turnlist.append(goblin)
endfunction
" }}}


""" brave


""" mana
" let g:dungeon#dungeon#mana {{{
let g:dungeon#dungeon#mana = {}
let g:dungeon#dungeon#mana.mana = 0
let g:dungeon#dungeon#mana.line = 0
let g:dungeon#dungeon#mana.header = '  mana: '
" }}}
" dungeon#dungeon#mana.setline() {{{
function dungeon#dungeon#mana.init()
   let g:dungeon#dungeon#mana.line = line('$') + 1
endfunction
" }}}
" dungeon#dungeon#mana.redraw() {{{
function dungeon#dungeon#mana.redraw()
   call setline(g:dungeon#dungeon#mana.line, g:dungeon#dungeon#mana.header . g:dungeon#dungeon#mana.mana)
   redraw
endfunction
" }}}
" dungeon#dungeon#mana.setmana(mana) {{{
function dungeon#dungeon#mana.setmana(mana)
   let g:dungeon#dungeon#mana.mana = a:mana
   call g:dungeon#dungeon#mana.redraw()
endfunction
" }}}
" dungeon#dungeon#mana.usable(mana) {{{
function dungeon#dungeon#mana.usable(mana)
   if g:dungeon#dungeon#mana.mana >= a:mana
      return v:true
   else
      return v:false
   endif
endfunction
" }}}
" dungeon#dungeon#mana.charge(mana) {{{
function dungeon#dungeon#mana.charge(mana)
   let g:dungeon#dungeon#mana.mana += a:mana
   call g:dungeon#dungeon#mana.redraw()
endfunction
" }}}
" dungeon#dungeon#mana.lost(mana) {{{
function dungeon#dungeon#mana.lost(mana)
   let g:dungeon#dungeon#mana.mana -= a:mana
   call g:dungeon#dungeon#mana.redraw()
endfunction
" }}}


""" history
" let g:dungeon#dungeon#history {{{
let g:dungeon#dungeon#history = {}
let g:dungeon#dungeon#history.start = 0
let g:dungeon#dungeon#history.end = 0
let g:dungeon#dungeon#history.num = 0
let g:dungeon#dungeon#history.histories = []
" }}}
" dungeon#dungeon#history.init(hisnum) {{{
function dungeon#dungeon#history.init(num)
   let h = line('$') + 1
   let g:dungeon#dungeon#history.start = h
   let g:dungeon#dungeon#history.end = h + a:num + 1
   let g:dungeon#dungeon#history.num = a:num
   let g:dungeon#dungeon#history.histories = repeat([''], a:num)
   let n = a:num
   call setline(g:dungeon#dungeon#history.start, repeat('=', 10) . ' history ' . repeat('=', 10))
   while n
      call append(line('$'), '')
      let n = n - 1
   endwhile
   call setline(g:dungeon#dungeon#history.end, repeat('=', 29))
   redraw
endfunction
" }}}
" dungeon#dungeon#history.new(text) {{{
function dungeon#dungeon#history.new(text)
   call insert(g:dungeon#dungeon#history.histories, a:text)
   call g:dungeon#dungeon#history.redraw()
endfunction
" }}}
" dungeon#dungeon#history.redraw() {{{
function dungeon#dungeon#history.redraw()
   let s = g:dungeon#dungeon#history.start
   let n = g:dungeon#dungeon#history.num
   let h = deepcopy(g:dungeon#dungeon#history.histories)
   let i = 0
   for t in range(s + 1, s + n)
      call setline(t, h[i])
      let i = i + 1
   endfor
   redraw
endfunction
" }}}


""" config
" let g:dungeon#dungeon#config {{{
let g:dungeon#dungeon#config = {}
let g:dungeon#dungeon#config.sleeptime = 8
let g:dungeon#dungeon#config.sleeptimes = [10, 20, 30, 50, 80, 100, 120, 150, 200, 250, 300, 400, 500]
let g:dungeon#dungeon#config.floor = { "name": "floor", "type": "floor", "view": "." }
let g:dungeon#dungeon#config.wall = { "name": "wall", "type": "wall" }
let g:dungeon#dungeon#config.vwall =  { "name": "wall", "type": "wall", "view": "|" }
let g:dungeon#dungeon#config.hwall =  { "name": "wall", "type": "wall", "view": "-" }
let g:dungeon#dungeon#config.cwall =  { "name": "wall", "type": "wall", "view": "+" }
let g:dungeon#dungeon#config.unknown = { "name": "unknown", "type": "unknown" }
" }}}
" dungeon#dungeon#config.sleep() {{{
function dungeon#dungeon#config.sleep()
   let time = g:dungeon#dungeon#config.getsleeptime()
   execute('sleep ' . time . 'ms')
endfunction
" }}}
" dungeon#dungeon#config.getsleeptime() {{{
function dungeon#dungeon#config.getsleeptime()
   return g:dungeon#dungeon#config.sleeptimes[g:dungeon#dungeon#config.sleeptime]
endfunction
" }}}
" dungeon#dungeon#config.fasten() {{{
function dungeon#dungeon#config.fasten()
   if g:dungeon#dungeon#config.sleeptime > 0
      let g:dungeon#dungeon#config.sleeptime -= 1
   endif
endfunction
" }}}
" dungeon#dungeon#config.slowen() {{{
function dungeon#dungeon#config.slowen()
   if g:dungeon#dungeon#config.sleeptime < 12
      let g:dungeon#dungeon#config.sleeptime += 1
   endif
endfunction
" }}}
" dungeon#dungeon#config.getfloor() {{{
function dungeon#dungeon#config.getfloor()
   return deepcopy(g:dungeon#dungeon#config.floor)
endfunction
" }}}
" dungeon#dungeon#config.getwall() {{{
function dungeon#dungeon#config.getwall()
   return deepcopy(g:dungeon#dungeon#config.wall)
endfunction
" }}}
" dungeon#dungeon#config.getunknown() {{{
function dungeon#dungeon#config.getunknown()
   return deepcopy(g:dungeon#dungeon#config.unknown)
endfunction
" }}}
" dungeon#dungeon#config.command() {{{
function dungeon#dungeon#config.command()
   " keeper move
   nnoremap <buffer><silent> h :call g:dungeon#dungeon#keeper.move('left')<CR>
   nnoremap <buffer><silent> j :call g:dungeon#dungeon#keeper.move('down')<CR>
   nnoremap <buffer><silent> k :call g:dungeon#dungeon#keeper.move('up')<CR>
   nnoremap <buffer><silent> l :call g:dungeon#dungeon#keeper.move('right')<CR>
   nnoremap <buffer><silent> <LEFT>  :call g:dungeon#dungeon#keeper.move('left')<CR>
   nnoremap <buffer><silent> <DOWN>  :call g:dungeon#dungeon#keeper.move('down')<CR>
   nnoremap <buffer><silent> <UP>    :call g:dungeon#dungeon#keeper.move('up')<CR>
   nnoremap <buffer><silent> <RIGHT> :call g:dungeon#dungeon#keeper.move('right')<CR>
   " other ...so it thinking now
   nnoremap <buffer><silent> m :call g:dungeon#dungeon#keeper.monster()<CR>
   nnoremap <buffer><silent> s :call g:dungeon#dungeon#keeper.sacrifice()<CR>
   " develop quit
   nnoremap q :qa<CR>
endfunction
" }}}


""" event
" let g:dungeon#dungeon#event {{{
let g:dungeon#dungeon#event = {}
function dungeon#dungeon#event.start()
   let loop = v:true
   while loop
      let order = nr2char(getchar(0))
      if order == 'q' | let loop = 0 | endif
      if order == 'f' | call g:dungeon#dungeon#config.fasten() | endif
      if order == 's' | call g:dungeon#dungeon#config.slowen() | endif
      if order == '' | qa | endif
      let turnholder = g:dungeon#dungeon#turnlist.first()
      call turnholder.action()
      call g:dungeon#dungeon#turnlist.next(1)
      call g:dungeon#dungeon#config.sleep()
   endwhile
endfunction
" }}}




" vim: set ts=3 sts=3 sw=3 et :
