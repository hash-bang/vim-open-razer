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
		\ 'black': '#000000',
		\ 'white': '#FFFFFF',
		\ 'red': '#FF0000',
		\ 'green': '#00FF00',
		\ 'blue': '#0000FF',
		\ 'yellow': '#FFFF00',
		\ 'purple': '#FF00FF',
	\}
endif

if !exists('g:razer_modes')
	let g:razer_modes = {
		\ 'Mode:n': g:razer_colors['blue'],
		\ 'Mode:i': g:razer_colors['white'],
		\ 'Mode:v': g:razer_colors['purple'],
		\ 'Mode:V': g:razer_colors['purple'],
		\ 'Mode:Term': g:razer_colors['yellow'],
		\ 'State:Resume': g:razer_colors['blue'],
		\ 'State:Suspend': g:razer_colors['blue'],
	\}
endif
" }}}

" Horrible merge of various color conversion techniques to work out what the user ment
" @param {string} input The input value to convert
" @returns {blob} A binary blob object comaptible with the input of OpenRazer device drivers
"
" This function accepts the following input types:
"     * "#AABBCC" - Color hex
"
function! Razer#Color2OR(input)
	if a:input =~ '^#[0-9a-f]\{6\}$'
		let blob = 0z000000
		let blob[0] = str2nr(strpart(a:input, 1, 2), 16)
		let blob[1] = str2nr(strpart(a:input, 3, 2), 16)
		let blob[2] = str2nr(strpart(a:input, 5, 2), 16)
		" echo "COLOR CONV [" . a:input . "]" . " => [" . string(l:blob[0]) . "," . string(l:blob[1]) . "," . string(l:blob[2]) . "]"
		return blob
	else
		throw "Unsupported input color '" . a:input . "' - must be hex ('#123456')"
	endif
endfunction

function! Razer#Static(hex)
	let l:writeStr = 0z + a:hex
	call writefile(writeStr, g:razer_device_path . "/matrix_effect_static")
endfunction

function! Razer#Mode(mode)
	if has_key(g:razer_modes, a:mode)
		call Razer#Static(Razer#Color2OR(g:razer_modes[a:mode]))
	endif
endfunction

function! Razer#Setup()
	autocmd ModeChanged * call Razer#Mode('Mode:' . mode())
	autocmd FocusLost,UILeave,ExitPre,VimSuspend * call Razer#Mode('State:Suspend')
	autocmd FocusGained,UIEnter,ExitPre,VimResume,VimEnter * call Razer#Mode('State:Resume')
	autocmd TermEnter * call Razer#Mode('Mode:Term')
endfunction

if g:razer_enabled && len(readdir(g:razer_device_path)) > 0
	call Razer#Setup()
elseif g:razer_silent
	" Do nothing
else
	echoerr "No OpenRazer device found, use `let g:razer_device_path = /sys/bus/hid/drivers/razerkbd/<DEVICE>` to the right device or `let g:razer_silent = 1` to silence"
endif
