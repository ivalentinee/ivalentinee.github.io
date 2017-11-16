---
layout: post
title:  "Redux-form с валидациями и сабмитом из браузера"
date:   2017-11-16
categories: programming
---

## Проблема

Надо было сделать мне форму для объекта `product`. Причём в отношении инпутов (селекты, текст) нужна была долбанутая логика, при этом нужно было всё ещё и с файлами (`multipart/form-data`), которые потом скармливаем, например, [CarrierWave'у](https://github.com/carrierwaveuploader/carrierwave). Да ещё это и с рельсами завернуть, плюс основную часть данных загружать нужно в jsonb (потому что структура может быть динамической), а некоторые значения надо было в обычные поля (`varchar`, `text`) в базу сохранять.

Ввиду необходимости впиливать сложную логику, валидации и нормализации и простой человеческой привычке (ну привык я с этим пакетом работать), я решил использовать [redux-form](https://redux-form.com/). Хороший пакет для форм, всем рекомендую. Но в некоторых местах его не особо "похачишь", многое спрятано внутрь, увы.

Я принял решение, что не хочу возиться с сериализацией и отправкой **всех** данных (включая файлы), поэтому `submit` надо использовать обычный браузерный (не из redux-form).

Данное решение — жуткий костыль! Так лучше не делать! Но мне было настолько лень придумывать, как сделать по-нормальному, что я ~~решил не думать~~ пошёл на компромисс.

## Исходные данные

Пускай основным полем у нас будет `data`, который в postgresql сохраняется в jsonb, вторым будет поле `attachment` для файла, а третьим — `description`, который по неизвестным причинам мы будем сохранять в отдельное поле типа `text`.

При этом для поля `data` надо было динамически собирать инпуты и делать валидации. По этой причине и впилил реакт с redux-form, ибо делать это всё на зашкварии — так себе занятие.

## Немного кода из Rails
Исходя из предположения, что используется [strong parameters](https://github.com/rails/strong_parameters), код в рельсах будет примерно такой:
```ruby
# app/controllers/admin/products_controller.rb
class Admin::ProductsController < Admin::ApplicationController
  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to admin_products_path
    else
      render :new
    end
  end

  private

  def product_params
    data = JSON.parse(params.require(:product).require(:data))
    params.require(:product).permit(:attachment, :description).merge(
      data: data
    )
  end
end
```

Ввиду того, что `Content-Type: multipart/form-data` у нас не `application/json`, парсить `data` приходится руками. Грустно, но что поделаешь. Иначе рельсы сохранят строкой в jsonb.

Ну и немного кода под [react_on_rails](https://github.com/shakacode/react_on_rails), если по этому будут какие-то вопросы:
```haml
-# app/views/admin/products/new.haml
%h1 Создание продукта
= react_component("Product.Form", props: { method: 'post', data: @product.data || {}, url: admin_products_path, authenticityToken: form_authenticity_token })
```

## А теперь про фронт

Надеюсь на то, что читатели знают, что такое [**redux-form**](https://redux-form.com/), и как с ним управляться. Поэтому сразу к мякотке:
```javascript
// Код условный, у нас в конторе принят свой способ написания валидаций для redux-form, откуда можно получить список валидируемых полей
const validatedFields = ['title', 'price'];

class Form extends Component {
  // ...

  // Вот щас будет самое оно
  submit = (e) => {
    const { dispatch, asyncValidate, valid, touch } = this.props;
    // диспатчим touch, чтобы поля подсветились после проверки
    validatedFields.forEach(attribute => dispatch(touch(attribute)));
    // вызываем валидацию
    asyncValidate();
    if (!valid) {
      // тормозим Event('submit'), если валидации не пройдены
      e.preventDefault();
    }
  }

  render = () => (
    <form onSubmit={this.submit} action={this.props.url} encType="multipart/form-data" acceptCharset="UTF-8" method="POST">
      <input name="utf8" value="✓" type="hidden" />
      <input type="hidden" name="_method" value={this.props.method} />
      <input name="authenticity_token" value={this.props.authenticityToken} type="hidden" />
      {/* вот тут мы сохраняем сериализованные параметры в поле data (хорошо я придумал, а?) */}
      <input name="product[data]" value={JSON.stringify(this.props.formValues)} type="hidden" />

      <Field name="title" component="input" type="text" />
      <Field name="price" component="input" type="text" />
      <Field name="disabled" component="input" type="checkbox" />
      {/* тут можно было бы прикрутить даже wysiwyg (ckeditor?), но риякт не даст таких вольностей, конечно =) */}
      <input name="product[description]" type="text" />
      <input name="product[attachment]" type="file" />

      <button type="submit">Сохранить товар</button>
    </form>
  )
}

const ConnectedForm = reduxForm({
  form: 'product',
  validate: someValidationCallback(validatedFields),
})(Form);

const FormWrapper = props => (
  <div>
    <ConnectedForm
      {...props}
      initialValues={props.data}
    />
  </div>
);

export default FormWrapper;
```

Замечу, что `formValues` — это текущие значения формы. Получаю их в редуксовом контейнере через [`getFormValues`](https://redux-form.com/7.1.2/docs/api/selectors.md/#-code-getformvalues-formname-string-code-returns-code-state-gt-formvalues-object-code-).

Как и в любой другой подобной ситуации, главная проблема такого подхода — приходится дёргать всё руками:
- Получать список полей. Я надеюсь, что у redux-form есть какой-то способ получить список полей, но я его не нашёл. Приходится забирать его из списка валидаций, что уже нехорошо.
- Руками запускать валидации, когда в обычном сценарии за меня это сделал бы `submit` из redux-form.
- `if (!valid) e.preventDefault()` — ну, такое. Хотя, конечно, работает =)
- Если надо что-то делать на форме, то тут рельсы с их килограммами хелперов тут не помогут, надо протаскивать все данные руками через `props` и верстать в jsx.

## Вместо выводов

Данное решение — костыль. И можно сделать по-нормальному. Следует избегать таких подходов.

Кстати, может кто-нибудь знает, можно ли как-то нормально jsx подсвечивать в jekyll?
