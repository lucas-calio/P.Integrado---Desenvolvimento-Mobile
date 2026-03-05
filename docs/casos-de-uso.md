# Casos de Uso — Projeto STOX

## Disciplina
Engenharia de Software

## Projeto
STOX — Intelligent Inventory Management Platform

## Descrição

O STOX é uma plataforma mobile desenvolvida para automatizar processos de inventário integrados ao SAP Business One.  
O sistema permite realizar contagem de estoque utilizando leitura de código de barras e visão computacional com IA.

---

# Caso de Uso 01 — Realizar Login

**Ator:** Usuário (Operador de Inventário)

**Objetivo:**  
Permitir que o usuário acesse o sistema STOX através de autenticação válida.

## Pré-condições

- Usuário possui conta cadastrada
- Sistema possui integração com SAP Business One
- Conexão com internet disponível

## Pós-condições

- Sessão autenticada
- Usuário redirecionado para o dashboard

## Fluxo Principal

1. Usuário abre o aplicativo STOX.
2. Sistema apresenta tela de login.
3. Usuário informa e-mail e senha.
4. Sistema envia credenciais para autenticação.
5. Sistema valida dados no SAP Business One.
6. Sistema inicia sessão do usuário.
7. Usuário acessa o dashboard do sistema.

## Fluxos Alternativos

### A1 — Credenciais inválidas

1. Sistema detecta erro na autenticação.
2. Sistema exibe mensagem de erro.
3. Usuário retorna ao passo 3 do fluxo principal.

### A2 — Falha de conexão

1. Sistema não consegue conectar ao SAP.
2. Sistema exibe mensagem de erro.
3. Usuário pode tentar novamente.

## Regras de Negócio

RN01 — Usuário deve possuir permissão de acesso ao sistema.  
RN02 — Sessão expira após período de inatividade.

## Requisitos Relacionados

RF01 — Autenticação de usuário  
RF02 — Integração com SAP Service Layer  

RNF01 — Comunicação segura via HTTPS  
RNF02 — Tempo de resposta inferior a 3 segundos

---

# Caso de Uso 02 — Realizar Contagem de Estoque

**Ator:** Usuário (Operador de Inventário)

**Objetivo:**  
Registrar a quantidade de produtos em estoque utilizando leitura de código de barras ou contagem automática com inteligência artificial.

## Pré-condições

- Usuário autenticado
- Produtos sincronizados com SAP
- Inventário ativo

## Pós-condições

- Quantidade registrada no inventário
- Dados armazenados no sistema

## Fluxo Principal

1. Usuário seleciona um inventário ativo.
2. Usuário escaneia o código de barras do produto.
3. Sistema identifica o produto no banco de dados.
4. Usuário captura imagem do conjunto de peças.
5. Sistema envia imagem para o motor de IA.
6. IA detecta e conta os itens.
7. Sistema apresenta resultado ao usuário.
8. Usuário confirma contagem.
9. Sistema registra contagem no inventário.

## Fluxos Alternativos

### A1 — Produto não encontrado

1. Sistema não encontra produto correspondente.
2. Sistema exibe alerta.
3. Usuário tenta escanear novamente.

### A2 — Falha na contagem automática

1. Sistema não consegue detectar os itens.
2. Sistema solicita nova captura de imagem.

## Regras de Negócio

RN03 — Produto deve existir no cadastro do SAP.  
RN04 — IA deve atingir nível mínimo de confiança na detecção.  
RN05 — Usuário pode ajustar a contagem manualmente.

## Requisitos Relacionados

RF03 — Leitura de código de barras  
RF04 — Captura de imagem  
RF05 — Contagem automática via IA

RNF03 — Processamento de imagem inferior a 5 segundos

---

# Caso de Uso 03 — Sincronizar Inventário com SAP

**Ator:** Usuário / Sistema SAP

**Objetivo:**  
Atualizar o estoque oficial do SAP Business One com os dados coletados no aplicativo STOX.

## Pré-condições

- Usuário autenticado
- Inventário finalizado
- Conexão com SAP Service Layer ativa

## Pós-condições

- Estoque atualizado no SAP
- Inventário registrado no ERP

## Fluxo Principal

1. Usuário finaliza inventário no aplicativo.
2. Sistema prepara dados de contagem.
3. Sistema envia dados para API do SAP.
4. SAP processa atualização do estoque.
5. SAP retorna confirmação.
6. Sistema registra sucesso da operação.
7. Usuário visualiza relatório final.

## Fluxos Alternativos

### A1 — Falha de comunicação com SAP

1. Sistema não recebe resposta do SAP.
2. Sistema salva dados localmente.
3. Sistema tenta sincronizar novamente posteriormente.

## Regras de Negócio

RN06 — Apenas inventários finalizados podem ser sincronizados.  
RN07 — Cada item deve possuir identificador correspondente no SAP.

## Requisitos Relacionados

RF06 — Integração com SAP Business One  
RF07 — Atualização de estoque

RNF04 — Garantia de consistência de dados

---

# Relação Caso de Uso → User Stories → MVP

Caso de Uso relacionado: **Realizar Contagem de Estoque**

## User Stories do MVP

US01  
Como operador de inventário  
Quero fazer login no aplicativo  
Para acessar o sistema.

US02  
Como operador  
Quero escanear o código de barras do produto  
Para identificar rapidamente o item.

US03  
Como operador  
Quero capturar imagem dos produtos  
Para permitir que a IA realize a contagem automática.

US04  
Como operador  
Quero confirmar ou ajustar a contagem  
Para garantir a precisão dos dados.

US05  
Como operador  
Quero sincronizar o inventário com o SAP  
Para atualizar o estoque oficial.

---

# Diagrama de Casos de Uso (PlantUML)

```plantuml
@startuml
title STOX - Diagrama de Casos de Uso

actor Usuario
actor "SAP Business One" as SAP
actor "Motor de IA (YOLO)" as IA

rectangle Sistema {

Usuario --> (Realizar Login)

Usuario --> (Realizar Contagem de Estoque)

Usuario --> (Sincronizar Inventario com SAP)

(Realizar Contagem de Estoque) --> (Processar Contagem com IA)

(Processar Contagem com IA) --> IA

(Sincronizar Inventario com SAP) --> SAP

}

@enduml