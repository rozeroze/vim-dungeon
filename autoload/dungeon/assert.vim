" Vim plugin script
" File: dungeon/assert.vim
" Summary: dungeon keeper on Vim
" Authors: rozeroze <rosettastone1886@gmail.com>
" License: undecided
" Version: 2018-1-1


function! dungeon#assert#init()
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
   call g:dungeon#dungeon#monster.goblin.create(5, 5)
   call g:dungeon#dungeon#field.replace(5, 5, '@')
   call g:dungeon#dungeon#monster.goblin.create(6, 5)
   call g:dungeon#dungeon#field.replace(6, 5, '@')
   call g:dungeon#dungeon#monster.goblin.create(7, 6)
   call g:dungeon#dungeon#field.replace(7, 6, '@')
   call g:dungeon#dungeon#event.start()
endfunction


" vim: set ts=3 sts=3 sw=3 et :
