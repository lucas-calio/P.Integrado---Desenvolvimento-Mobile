# Documentação do Sistema STOX

O aplicativo STOX, idealizado pelo gerente Rafael Valentim, é uma solução de gestão de estoque desenvolvida para o Grupo JCN, com foco na integração em tempo real com o SAP Business One via Service Layer. Este documento centraliza os casos de uso, regras de negócio e a arquitetura técnica do projeto.

---

## 1. Casos de Uso
![Diagrama de Casos de Uso](diagramas/casos_de_uso.png)

[cite_start]O sistema foi desenhado para atender às necessidades operacionais e gerenciais de inventário, dividindo as interações entre dois atores principais[cite: 10]:
* [cite_start]**Operador:** Realiza o trabalho de campo, incluindo login, contagens simples e em equipe, consulta de itens no SAP, sincronização, exportação de CSV e impressão de etiquetas[cite: 10, 11].
* [cite_start]**Gerente:** Além das funções de contagem e sincronização, gerencia a importação de CSVs e a configuração da API[cite: 11].
* [cite_start]**Integrações Nativas:** Os casos de uso de contagem utilizam módulos embutidos de Scanner Universal (12 protocolos) e OCR via Inteligência Artificial (Google ML Kit) para agilizar a leitura[cite: 11, 12].

---

## 2. Histórias de Usuário (User Stories) e MVP
![User Stories](diagramas/user_stories.png)

[cite_start]O escopo do projeto foi dividido entre os requisitos do Produto Mínimo Viável (MVP) e funcionalidades futuras[cite: 32].

**Funcionalidades MVP (Implementadas):**
* [cite_start]Login integrado ao SAP, configuração de API, Scanner Universal, leitura de OCR e confirmação de salvamento de contagem[cite: 32].
* [cite_start]Múltiplas formas de sincronização (POST para simples, PATCH para equipe) e automação de IDs (CounterID)[cite: 32, 33].
* [cite_start]Ferramentas auxiliares como exportação/importação de CSV, exclusão múltipla e impressão de etiquetas TSPL via Bluetooth[cite: 33].

**Pós-MVP (Planejadas):**
* [cite_start]Relatórios avançados, detecção de divergências, dashboard gerencial, histórico por período e sugestão de reposição[cite: 33].

---

## 3. Fluxo de Sincronização Dual
![Fluxo de Sincronização](diagramas/fluxo_sincronizacao.png)

[cite_start]A arquitetura de sincronização do STOX possui inteligência para separar envios baseados no modo de contagem (`countingMode`)[cite: 15, 16]:

* **Contagem Simples (`single`):**
    * [cite_start]O aplicativo monta um payload `POST` agrupando quantidades por `ItemCode` e define a regra de negócio `BatchNumber = ItemCode`[cite: 16, 17].
    * [cite_start]Em caso de sucesso (HTTP 200/201), o status local muda para sincronizado e os dados são removidos[cite: 17, 18]. [cite_start]Erros como "Contagem já aberta no SAP" (-1310) ou "Sessão expirada" (401) possuem tratamentos específicos[cite: 19, 20].
* **Contagem em Equipe (`multiple`):**
    * [cite_start]Exige a seleção prévia de um documento[cite: 23].
    * [cite_start]O App busca o documento original via `GET`, mapeia o `ItemCode` para a respectiva `LineNumber` vinculada ao `counterID` e envia um `PATCH` atualizando apenas as linhas de responsabilidade daquele usuário[cite: 24, 25].
    * [cite_start]Erros de inconsistência de contagem (234000012) ou linhas duplicadas (-5002) são interceptados[cite: 28, 29].

---

## 4. Arquitetura do Sistema
![Diagrama de Arquitetura](diagramas/arquitetura.png)

[cite_start]O STOX foi construído em Flutter (Android) utilizando uma arquitetura modularizada[cite: 1]:
* [cite_start]**Camada de Interface (`pages/`):** Telas principais como Login, Home (com Drawer), Contadores Offline, Importação, Pesquisa, Etiquetas, Configuração e Splash Screen[cite: 1, 2].
* [cite_start]**Camada de Modelos (`models/`):** Define as regras de configuração de contagem e etiquetas[cite: 2].
* [cite_start]**Camada de Serviços (`services/`):** Concentra a lógica de negócios, gerenciando o `SapService` (comunicações HTTP com OData v4), `DatabaseHelper` (SQLite v3), `OcrService` (Google ML Kit), Exportações e Alertas audiovisuais[cite: 2, 3, 4].
* [cite_start]**Camada de Widgets (`widgets/`):** Componentes visuais reutilizáveis (Botões, Cards, Dialogs, Snackbars, Loading Skeletons)[cite: 3].

---

## 5. Esquema de Banco de Dados Local
![Schema do Banco de Dados](diagramas/banco_de_dados.png)

O armazenamento offline garante a continuidade do trabalho em áreas sem cobertura de rede. [cite_start]Ele é suportado pelo SQLite v3 e gerenciamento de SharedPreferences[cite: 5]:

* [cite_start]**Tabela `contagens`:** * Armazena o identificador do item (`itemCode`), quantidade, data/hora e código do depósito (`warehouseCode`)[cite: 5].
    * [cite_start]Registra o modo de operação (`countingMode`) e metadados do operador (`counterID`, `counterName`) e o status de sincronização (`syncStatus`)[cite: 5, 6].
* **SharedPreferences:**
    * [cite_start]Garante a persistência das configurações de conexão com a API do SAP, chaves de sessão ativas (`B1SESSION`, `ROUTEID`, `sap_user_internal_key`), e preferências de impressão/leitura[cite: 7, 8].