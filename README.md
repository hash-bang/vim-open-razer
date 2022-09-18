VIM-Open-Razer
==============
Control an OpenRazer compatible device from VIM.


Quickstart
----------
The below script lists the basic options for this plugin and their associated defaults.


```vimscript
" Include the package using your bundler of choice
Plug 'hash-bang/vim-open-razer'


" Global switch to enable / disable the plugin
let g:razer_enabled = 1


" If running on a machine without where `g:razer_device_path`, auto disable functionality
" This setting is mainly intended to provide a portable .vimrc file for systems lacking OpenRazer devices
let g:razer_silent = 0


" The OpenRazer device to use, set this to the latest device driver you are running
let g:razer_device_path = "/sys/bus/hid/drivers/razerkbd/0003:1532:025E.0003"


" The various modes and what should happen for each
let g:razer_modes = {
	\ 'Mode:n': {'static': 'blue'},
	\ 'Mode:i': {'static': 'white'},
	\ 'Mode:v': {'static': 'purple'},
	\ 'Mode:V': {'static': 'purple'},
	\ 'Mode:Term': {'static': 'yellow'},
	\ 'State:Resume': {'static': 'blue'},
	\ 'State:Suspend': {'static': 'blue'},
\}
```

Supported actions
=================
All actions are mapped against modes. These are typically a VIM `dict` object with a single key.


Static - Single color setter (fade effect)
------------------------------------------
Sets all keys to the same color.
This key takes a single argument which is any valid color.
This method sets using a fade effect from the current layout, if you want instant see `Flood`

```vimscript
" Set normal mode color to yellow
let g:razer_modes['Mode:n'] = {'static': 'yellow'}

" Set insert mode color to white using hex color code
let g:razer_modes['Mode:n'] = {'static': '#FFFFFF'}
```


Flood - Single color setter (instant)
-------------------------------------
Sets all keys to the same color instantly.
This key takes a single argument which is any valid color.
This method sets using a fade effect from the current layout, if you want instant see `Flood`

```vimscript
" Set normal mode color to yellow
let g:razer_modes['Mode:n'] = {'flood': 'yellow'}

" Set insert mode color to white using hex color code
let g:razer_modes['Mode:n'] = {'flood': '#FFFFFF'}
```

Inherit - Copy an existing mode
-------------------------------
Rather than define the same mode in multiple places the `inherit` action allows a pointer to an existing mode.

```vimscript
" Copy the `Mode:n` method to `State:Resume`
let g:razer_modes['State:Resume'] = {'inherit': 'Mode:n'}

" Copy the `Mode:n` method to `State:Resume` - alternate syntax
let g:razer_modes[State:Resume] = '>Mode:n'
```



Adding to the project
=====================


Custom Themes
-------------
Some pre-packaged themes are set up in the [themes](./themes) directory. These will only be loaded if `g:razer_modes` isn't already defined however.

If you do come up with something please open a [Pull Request](https://github.com/hash-bang/vim-open-razer/pulls) so others can benefit from your styling abilities


Custom Drivers
--------------
Unfortunately I only own a `Razer Cynosa V2 (1532:025e)` keyboard so this project is built a lot around that hardware.

If you would like to contibute I would suggest the following:

1. Fork the [repo](https://github.com/hash-bang/vim-open-razer)
2. Copy the existing base keymap in `./drivers/cynosa-v2.vim` as whatever file the plugin complains about when it tries to load (i.e. the `razer` prefix removed + every non-alpha numeric as '-')
3. Run `call Razer#WalkKeys()` to walk through all the keys on your keyboard and check the bindings are ok - correcting where necessary
4. Save your new keymap driver file
5. Please open a [Pull Request](https://github.com/hash-bang/vim-open-razer/pulls) so others can benefit from your VIM knowledge, you beautiful person you
