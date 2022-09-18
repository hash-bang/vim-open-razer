" ============================================================================
" File:        default.vim
" Description: Basic, boring default theme for VIM-Open-Razer
" Maintainer:  Matt Carter <m@ttcarter.com>
" License:     MIT, see LICENSE for more details.
" Website:     https://github.com/hash-bang/vim-open-razer
" ============================================================================

let g:razer_modes = {
	\ 'Mode:n': {'keymap': {':': 'red', 'other': 'blue'}},
	\ 'Mode:i': {'keymap': {'esc': 'red', 'other': 'white'}},
	\ 'Mode:v': {'keymap': {'esc': 'red', 'other': 'purple'}},
	\ 'Mode:V': {'keymap': {'esc': 'red', 'other': 'purple'}},
	\ 'Mode:Term': {'static': 'yellow'},
	\ 'State:Resume': {'static': 'blue'},
	\ 'State:Suspend': {'static': 'blue'},
\}
