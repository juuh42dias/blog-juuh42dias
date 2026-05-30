---
layout: post
title: "WIP: Série Hoje Aprendi"
date: 2022-06-25 21:20:54 +0000
categories: todayilearned hojeaprendi
tags: todayilearned hojeaprendi
description: "Este será um post com pequenas coisas do dia a dia que vou aprendendo e vou inserindo aqui, ele será..."
canonical_url: https://dev.to/juuh42dias/wip-serie-hoje-aprendi-nal
source: dev.to
---

Este será um post com pequenas coisas do dia a dia que vou aprendendo e vou inserindo aqui, ele será um eterno WIP post (vamos ver até onde o Dev.to vai me permitir hehe):

##Docker
`docker build . --platform linux/amd64`
###Contexto: 
Estavam rodando uma build do docker no Macbook M1 e ele estava gerando coisas dentro da imagem com base ARM

_Referência:_ https://docs.docker.com/engine/reference/commandline/build/#options

##Systemd
`systemd-run --scope -p MemoryMax=5024M --user rspec spec/`
###Contexto:
Eu estava precisando limitar a quantidade de memória de um processo na máquina que estava usando, pois os testes que estava rodando consumiam MUITA memória :sweat_smile: 
ps: Adicionando o --user para usar o contexto o user e reduzir o escopo de acesso do processo
Dica adicionada por @lucas59356 - X

_Referência:_ https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html

##Rails - ActiveRecord
`User.attribute_types`
`User.columns`
`User.columns_hash`
###Contexto:
Estava apenas querendo saber os tipos de dados do model/tabela sem ter que sair do console do Rails

_Referência_
https://github.com/rails/rails/blob/main/activerecord/lib/active_record/model_schema.rb#L428

##Ruby - Object/Method
```
Time.method(:parse).parameters
 => [[:req, :date], [:opt, :now]]
```
###Contexto:
Estava querendo saber os paramêtros que uma classe esperava em seu construtor e eu não tinha acesso a tal arquivo pra ler  essa classe, dúvida sanada por @leandroico. 
 
_Referência_ 
https://ruby-doc.org/core-2.6.4/Method.html#method-i-parameters

##Rails - ActiveRecord/Reflections
```
3.0.4 :035 > Decidim::User.reflections.keys
 =>
["resource_links_to",
 "resource_links_from",
 "resource_permission",
 "follows",
 "followers",
 "organization"
...
```

###Contexto:
Estava apenas querendo saber as associations de um model (que usa ActiveRecord) sem ter que ficar percorrendo e vasculhando mil arquivos.
Ás vezes temos models e ou usamos classes que estão "escondidas" em gems ou nos internals do framework e não temos acesso fácil via editor.

_Referência_
https://api.rubyonrails.org/classes/ActiveRecord/Reflection/ClassMethods.html#method-i-reflections


##MacOS - log
```shell
log stream
```

###Contexto:
Meu Bluetooth parou do nada de funcionar no Ubuntu e resolvi então reiniciar, mas ainda suspeitando do que poderia ter acontecido resolvi rodar o dmesg pra analisar, com isso pensei se existia um comando parecido para o MacOS.

_Referência_
https://ss64.com/mac/log.html