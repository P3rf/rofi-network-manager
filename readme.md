# Rofi-NetWork-manager
A nework manager for Tiling Window Managers [i3/bspwm/awesome/etc] or not. 
Inspired from [rofi-wifi-menu](https://github.com/zbaylin/rofi-wifi-menu).


## Table of Contents
* [Requirements](#requirements)
* [Features](#features)
* [Screenshots](#screenshots)
* [Download-Usage](#download-usage)
* [ToDo](#todo)

### Requirements
* nmcli
* [rofi](https://github.com/davatorium/rofi)
* [dunst](https://github.com/dunst-project/dunst) (_For notifications_)
### Features
* Connect to an existing network
* Disconnect from the network
* Turn on/off wifi
* Support for Multiple wifi devices (_Up to two_)
	* Option to change between wifi devices when available
* Manual Connection to a hidden wifi
* Turn on/off ethernet
	* See when ethernet is unavailable
* Restart the network
* Status 
	* See devices Connection name and local IP
### Screenshots
<img src="https://raw.githubusercontent.com/P3rf/rofi-network-manager/master/options.png"/>

### Download-Usage
```
git clone https://github.com/P3rf/rofi-network-manager.git
cd rofi-network-manager
bash "./rofi-network-manager.sh"
```


### ToDo
 * Tweak notifications
 * Add notifications icons
