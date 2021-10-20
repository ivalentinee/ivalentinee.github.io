---
layout: post
title:  "Emacs в Windows"
date:   2021-09-24
categories: programming
math: true
uid: emacs-on-windows
---

## Как же я дошёл до жизни такой?
В связи со сменой работы мне пришлось взять новый ноут (корпоративный забрали).\\
Требования к ноуту у меня были достаточно понятные: 16 гиг оперативы, 512 гиг жёсткого диска (или больше) и — это самое противное — чтобы на нём завёлся Linux без особых танцев.\\
Я не очень долго выбирал, потому что несколько лет работал на Lenovo X1 Carbon (вроде как 4 поколения), взяв Lenovo X1 Carbon но уже 9 поколения.

Когда мне пришёл ноут, я запустил Windows 10 Pro, которая шла в комплекте, и ... решил не ставить Linux. Почему? Потому что тут внезапно(!) оказался тачскрин, работающий сканер отпечатков пальцев, профили питания для экономии батареи... Короче, я понял, что заводить всё это в лялихе мне неохота, а отказываться от таких удобств чисто ради виндекапца я не готов.

Настроил за пару дней WSL2, Docker, [Emacs](https://emacsredux.com/blog/2020/09/23/using-emacs-on-windows-with-wsl2/), всё завелось, я смог работать.

Но тут по работе пришлось скачивать кучу файлов, смотреть/редактировать их, затем отправлять назад. Так как все приложения кроме докера и Emacs'а у меня запущены в винде, открывать всё это в Emacs, который работает изнутри WSL не очень удобно. Я решил попробовать запустить Emacs в винде. Так как на многие мои вопросы ответы в интернете ищутся не по первой ссылке, я решил часть всего этого описать тут.

## Установка
Ну тут всё просто: идём на сайт [https://www.gnu.org/software/emacs/](https://www.gnu.org/software/emacs/), качаем, ставим.

## Складываем конфиги
По-умолчанию Emacs ищет конфиги не в `C:\Users\<Username>`, а в `C:\Users\<Username>\AppData\Roaming`. Туда их и сложим, чтобы не извращаться с особенностями винды.

Так как я держу конфиги в Git, я склонировал репозиторий в `C:\Users\<Username>\Code\emacs_config`, а затем сделал символические ссылки в PowerShell (запущенном под админом):
```
 C:\Users\Valen> mkdir .emacs.d
 C:\Users\Valen> New-Item -ItemType SymbolicLink -Path C:\Users\Valen\ -Name .emacs -Value 'C:\Users\Valen\Code\emacs_config\.emacs'
 C:\Users\Valen> New-Item -ItemType SymbolicLink -Path C:\Users\Valen\.emacs.d\ -Name settings -Value 'C:\Users\Valen\Code\emacs_config\.emacs.d\settings'
```

## Меняем домашнюю директорию
Так как emacs по-умолчанию считает домашней директорией `C:\Users\<Username>\AppData\Roaming`, открывать файлы в emacs не очень удобно (нужно постоянно возвращаться в `C:\Users\<Username>`). Чтобы с этим побороться есть несколько способов:
1. Перенастроить переменную HOME\\
   Не мой вариант, потому что мне лень возиться с тем, чтобы объяснять Emacs'у, где у него HOME из винды
2. Переопределить переменную HOME\\
   Вот это мой варик, тут мне всё понятно

Для этого в конец .emacs дописываем следующий код:
```elisp
(if (string= system-type "windows-nt")
    (setenv "HOME" "C:\\Users\\Valen"))
```

## emacs --daemon и emacsclient
Я достаточно долго (пару часов) гуглил, чтобы решить ряд непонятных ошибок, поэтому в этом разделе, думаю, самое ценное.

Во-первых, мне бы хотелось пользоваться emacsclient, потому что в 2021 году emacs всё ещё стартует непозволительно долго.\\
Во-вторых, мне не хотелось запускать `emacs --daemon` при каждом старте системы. Ну просто потому что.

Выход я нашёл следующий: если запускать emacsclient с ключом `-a` (который запускает альтернативный редактор, если emacsclient не запустился) равным пустой строке, то emacsclient сам пытается запустить `emacs --daemon` и подключиться к нему. Наш вариант!

Для того, чтобы это всё заработало, надо удалить папку `C:\Users\Valen\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Emacs-<version>`, в которой находятся ярлыки, созданные при установке Emacs.

Далее в папке `C:\Users\Valen\AppData\Roaming\Microsoft\Windows\Start Menu\Programs` нужно создать ярлык с названием Emacs и в свойстве `target` указать следующее:
```
"C:\Program Files\Emacs\x86_64\bin\emacsclient.exe" -c -n -f "c:\Users\Valen\.emacs.d\server\server" -a=
```
Где `-f "c:\Users\Valen\.emacs.d\server\server"` указывает на файл сокета. Помните, мы меняли домашнюю директорию? Так вот да, есть последствия.

## Перенастройка
Linux'овый конфиг Emacs'а не давал нормально запускаться. Пришлось искать и лечить.

В частности, пришлось отключить pinentry-интеграция (в винде она всё равно не актуальна):
```elisp
(if (string= system-type "gnu/linux")
    (progn (setenv "INSIDE_EMACS" (format "%s,comint" emacs-version))
           (setq epa-pinentry-mode 'loopback)
           (pinentry-start)))
```

## PowerShell
Для полного счастья не хватало только PowerShell в shell-mode. Делается это добавлением следующего в конфиг Emacs:
```elisp
(if (string= system-type "windows-nt")
    (setq
     shell-file-name "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
     explicit-powershell.exe-args '("-InputFormat" "Text" "-NoLogo")))
```

Правда, автодополнение не завелось пока что.

## Что ещё?
Очевидно, не завелись ни grep, ни silversearcher-ag, что печалит. Но наверняка найдётся выход и из этого положения.\\
Плюс я не занимался вопросом интеграции с git, потому что, очевидно, под виндой не занимаюсь написанием кода.

## Небольшое заключение
В WSL2 он (Emacs) всё ещё работает быстрее а пользоваться им удобнее. Поэтому я всё-таки сделал symlink `/mnt/c/Users/Valen → ~/winhome` и пользуюсь WSL'ным.

А, да, на днях вышел анонс Surface Laptop Studio, так что я пожалел, что взял Lenovo Carbon. Но теперь я знаю, что на винде есть жизнь.
