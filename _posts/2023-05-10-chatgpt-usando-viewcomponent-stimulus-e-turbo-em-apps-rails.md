---
layout: post
title: "ChatGPT: Usando ViewComponent, Stimulus e Turbo em apps Rails"
date: 2023-05-10 23:51:44 +0000
categories: 
tags: 
description: "Rails é um framework de desenvolvimento web poderoso que torna fácil criar aplicativos da web ricos..."
canonical_url: https://dev.to/juuh42dias/chatgpt-usando-viewcomponent-stimulus-e-turbo-em-apps-rails-1i36
source: dev.to
---

Rails é um framework de desenvolvimento web poderoso que torna fácil criar aplicativos da web ricos em recursos. Entre as ferramentas que o Rails oferece, há o ViewComponent, Stimulus e Turbo, que permitem construir componentes reutilizáveis, adicionar interatividade do lado do cliente e aumentar a velocidade da navegação.

Neste blog post, vamos explorar como usar ViewComponent, Stimulus e Turbo em aplicações Rails, com exemplos simples.

## ViewComponent

ViewComponent é uma maneira de encapsular a lógica da view em componentes reutilizáveis que podem ser usados em várias páginas. Os componentes podem ter seu próprio controlador e modelo, e isso ajuda a manter a separação de responsabilidades e reduzir a complexidade do código.

Para criar um componente usando ViewComponent, crie um arquivo na pasta `app/components` com o nome do componente e adicione o código HTML e Ruby que definem o comportamento do componente. Por exemplo, vamos criar um componente simples que exibe um título e uma descrição:

```ruby
# app/components/my_component.rb
class MyComponent < ViewComponent::Base
  def initialize(title:, description:)
    @title = title
    @description = description
  end
end
```

```html
<!-- app/components/my_component.html.erb -->
<div class="my-component">
  <h1><%= @title %></h1>
  <p><%= @description %></p>
</div>
```

Então, você pode usar o componente em uma view chamando o método `render` passando o nome do componente e os parâmetros:

```html
<!-- app/views/pages/home.html.erb -->
<%= render MyComponent.new(title: 'Hello', description: 'World') %>
```

## Stimulus

Stimulus é uma biblioteca JavaScript que ajuda a adicionar interatividade do lado do cliente a uma aplicação Rails. É uma alternativa mais simples e fácil de usar ao React ou Vue.js. Ele se concentra em adicionar comportamento aos elementos existentes na página, em vez de criar novos componentes do zero.

Para começar a usar o Stimulus em uma aplicação Rails, você precisa instalá-lo e configurá-lo. Isso é feito facilmente adicionando o seguinte código ao arquivo `app/javascript/packs/application.js`:

```javascript
import { Application } from "stimulus"
import { definitionsFromContext } from "stimulus/webpack-helpers"

const application = Application.start()
const context = require.context("./controllers", true, /\.js$/)
application.load(definitionsFromContext(context))
```

Isso carrega todos os controladores Stimulus definidos na pasta `app/javascript/controllers`. Para criar um controlador, crie um arquivo JavaScript na pasta `app/javascript/controllers` e defina um controlador como este:

```javascript
// app/javascript/controllers/hello_controller.js
import { Controller } from "stimulus"

export default class extends Controller {
  static targets = [ "name" ]

  greet() {
    console.log(`Hello, ${this.name}!`)
  }

  get name() {
    return this.nameTarget.value
  }
}
```

Este controlador é usado em um elemento HTML com o atributo `data-controller` e os atributos `data-target` e `data-action` definidos:

```html
<!-- app/views/pages/home.html.erb -->
<div data-controller="hello">
  <input type="text" data-target="hello.name">
  <button data-action="click->hello#greet">Greet</button>
</div>
```

Vamos ver agora como usar o Turbo em uma aplicação Rails.

## Turbo

Turbo é uma nova tecnologia do Rails que ajuda a aumentar a velocidade da navegação em uma aplicação web. Ele usa técnicas como cache e pré-renderização para tornar as transições entre páginas mais rápidas e suaves.

Para começar a usar o Turbo em uma aplicação Rails, você precisa incluir a biblioteca do Turbo no arquivo `app/javascript/packs/application.js`:

```javascript
import Rails from "@rails/ujs"
import * as Turbo from "@hotwired/turbo"

Rails.start()
Turbo.start()
```

Com o Turbo instalado e configurado, agora podemos usar o `turbo-frame` para carregar conteúdo dinamicamente sem atualizar a página. Por exemplo, vamos supor que queremos carregar uma lista de usuários em uma página:

```html
<!-- app/views/users/index.html.erb -->
<h1>Usuários</h1>
<turbo-frame id="users">
  <%= render partial: 'users_list', locals: { users: @users } %>
</turbo-frame>
```

```html
<!-- app/views/users/_users_list.html.erb -->
<ul>
  <% users.each do |user| %>
    <li><%= user.name %></li>
  <% end %>
</ul>
```

Neste exemplo, estamos renderizando a lista de usuários em um componente parcial `_users_list.html.erb` e incluindo-o dentro de um `turbo-frame` com o ID `users`. Quando o usuário acessa a página pela primeira vez, a lista de usuários é carregada normalmente. No entanto, quando o usuário navega para outra página e volta para a lista de usuários, o Turbo usa cache e pré-renderização para carregar a lista de usuários instantaneamente, sem fazer uma nova solicitação ao servidor.

Conclusão

O ViewComponent, Stimulus e Turbo são ferramentas poderosas para construir componentes reutilizáveis, adicionar interatividade do lado do cliente e aumentar a velocidade da navegação em uma aplicação Rails. Espero que este blog post tenha sido útil e que você possa começar a usar essas ferramentas em sua própria aplicação!