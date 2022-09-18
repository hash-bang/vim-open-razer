" Options loading {{{
if !exists('g:razer_enabled')
	let g:razer_enabled = 1
endif

if !exists('g:razer_silent')
	let g:razer_silent = 0
endif

if !exists('g:razer_device_path')
	let g:razer_device_path = "/sys/bus/hid/drivers/razerkbd/0003:1532:025E.0003"
endif

if !exists('g:razer_colors')
	let g:razer_colors = {
		\ 'black': 0z000000,
		\ 'white': 0zFFFFFF,
		\ 'red': 0zFF0000,
		\ 'green': 0z00FF00,
		\ 'blue': 0z0000FF,
		\ 'purple': 0zFF00FF,
	\}
endif

if !exists('g:razer_modes')
	let g:razer_modes = {
		\ 'n': g:razer_colors['blue'],
		\ 'i': g:razer_colors['white'],
		\ 'v': g:razer_colors['purple'],
		\ 'V': g:razer_colors['purple'],
	\}
endif
" }}}

function! Razer#Static(hex)
	let l:writeStr = 0z + a:hex
	call writefile(writeStr, g:razer_device_path . "/matrix_effect_static")
endfunction

function! Razer#Mode(mode)
	if has_key(g:razer_modes, a:mode)
		call Razer#Static(g:razer_modes[a:mode])
	endif
endfunction

function! Razer#Setup()
	autocmd ModeChanged * call Razer#Mode(mode())
endfunction

if g:razer_enabled && len(readdir(g:razer_device_path)) > 0
	call Razer#Setup()
elseif g:razer_silent
	" Do nothing
else
	echoerr "No OpenRazer device found, use `let g:razer_device_path = /sys/bus/hid/drivers/razerkbd/<DEVICE>` to the right device or `let g:razer_silent = 1` to STFU"
endif
