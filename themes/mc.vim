" ============================================================================
" File:        mc.vim
" Description: MC's own Razer preferences, intended here to show-off
" Maintainer:  Matt Carter <m@ttcarter.com>
" License:     MIT, see LICENSE for more details.
" Website:     https://github.com/hash-bang/vim-open-razer
" ============================================================================

let g:razer_modes = {
	\ 'Mode:n': {'keymap': {
		\ ':': 'red',
		\ 'caps': 'red',
		\ 'other': 'blue'
	\}},
	\ 'Mode:i': {'keymap': {
		\ 'esc': 'red',
		\ 'other': 'white'
	\}},
	\ 'Mode:v': {'keymap': {
		\ 'esc': 'red',
		\ 'other': 'purple',
	\}},
	\ 'Mode:V': {'keymap': {
		\ 'esc': 'red',
		\ 'other': 'purple',
	\ }},
	\ 'Mode:Term': {'keymap': {
		\ 'esc': 'red',
		\ 'other': 'yellow'
	\}},
	\ 'State:Resume': '>Mode:n',
	\ 'State:Suspend': {'flood': 'blue'},
\}
