---
layout: post
title:  "Emacs on Windows"
date:   2021-09-24
categories: programming
math: true
uid: emacs-on-windows
---

## How did I get there
Due to workplace change I had to buy a new laptop (I had give laptop from my previous job back).\\
Requirements on new laptop were pretty clear: 16G RAM, 512G SSD and — that was the worst — it has to be able to run linux without too much hassle.\\
Since my old Lenovo Carbon (4 gen I suppose) worked for many years without any problem the choice was simple and I got another Lenovo Carbon (9 gen).

When my new laptop arrived I logged into Windows 10 Pro (OEM) and... decided to keep windows. Why? This laptop (suddenly!) had touchscreen, fingerprint scanner, power modes to keep battery last longer... Well, I didn't want to make it all work in Linux, but wanted to use all these features.

I got WSL2, Docker and [Emacs under WSL2](https://emacsredux.com/blog/2020/09/23/using-emacs-on-windows-with-wsl2/) working in two days so I was able to go around my day job.

A month later I had to download lots of files, edit them and send back. As almost all applications (apart from Docker and Emacs) were running on windows using WSL emacs was not very convenient. So I decided to make Emacs work on Windows. As most of my questions took some hours to google answers to I decided to put these answers here.

## Installing
That's the easiest part: go to [https://www.gnu.org/software/emacs/](https://www.gnu.org/software/emacs/), download, install.

## Configuring
Emacs by default looks for configuration not in `C:\Users\<Username>` but in `C:\Users\<Username>\AppData\Roaming`. So that's where we put it

As I keep emacs dotfiles in Git I cloned my repo to `C:\Users\<Username>\Code\emacs_config` and made symbolic links in PowerShell (under Administrator):
```
 C:\Users\Valen> mkdir .emacs.d
 C:\Users\Valen> New-Item -ItemType SymbolicLink -Path C:\Users\Valen\ -Name .emacs -Value 'C:\Users\Valen\Code\emacs_config\.emacs'
 C:\Users\Valen> New-Item -ItemType SymbolicLink -Path C:\Users\Valen\.emacs.d\ -Name settings -Value 'C:\Users\Valen\Code\emacs_config\.emacs.d\settings'
```

## Changing HOME folder
As Emacs looks for home in `C:\Users\<Username>\AppData\Roaming` finding files is not very convenient (getting back to `C:\Users\<Username>` every time). There're few ways to fix this:
1. Set HOME in Windows
   Not my thing, 'cause fighting Windows to set HOME is too painful to me
2. Set HOME in Emacs
   That's my thing!

To do this I put this code at the end of .emacs:
```elisp
(if (string= system-type "windows-nt")
    (setenv "HOME" "C:\\Users\\Valen"))
```

## emacs --daemon and emacsclient
It took me about two hours to google answers for that, so this section (I think) is the most valuable.

First, I wanted to use emacsclient 'cause in 2021 it takes emacs inexcusibly long time to start.\\
Second, I'd like not to lauch `emacs --daemon` at system start. That's just me.

I found this solution: run emacs with `-a` option (which starts alternative editor if emacsclient fails to start) with empty value which causes emacsclient to start `emacs --daemon` and connect to it.

To make this work I had to delete `C:\Users\Valen\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Emacs-<version>` which had shortcuts created by emacs installer.
Next I created shortcut `C:\Users\Valen\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Emacs` and set `target` attribute to this:
```
"C:\Program Files\Emacs\x86_64\bin\emacsclient.exe" -c -n -f "c:\Users\Valen\.emacs.d\server\server" -a=
```
Where `-f "c:\Users\Valen\.emacs.d\server\server"` points to daemon socket. Remember we changed HOME? That has consequences.

## Adopting emacs configuration
Emacs config from Linux didn't allow Emacs to start normally, so I had to fix it.

Specifically, I had to turn off pinentry integration (it makes no sense in Windows anyway):
```elisp
(if (string= system-type "gnu/linux")
    (progn (setenv "INSIDE_EMACS" (format "%s,comint" emacs-version))
           (setq epa-pinentry-mode 'loopback)
           (pinentry-start)))
```

## PowerShell
Cmd was not an option, so I had to make PowerShell work inside shell-mode:
```elisp
(if (string= system-type "windows-nt")
    (setq
     shell-file-name "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
     explicit-powershell.exe-args '("-InputFormat" "Text" "-NoLogo")))
```

Autocompletition doesn't work though.

## What else?
Well, neigher grep nor silversearcher-ag are easy to install for PowerShell which is sad.\\
And I didn't bother wit git integration because I don't write too much code in Windows.

## Small recap
In WSL2 it (Emacs) still runs faster and is easier to use. So I ended up making `/mnt/c/Users/Valen → ~/winhome` symlink ans use Emacs inside WSL.

And yeah, I saw Surface Laptop Studio announce and now I regret that I got Lenovo Carbon. But at least it was a way to know that development under Windows (with WSL) works pretty well (so I don't need Linux as host system).
