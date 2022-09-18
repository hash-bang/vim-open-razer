" ============================================================================
" File:        Razer.vim
" Description: OpenRazer support for VIM
" Maintainer:  Matt Carter <m@ttcarter.com>
" License:     MIT, see LICENSE for more details.
" Website:     https://github.com/hash-bang/vim-open-razer
" ============================================================================

" Options loading {{{
" Set this to 1 to override all "if it doesn't already exist set it" options
" This is useful for rapidly reloading this module (via `source %`) to update
" bindings and keymaps
let g:razer_debug = 0

if g:razer_debug || !exists('g:razer_enabled')
	let g:razer_enabled = 1
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

if g:razer_debug || !exists('g:razer_theme')
	let g:razer_theme = 'default'
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

if g:razer_debug || !exists('g:razer_theme')
	let g:razer_theme = "default"
endif
" }}}

" Generic state variables {{{
" Path to the main root directory of this plugin
" @type {string}
let s:razer_path = resolve(expand('<sfile>:h') . '/..')
" }}}

" Generic utility functions {{{

" Constrain a numeric value between a min / max
" @param {number} value The value to set
" @param {number} min The minimum value allowed
" @param {number} max The maximum value allowed
" @returns {number} The output number clamped between min + max
function! s:clamp(value, min, max)
	if a:value < a:min
		return a:min
	elseif a:value > a:max
		return a:max
	else
		return a:value
	endif
endfunction


function! s:position2map(row, col)
	for key in keys(g:razer_keymap)
		if (g:razer_keymap[key][0] == a:row && g:razer_keymap[key][1] == a:col)
			echo "Match key " . key . " for " . a:row . "," . a:col
			return key
		endif
	endfor
	echo "No match for " . a:row . "," . a:col
	return ''
endfunction
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
			let rows[key_y]['map'][key_x] = key_color
			let set_all = 1
			let a:keymap['other'] = '#000000'
		elseif has_key(g:razer_keymap, key)
			let key_color = Razer#Color2OR(a:keymap[key])
			let key_y = g:razer_keymap[key][0]
			let key_x = g:razer_keymap[key][1]

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
			" echo "RAW WRITE " . row . " " . rows[row]['start'] . ":" . rows[row]['end']  . " = [" . string(writeLine) . "] ~ " . len(writeLine) . " items"
			call writefile(writeLine, g:razer_device_path . "/matrix_custom_frame")
		endif
		let row += 1
	endwhile

	call writefile(['1'], g:razer_device_path . "/matrix_effect_custom")
	" }}}
endfunction


" Show each keymap item in sequence prompting the user to move on in each case
" This function is designed to help with setting up the keymap
" @param {number} [prompt=1] Whether to prompt the user or just animate through the keys
function Razer#WalkKeymap(prompt=1)
	let key_offset = 0
	let keys = sort(keys(g:razer_keymap))

	while key_offset < len(keys)
		let key = keys[key_offset]
		let keymap = {'other': 'black'}
		let keymap[key] = 'white'
		call Razer#Keymap(keymap)

		if a:prompt == 1
			let user_response = confirm(
				\ 'Currently showing key [' . key . ']',
				\ "&Next\n&Previous\n&Quit"
			\])
			if user_response == 0 || user_response == 1
				let key_offset = s:clamp(key_offset + 1, 0, len(keys))
			elseif user_response == 2
				let key_offset = s:clamp(key_offset -1, 0, len(keys))
			else
				return
			endif
		else
			sleep 1
			let key_offset += 1
		endif
	endwhile
endfunction


" Show each key position in sequence prompting the user to move on in each case
" This function is designed to help with setting up the keymap
" @param {number} [prompt=1] Whether to prompt the user or just animate through the keys
function Razer#WalkKeys(prompt=1)
	let row = 0
	while row < g:razer_device_max_rows
		let col = 0
		while col < g:razer_device_max_cols
			let keymap = {'other': 'black'}
			let keymap[row . ',' . col] = 'white'
			call Razer#Keymap(keymap)

			if a:prompt == 1
				let existing_map = s:position2map(row, col)
				let user_response = confirm(
					\ 'Currently showing key position [' . row . ',' . col . ']' . (existing_map != '' ? ' - mapped to "' . existing_map . '"' : ''),
					\ "&Next\n&Previous\n\&Down\n&Up\n&Quit"
				\)
				if user_response == 0 || user_response == 1
					let col += 1
				elseif user_response == 2
					let col = s:clamp(col - 1, 0, g:razer_device_max_cols)
				elseif user_response == 3
					let row = s:clamp(row + 1, 0, g:razer_device_max_rows)
				elseif user_response == 4
					let row = s:clamp(row - 1, 0, g:razer_device_max_rows)
				else
					return
				endif
			else
				sleep 1
				let col += 1
			endif
		endwhile
		let row += 1
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
	elseif (has_key(a:action, 'keymap'))
		call Razer#Keymap(a:action['keymap'])
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


" Load a specific theme file
" @param {string} [theme='default'] The theme file to load, if unspecified defaults to `g:razer_theme`
" @param {number} [force=0] Only load the theme if no other `g:razer_modes` state exists
function! Razer#Theme(theme=g:razer_theme, force=0)
	if ! a:force && exists('g:razer_modes')
		return
	endif

	try
		let theme_path = s:razer_path . '/themes/' . fnameescape(a:theme) . '.vim'
		execute('source ' . theme_path)
		if ! exists('g:razer_modes')
			echoerr "Expeccted `g:razer_modes` to now be defined after including [" . theme_path . "] but its still not - missing or corrupt theme?"
			let g:razer_modes = {}
		endif
	catch
		echorr "Error loading the vim-open-razor theme '" . a:theme . '" from [' . theme_path . "]'"
	endtry
endfunction


" Set up the main autocmd and other hook functionality to bind to various VIM operations
" This command will be automatically called if `g:razer_enabled == 1` and a
" valid `g:razer_device_path` is found
" @see Razer#Bootstrap()
function! Razer#Init()
	" Determine keymap to use + include it {{{
	let driver_file =
		\ g:razer_device_keymap == 'auto'
			\ ? substitute(
				\ readfile(g:razer_device_path . '/device_type')[0],
				\ '^.*$',
				\ "\\L\\0",
				\ ''
			\)
			\ : g:razer_device_keymap

	" Strip redundent "razer " prefix from drivers
	let driver_file = substitute(driver_file, '^razer ', '', '')

	" Replace non-alpha-numeric with '-', so it will match a file in ./drivers/
	let driver_file = substitute(driver_file, "\\W\\{1,}", '-', 'g')

	let driver_path = s:razer_path . '/drivers/' . fnameescape(driver_file) . '.vim'
	try
		execute('source ' . driver_path)
	catch
		echoerr "Error including the device driver '" . driver_file . "' - cant find a corresponding driver at [" . driver_path . "]. See https://github.com/hash-bang/vim-open-razer#custom-drivers for more details"
	endtry
	" }}}}

	" Load theme {{{
	call Razer#Theme()
	" }}}

	" Bind to various event listeners {{{
	autocmd ModeChanged * call Razer#Mode('Mode:' . mode())
	autocmd FocusLost,UILeave,ExitPre,VimSuspend * call Razer#Mode('State:Suspend')
	autocmd FocusGained,UIEnter,ExitPre,VimResume,VimEnter * call Razer#Mode('State:Resume')
	autocmd TermEnter * call Razer#Mode('Mode:Term')
	" }}}
endfunction


" Bootstrap functionality
" Run automatically on boot
function! Razer#Bootstrap()
	try
		if g:razer_enabled && len(readfile(g:razer_device_path . '/device_serial')) > 0
			call Razer#Init()
		endif
	catch
		if g:razer_silent == 0
			echoerr "No OpenRazer device found, use `let g:razer_device_path = /sys/bus/hid/drivers/razerkbd/<DEVICE>` to the right device or `let g:razer_silent = 1` to silence"
		endif
	endtry
endfunction

call Razer#Bootstrap()
