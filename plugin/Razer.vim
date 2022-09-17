let g:razer_enabled = 1
let g:razer_silent = 0
let g:razer_device_path = "/sys/bus/hid/drivers/razerkbd/0003:1532:025E.0003"

let s:colors = {
	\ 'black': 0z000000,
	\ 'white': 0zFFFFFF,
	\ 'red': 0zFF0000,
	\ 'green': 0z00FF00,
	\ 'blue': 0z0000FF,
	\ 'purple': 0zFF00FF,
\}


let s:mode_map = {
	\ 'n': s:colors['blue'],
	\ 'i': s:colors['white'],
	\ 'v': s:colors['purple'],
	\ 'V': s:colors['purple'],
\}

function! Razer#Static(hex)
	let l:writeStr = 0z + a:hex
	call writefile(writeStr, g:razer_device_path . "/matrix_effect_static")
endfunction

function! Razer#Mode(mode)
	if has_key(s:mode_map, a:mode)
		call Razer#Static(s:mode_map[a:mode])
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
	warn "No OpenRazer device found, use `let g:razer_device_path = /sys/bus/hid/drivers/razerkbd/<DEVICE>` to the right device or `let g:razer_silent = 1` to STFU"
endif
