---
layout: post
title:  "Решил я тут побложить немного снова, надеюсь, получится"
date:   2017-05-17
categories: blog
---

А почему нет. Пробовал я как-то побложить отдельно про настолки. [Не вышло](http://rolygamer.tumblr.com/). Думаю, что просто бложить надо про то, что сейчас болит, а не что может заболеть у потенциального_посетителя.

А надо ли вообще бложить-то? Стоит оно того? Думаю, стоит. Ради нескольких вещей:

1. Ретроспектива. Всегда полезно возвращаться к старому себе и думать “эх, какой же я был примитивный ~~обезьян~~” и ~~удалять посты~~ исправляться.
2. А вдруг кому-то мои мысли/открытия/изобретения/лайфхаки действительно пригодятся? Да нет, бред какой-то.
3. Срачи. Обычно я имею возможность вбрасывать только в ограниченных кругах лиц, прямо меня знающих не первый день. А тут, в теории, если набегут анонимы, то можно и <strike>покидаться друг в друга</strike> подискутировать по вопросу. Тем более что такие дискуссии зачастую бывают для меня жутко полезными.

Вот.

<!--more-->

Я не очень долго думал про платформу, но именно думал, а не гуглил, потому что гугление выдаёт сплошной вордпресс и прочие self-hosted <strike>поделки</strike> решения. ЖЖ — интерфейс примерно из позапрошлого века, хотя в нём и сейчас обитает знатное количество [интересных людей](http://lionet.livejournal.com/), [например](http://tonsky.livejournal.com/).

Попробовал тумблер завести по-быстому. Тумблер имеет богатый функционал из коробки и, самое главное, редактор, который действительно мне (хотя может только мне одному?) нравится. Простой, удобный, мышекликательный. Но возможности форматирования немного бедноваты, при попытках сделать подсветку кода не в markdown/html редакторе я был вынужден напилить знатный кусок ~~говна~~ кода на js.

Воскрешать старое решение, для которого приходилось патчить Emacs (благо это можно сделать без особых проблем прям в рантайме) и упарываться сборкой .org в блог для гитхаба руками... Ну так себе затея. Староват я для такого.

Так и скатился в jekyll. Ну хоть в Emacs'е можно редактировать, я не в WYSYWIG. Правда, markdown с его разрывами строк двумя пробелами... Зря они так, конечно. А Github Pages не поддерживают более textile, увы.

В планах сейчас
1. ~~В третий раз впилить disqus, потому что "а разве есть что-то ещё"~~ Таки впилил комменты из плюсача. Они красявше.
2. Перенести старые посты.

Вот, кстати, и этот блок ~~говна~~ кода на js.
~~~javascript
(function(){
  var requiredScripts = [
  ];
  var postElementClass = "post";
  var codeBlockElementTag = "blockquote";
  var codeWrapperTag = "p";
  var preElementClass = "prettyprint";
  var preElementLangClassPrefix = "lang-";
  var sourceLangRegexp = /highlight-source: ([\w]+)/;

  var importCodePrettify = function() {
    requiredScripts.forEach(function(src){
      var scriptElement = document.createElement('script');
      scriptElement.setAttribute('src', src);
      document.head.appendChild(scriptElement);
    });
  };

  var iterateOverDomElements = function(elements, func) {
    for(var i = 0; i < elements.length; i++) {
      var element = elements[i];
      func(element);
    };
  };

  var highlightCodeBlock = function(codeBlockElement) {
    var codeWrapper = codeBlockElement.getElementsByTagName(codeWrapperTag)[0];
    if (!sourceLangRegexp.test(codeWrapper.innerHTML)) return;

    var language = sourceLangRegexp.exec(codeWrapper.innerHTML)[1];

    var preElement = document.createElement('pre');
    preElement.className = preElementClass + " " + preElementLangClassPrefix + language;
    preElement.innerHTML = codeWrapper.innerHTML;

    codeBlockElement.insertBefore(preElement, codeWrapper);
    codeBlockElement.replaceChild(preElement, codeWrapper);
  };

  var highlightPostCodeBlocks = function(postElement) {
    var codeBlocks = postElement.getElementsByTagName(codeBlockElementTag);
    iterateOverDomElements(codeBlocks, highlightCodeBlock);
  };

  var highlightPostsCodeBlocks = function(){
    if (typeof window.PR === "undefined") return;

    var posts = document.getElementsByClassName(postElementClass);
    if (posts.length === 0) return;

    iterateOverDomElements(posts, highlightPostCodeBlocks);
    window.PR.prettyPrint();
  };

  document.addEventListener("DOMContentLoaded", highlightPostsCodeBlocks);
})();
~~~
