---
layout: post
title:  "Emacs как средство публикации записей"
date:   2014-05-24
categories: blog
---

# Предисловие

Итак, это наконец-то случилось. Допилил экспорт из Emacs в html с нормальным sitemap'ом. Теперь буду как все социокуртизанки постить про всё подряд. Ага.

# Что использовалось

Для публикации записей использован замечательный [org-mode](http://www.emacswiki.org/emacs/OrgMode).

Для запиливания были использованы [сайт org-mode](http://orgmode.org/) и [stackoverflow](http://stackoverflow.com/).

# Как сделано

Итак, начнём.

## Базовые штуки

### projects.el

Именно [в этом файле](https://github.com/vemperor/Blog-Source/blob/master/projects.el) находится основная конфигурация проекта.

Кроме материалов мануала ничего не использовалось, поэтому комментировать нечего.

Немного фарш, конечно, и raw html в конфиге. Но с этим я пока возиться не стал. Может быть когда-нибудь сделаю нормально.

### customized-org-html.el

1.  org-export-html

    Ввиду того, что оригинальный org-export-html делает пару вещей не так, пришлось [сделать свою функцию экспорта](https://github.com/vemperor/emacs_config/blob/20999812763e86b95dfe84c3d57bbe8c1f28c416/.emacs.d/global/customized-org-html.el#L587) (копипаста оригинала, C-s и C-S-%). Также пришлось сделать [собственную функцию публикации](https://github.com/vemperor/emacs_config/blob/20999812763e86b95dfe84c3d57bbe8c1f28c416/.emacs.d/global/customized-org-html.el#L45).

2.  Ссылки на файлы

    Org-mode умеет красиво делать ссылки на файлы (в моём случае — картинки). Но не очень красиво их заворачивает при экспорте. Слава [stackoverflow](http://stackoverflow.com/), я нашёл [решение](http://stackoverflow.com/questions/14684263/how-to-org-mode-image-absolute-path-of-export-html). Приведу здесь код

        (defun org-custom-link-img-follow (path)
          (org-open-file-with-emacs
           (format "../images/%s" path)))

        (defun org-custom-link-img-export (path desc format)
          (cond
           ((eq format 'html)
            (format "<img src=\"/images/%s\" alt=\"%s\"/>" path desc))))

        (org-add-link-type "img" 'org-custom-link-img-follow 'org-custom-link-img-export)

    **UPD**
    Также добавил тип ссылок с превью img-t. И сейчас же его использую, чтобы потом возвращаться к тексту поста. Автор фотографии — [Глеб Гончаров](http://gongled.ru/).

    ![Тестовое изображение](/assets/img/posts/2014-05-24-emacs-blogging/test.jpg)

## Разные плюшки

С основной частью мы разобрались, теперь про остальное.

### Стили

Для внешнего вида решил пользовать [pure css](http://purecss.io/). Приятный и простой css-framework, показался мне симпатичным.

Подключается всё это дело через шаблоны (org-template). Вот код шаблона

    #+AUTHOR:    Emperor
    #+EMAIL:     valentine.emperor@gmail.com
    #+STYLE: <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/pure/0.4.2/pure-min.css">
    #+STYLE: <link rel="stylesheet" type="text/css" href="/stylesheets/post-style.css" />
    #+STYLE: <link rel="stylesheet" type="text/css" href="/stylesheets/post-layout.css" />
    #+STYLE: <link rel="stylesheet" type="text/css" href="/stylesheets/menu.css" />

    #+STYLE: <script async="true" src="/javascript/run_prettify.js"></script>
    #+STYLE: <link rel="stylesheet" type="text/css" href="/stylesheets/google-code-prettify/desert-theme.css" />

    #+OPTIONS: toc:t
    #+LANGUAGE: ru

1.  Подсветка кода

    Для подсветки кода используется [google-code-prettify](http://code.google.com/p/google-code-prettify/). Как видно выше, в шаблоне подключаются соответствующие .js и .css. Также перепилена [функция экспорта кода](https://github.com/vemperor/emacs_config/blob/20999812763e86b95dfe84c3d57bbe8c1f28c416/.emacs.d/global/customized-org-html.el#L147).

### Меню

Для меню у меня отдельный кусок html-кода, который нагло украден со [страницы соответствующего layout'а pure css](http://purecss.io/layouts/side-menu/). Подключается отдельным org-файлом. К сожалению, приходится подключать вручную в каждом файле поста. Щито поделать, десу.

### Карта сайта (aka index.html)

Тут основные настройки прописаны в projects.el.

Стоит только отметить, что для sitemap'а отдельный шаблон. Ради этого была препилена [функция генерации sitemap'а](https://github.com/vemperor/emacs_config/blob/20999812763e86b95dfe84c3d57bbe8c1f28c416/.emacs.d/global/customized-org-html.el#L53). Приведу текст шаблона.

    #+AUTHOR:    Emperor
    #+EMAIL:     valentine.emperor@gmail.com
    #+STYLE: <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/pure/0.4.2/pure-min.css">
    #+STYLE: <link rel="stylesheet" type="text/css" href="stylesheets/sitemap-style.css" />
    #+STYLE: <link rel="stylesheet" type="text/css" href="stylesheets/sitemap-layout.css" />

    #+HTML_CONTAINER: div

    #+OPTIONS: toc:nil
    #+LANGUAGE: ru

Очевидно, что отличается он только layout'ом.

# Что дальше

~~Теперь надо прикрутить комменты из google+~~ **добавил disqus**, angular/jquery/_что ещё там напридумывали для жабоскрапта_ для некоторой интерактивности, допилить стили. В первую очередь надо прикрутить сворачиваемость кода и содержания.
