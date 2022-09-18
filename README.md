VIM-Open-Razer
==============
(Currently an) extremely simplistic example driver for Open-Razer compatible keyboards.

This module is heavily under construction and shouldn't be used by anyone.


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

Static - Single color setter
----------------------------
Sets all keys to the same color.
This key takes a single argument which is any valid color.

```vimscript
" Set normal mode color to yellow
let g:razer_modes['Mode:n'] = {'static': 'yellow'}

" Set insert mode color to white using hex color code
let g:razer_modes['Mode:n'] = {'static': '#FFFFFF'}
```
