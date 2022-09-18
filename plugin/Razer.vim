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

if !exists('g:razer_device_max_rows')
	let g:razer_device_max_rows = 5
endif

if !exists('g:razer_device_max_cols')
	let g:razer_device_max_cols = 21
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
		\ 'Mode:n': {'static': 'blue'},
		\ 'Mode:i': {'static': 'white'},
		\ 'Mode:v': {'static': 'purple'},
		\ 'Mode:V': {'static': 'purple'},
		\ 'Mode:Term': {'static': 'yellow'},
		\ 'State:Resume': {'static': 'blue'},
		\ 'State:Suspend': {'static': 'blue'},
	\}
endif
" }}}


" Horrible merge of various color conversion techniques to work out what the user ment
" @param {string} input The input value to convert
" @returns {blob} A binary blob object comaptible with the input of OpenRazer device drivers
"
" This function accepts the following input types:
"     * "#AABBCC" - Color hex
"     * Any key - If string exists within g:razer_colors use its value
"
function! Razer#Color2OR(input)
	if a:input =~ '^#[0-9a-f]\{6\}$'
		let blob = 0z000000
		let blob[0] = str2nr(strpart(a:input, 1, 2), 16)
		let blob[1] = str2nr(strpart(a:input, 3, 2), 16)
		let blob[2] = str2nr(strpart(a:input, 5, 2), 16)
		" echo "COLOR CONV [" . a:input . "]" . " => [" . string(l:blob[0]) . "," . string(l:blob[1]) . "," . string(l:blob[2]) . "]"
		return blob
	elseif has_key(g:razer_colors, a:input)
		return Razer#Color2OR(g:razer_colors[a:input])
	else
		throw "Unsupported input color '" . a:input . "' - must be hex ('#123456')"
	endif
endfunction


" Simple function to set all keys on the keyboard to the same static color
" NOTE: This function has a fade effect from the previous color to the one
"       specified. If an instant set is requried use Razer#Flood()
" @param {string} color Any valid color to set all keys to
function! Razer#Static(color)
	let writeColor = Razer#Color2OR(a:color)
	call writefile(writeColor, g:razer_device_path . "/matrix_effect_static")
endfunction


" Set all keys on the keyboard to the same color
" This function differs from Razer#Static() in that it uses the keyboard
" framebuffer, avoiding the fade effect the hardware forces on a usual color change
" @param {string} color Any valid color to set all keys to
function! Razer#Flood(color)
	let writeColor = Razer#Color2OR(a:color)
	let row = 0
	while row < g:razer_device_max_rows + 1
		let writeLine = 0z00
		let writeLine[0] = row
		let writeLine[1] = 0
		let writeLine[2] = g:razer_device_max_cols
		let col = 0
		while col < g:razer_device_max_cols + 1
			let writeLine += writeColor
			let col += 1
		endwhile
		call writefile(writeLine, g:razer_device_path . "/matrix_custom_frame", "a")
		let row += 1
	endwhile

	call writefile(['1'], g:razer_device_path . "/matrix_effect_custom")
endfunction


" Execute a single action
" This funciton is usally called by Razer#Mode(action) to execute a mode change
" @param {dict} action The action object to execute
function! Razer#Action(action)
	if (has_key(a:action, 'static'))
		call Razer#Static(a:action['static'])
	elseif (has_key(a:action, 'flood'))
		call Razer#Flood(a:action['flood'])
	else
		throw "Unknown action '" . a:action . "'"
	endif
endfunction


" Central function to handle mode changes
" Modes can be specified against any `autocmd` or defined as custom by the user
" If the mode has no valid definition, nothing will happen
" @param {string} mode The mode to change to
function! Razer#Mode(mode)
	if has_key(g:razer_modes, a:mode)
		call Razer#Action(g:razer_modes[a:mode])
	endif
endfunction


" Set up the main autocmd and other hook functionality to bind to various VIM operations
" This command will be automatically called if `g:razer_enabled == 1` and a
" valid `g:razer_device_path` is found
function! Razer#Setup()
	autocmd ModeChanged * call Razer#Mode('Mode:' . mode())
	autocmd FocusLost,UILeave,ExitPre,VimSuspend * call Razer#Mode('State:Suspend')
	autocmd FocusGained,UIEnter,ExitPre,VimResume,VimEnter * call Razer#Mode('State:Resume')
	autocmd TermEnter * call Razer#Mode('Mode:Term')
endfunction


" Bootstrap functionality
try
	if g:razer_enabled && len(readfile(g:razer_device_path . '/device_serial')) > 0
		call Razer#Setup()
	endif
catch
	if g:razer_silent == 0
		echoerr "No OpenRazer device found, use `let g:razer_device_path = /sys/bus/hid/drivers/razerkbd/<DEVICE>` to the right device or `let g:razer_silent = 1` to silence"
	endif
endtry
