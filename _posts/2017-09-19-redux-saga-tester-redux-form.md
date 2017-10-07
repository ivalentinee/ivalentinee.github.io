---
layout: post
title:  "Redux-saga-tester и redux-form (или как меня подвёл поиск на гитхабе)"
date:   2017-09-19
categories: programming
---

## С чего началось

А началось всё с того, что я полез в эти ваши чёртовы фронтенды. Как-то давно надоело мне ковырять рельсы, и теперь я ещё и на жабаскрипте пописываю иногда.

И приспичило мне в [саге](https://github.com/redux-saga/redux-saga) сделать изменение в состоянии [redux-form](https://redux-form.com/). Соединим всё это с моим стремлением к [написанию всего через тесты]({% post_url 2017-06-05-TDD %}), и приехали. Всё сломалось.

Для особо нетерпеливых: можно сразу листать до раздела "решение".

## Что, собственно, случилось

Постарался привести максимально полный и приближённый к реальному код.

### Код, который тестирует
~~~javascript
import SagaTester from 'redux-saga-tester';
import sinon from 'sinon';
import { defer } from 'lodash';
import { change } from 'redux-form';
import getValueSaga from '../getValueSaga';
import SomeTypes from './SomeTypes';
import * as SomeActions from './SomeActions';

describe('getValueSaga test', () => {
  let sagaTester = null;
  let server = null;

  const path = '/get-value';
  const response = { value: true };

  beforeEach(() => {
    server = sinon.fakeServer.create();
    sagaTester = new SagaTester({ initialState });
    sagaTester.start(getValueSaga);
  });

  afterEach(() => {
    server = server.restore();
  });

  it('should get value and add it to form state', async () => {
    server.respondWith([200, {}, JSON.stringify(response)]);

    sagaTester.dispatch(SomeActions.getValue());

    defer(() => { server.respond(); });

    await sagaTester.waitFor(SomeTypes.GET_VALUE_SUCCESS);

    const request = server.requests[0];
    expect(request.url).toEqual(path);
    expect(request.method).toEqual('GET');

    expect(sagaTester.getCalledActions()).toContainEqual(change('some-form', 'value', response.value));
    expect(sagaTester.getLatestCalledAction()).toEqual(SomeActions.getValueSuccess());
  });
});
~~~

### Код, который тестируется

~~~javascript
import { call, put, takeLatest } from 'redux-saga/effects';
import { change } from 'redux-form';
import SomeTypes from './SomeTypes';
import * as SomeActions from './SomeActions';

function sendRequest(params) {
  const url = '/get-value';
  return axios.get(url).then(response => response.data);
}

function* getValueSaga(action) {
  try {
    const response = yield call(sendRequest);
    yield put(change('form-name', 'attribute-name', response.value));
    yield put(SomeActions.getValueSuccess());
  } catch (error) {
    // пропустим обработку ошибок
  }
}

export default function* watchGetValueSaga() {
  yield takeLatest(SomeTypes.GET_VALUE, getValueSaga);
}
~~~

### Проблема
Вот на этой строке тест ломается
~~~javascript
expect(sagaTester.getCalledActions()).toContainEqual(change('some-form', 'value', response.value));
~~~
С фразой "такой action не был вызван". Wut?

Ладно, пробуем проверять так:
~~~javascript
yield put({ type: "@@redux-form/change" });
~~~

Иии... Снова всё тоже, снова "такой action не был вызван".

Хмм...

В результате долгих экспериментов я выяснил, что все action'ы, которые начинаются с `@@redux` куда-то исчезают. Совпадение? Не думаю.

## Решение
Несколько часов (потому что я — идиот) поиска ключевой фразы сначала в `redux`, потом в `redux-saga`, потом в `redux-form` не дали ничего значимого. А вот поиск в `redux-saga-tester` дал [интересный результат](https://github.com/wix/redux-saga-tester/blob/247c908ff433964e385f41f13d8a3b95ca7af990/src/SagaTester.js#L45):
~~~javascript
if (ignoreReduxActions && action.type.startsWith('@@redux')) {
  // Don't monitor redux actions
~~~
И далее поиск приводит [сюда](https://github.com/wix/redux-saga-tester/blob/247c908ff433964e385f41f13d8a3b95ca7af990/test/SagaTester.spec.js#L51):
~~~javascript
const sagaTester = new SagaTester({ignoreReduxActions: false});
~~~

И ни единой строчки про это в документации в `redux-saga-tester`, как и про то, что он вообще отбрасывает все action'ы, которые начинаются с `@@redux`.

В результате, изменение соответствующей строки на такую:
~~~javascript
sagaTester = new SagaTester({ ignoreReduxActions: false, initialState });
~~~
решает проблему полностью.

## А при чём тут Github, собственно?
А при том, что искать по строке `@@redux` он не даёт, как и не даёт искать вообще что-либо с символом `@`.

В результате, протратив время на поиск в github по всем библиотекам, я был вынужден потом клонировать репозиторий каждой и грепать локально. Позор, Github!
