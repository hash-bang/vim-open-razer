" Options loading {{{
" Set this to 1 to override all "if it doesn't already exist set it" options
" This is useful for rapidly reloading this module (via `source %`) to update
" bindings and keymaps
let g:razer_debug = 1

if g:razer_debug || !exists('g:razer_enabled')
	let g:razer_enabled = 0
endif

if g:razer_debug || !exists('g:razer_silent')
	let g:razer_silent = 0
endif

if g:razer_debug || !exists('g:razer_device_path')
	let g:razer_device_path = "/sys/bus/hid/drivers/razerkbd/0003:1532:025E.0003"
endif

if g:razer_debug || !exists('g:razer_device_keymap')
	let g:razer_device_keymap = "auto"
endif

if g:razer_debug || !exists('g:razer_device_max_rows')
	let g:razer_device_max_rows = 5
endif

if g:razer_debug || !exists('g:razer_device_max_cols')
	let g:razer_device_max_cols = 21
endif

if !exists('g:razer_keymap')
	let g:razer_keymap = {
		\ 'esc' : [ 0,  1],
		\ 'f1'  : [ 0,  3],
		\ 'f2'  : [ 0,  4],
		\ 'f3'  : [ 0,  5],
		\ 'f4'  : [ 0,  6],
		\ 'f5'  : [ 0,  7],
		\ 'f6'  : [ 0,  8],
		\ 'f7'  : [ 0,  9],
		\ 'f8'  : [ 0, 10],
		\ 'f9'  : [ 0, 11],
		\ 'f10' : [ 0, 12],
		\ 'f11' : [ 0, 13],
		\ 'f12' : [ 0, 14],
		\ '`'   : [ 1,  1],
		\ '1'   : [ 1,  2],
		\ '2'   : [ 1,  3],
		\ 'tab' : [ 2,  1],
		\ 'q'   : [ 2,  2],
		\ 'w'   : [ 2,  3],
		\ 'e'   : [ 2,  4],
		\ 's'   : [ 3,  3],
	\}
endif

if g:razer_debug || !exists('g:razer_colors')
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
" Functionally this is the same as calling `Razer#Keymap({'other': color})`
" but more efficient
"
" This function differs from Razer#Static() in that it uses the keyboard
" framebuffer, avoiding the fade effect the hardware forces on a usual color change
"
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


" Set specific key colors, overriding their current state
" If the "other" key is specified all remaining colors are set to that value
"
" @param {dict<string>} keymap A dictionary describing the key colors
" @param {string} [keymap.other] Default color for any key not specified
function Razer#Keymap(keymap)
	" Calculate if we need to set everything or can optimize for just the
	" delta key color changes
	let set_all = has_key(a:keymap, 'other')

	" Populate initial row matrix (cols x rows) {{{
	let rows = []
	let row = 0
	while row < g:razer_device_max_rows + 1
		let row += 1
		let rows += [{
			\ 'map': repeat([-1], g:razer_device_max_cols),
			\ 'start': -1,
			\ 'end': -1,
		\}]
	endwhile
	" }}}

	" Populate matrix with incoming keymap {{{
	for key in keys(a:keymap)
		if key =~ "^\\d\\+,\\d\\+$"
			let key_color = Razer#Color2OR(a:keymap[key])
			let key_ref = split(key, ",")
			let key_y = key_ref[0]
			let key_x = key_ref[1]
			echo "FORCE SET KEY " . key_y . "," + key_x " = " . a:keymap[key]
			let rows[key_y]['map'][key_x] = key_color
			let set_all = 1
			let a:keymap['other'] = '#000000'
		elseif has_key(g:razer_keymap, key)
			let key_color = Razer#Color2OR(a:keymap[key])
			let key_y = g:razer_keymap[key][0]
			let key_x = g:razer_keymap[key][1]

			echo "SET KEY " . key_x . "," . key_y . " = " . string(key_color)

			" Set key color
			" let rows[g:razer_keymap[key][0]]['map'][key_x] = key_color
			let rows[key_y]['map'][key_x] = key_color

			" Only adjust start / end params if we know we are not setting all
			" keys - this is inefficient but hey, why not!
			if ! set_all
				" Move start position if its not been set yet OR is lower than current
				if rows[key_y]['start'] < 0 || key_x < rows[key_y]['start']
					let rows[key_y]['start'] = key_x
				endif

				" Move end position if its not been set yet OR is higher than current
				if rows[key_y]['end'] < 0 || key_x > rows[key_y]['end']
					let rows[key_y]['end'] = key_x
				endif
			endif
		elseif key == 'other'
			" Do nothing - handled later
		else
			echoerr "Unknown key '" . key . "'"
		endif
	endfor
	" }}}

	" If "other" meta key exists populate all gaps {{{
	if set_all
		let otherColor = Razer#Color2OR(a:keymap['other'])
		let row = 0
		while row < len(rows)
			"
			" Iterate over all keys setting the color if its not already been set above
			let col = 0
			while col < len(rows[row]['map'])

				let cell = rows[row]['map'][col]
				if type(cell) == type(0) && cell < 0
					let rows[row]['map'][col] = otherColor
				endif

				let col += 1
			endwhile

			" Remove offset calc to splat the entire row anyway
			let rows[row]['start'] = 0
			let rows[row]['end'] = len(rows[row]['map'])

			let row += 1
		endwhile
	endif
	" }}}

	" Write all rows which have a marked change to the driver {{{
	let row = 0
	while row < len(rows)
		" We have work to do?
		if rows[row]['start'] >= 0
			let writeLine = 0z000000
			let writeLine[0] = row
			let writeLine[1] = rows[row]['start']
			let writeLine[2] = rows[row]['end']
			for cell in rows[row]['map'][ rows[row]['start'] : rows[row]['end'] ]
				" echo "APPEND FOR " . row . " ~ [" . string(cell) . "]"
				let writeLine += cell
			endfor
			let writeLine += 0z000000
			echo "RAW WRITE " . row . " " . rows[row]['start'] . ":" . rows[row]['end']  . " = [" . string(writeLine) . "] ~ " . len(writeLine) . " items"
			call writefile(writeLine, g:razer_device_path . "/matrix_custom_frame")
		endif
		let row += 1
	endwhile

	call writefile(['1'], g:razer_device_path . "/matrix_effect_custom")
	" }}}
endfunction


" Show each keymap item in sequence prompting the user to move on in each case
" This function is designed to kep with setting up the keymap
" @param {number} [prompt=1] Whether to prompt the user or just animate through the keys
function Razer#WalkKeymap(prompt=1)
	let key_offset = 0
	while key_offset < len(g:razer_keymap)
		let key = keys(g:razer_keymap)[key_offset]
		let keymap = {'other': 'black'}
		let keymap[key] = 'white'
		call Razer#Keymap(keymap)

		if a:prompt == 1
			let user_response = inputlist([
				\ 'Currently showing key [' . key . ']',
				\ '0 / Enter. Next map',
				\ '1. Previous map',
			\])
			if user_response == 0
				let key_offset += 1
			elseif user_response == 1
				let key_offset -= 1
			elseif key_offset > 1
				break
			endif
		else
			sleep 1
			let key_offset += 1
		endif
	endwhile
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
