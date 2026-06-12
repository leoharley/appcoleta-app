# Tutorial - Controle de Estratificacao da Amostra (AppColeta)

## O que e?

O Controle de Estratificacao e um recurso do AppColeta que permite acompanhar, em tempo real, as cotas de coleta por perfil demografico de cada questionario. Ele ajuda os aplicadores a saberem quantas entrevistas ainda sao necessarias em cada categoria (ex: faixa etaria, genero, regiao), evitando coletas excedentes.

---

## Como funciona?

O sistema e dividido em **duas telas**:

---

## 1. Tela de Pre-visualizacao do Questionario

Ao selecionar um questionario para aplicar, antes de iniciar a coleta, o aplicador vera um **painel de estratificacao** abaixo das informacoes do questionario. Esse painel mostra:

- **Barra de Progresso Geral** - Mostra quantas entrevistas ja foram realizadas do total planejado (ex: `85/200 - 42.5%`)
- **Categorias de Estratificacao** - Cada categoria (ex: "Faixa Etaria", "Genero") aparece com sua propria barra de progresso
- **Detalhamento por Estrato** - Dentro de cada categoria, cada opcao (ex: "18-24 anos", "25-34 anos") mostra:
  - Um icone de status: circulo vazio (pendente) ou check laranja (cota atingida)
  - O nome da opcao
  - Uma mini barra de progresso individual
  - A contagem atual/meta (ex: `15/30`)

### Exemplo visual do painel:

```
  Estratificacao - Pesquisa Municipal
   Progresso Geral                    85/200 (42.5%)
   ||||||||||||..............................

   -- Faixa Etaria --                 45/100
   ||||||||||||||||....................

   o 18-24 anos          ||||....  10/30
   o 25-34 anos          |||||...  15/30
   v 35-44 anos          ||||||||  20/20  (cota atingida)
   o 45+ anos            ........   0/20

   -- Genero --                       40/100
   ||||||||||||..........................

   o Masculino           ||||....  20/50
   o Feminino            ||||....  20/50
```

> **Obs:** Se o questionario nao tiver estratificacao configurada, o painel simplesmente nao aparece. Se o aplicador estiver offline, o painel tambem nao aparece (a coleta continua normalmente).

---

## 2. Alerta Durante o Preenchimento

Quando o aplicador esta respondendo o questionario e seleciona uma opcao cuja cota ja foi atingida, o app exibe um **alerta flutuante na parte inferior da tela** com a mensagem:

> *"Atencao: A cota para [opcao] na categoria [categoria] ja foi atingida (20/20)."*

**Importante:**
- O alerta e **apenas informativo** - ele **NAO bloqueia** o preenchimento
- O aplicador pode continuar normalmente e enviar o questionario mesmo com a cota atingida
- O alerta desaparece automaticamente apos 4 segundos

---

## Regras de Funcionamento

| Aspecto | Comportamento |
|---|---|
| **Conectividade** | As cotas sao carregadas do servidor ao abrir o questionario. Sem internet, o painel nao aparece, mas a coleta funciona normalmente |
| **Bloqueio** | O sistema **nunca bloqueia** o envio de um formulario. Os alertas sao apenas informativos |
| **Atualizacao** | As cotas sao atualizadas cada vez que o aplicador abre a tela de pre-visualizacao do questionario |
| **Visibilidade** | Se o questionario nao possui estratificacao configurada no painel administrativo, nenhum elemento extra aparece no app |

---

## Fluxo Resumido

```
1. Aplicador seleciona o questionario
2. Tela de pre-visualizacao carrega -> painel de cotas aparece
3. Aplicador visualiza o progresso por categoria
4. Clica em "Iniciar Questionario"
5. Durante o preenchimento, se selecionar uma opcao com cota cheia -> alerta informativo
6. Aplicador continua normalmente e envia o formulario
```

---

## Configuracao (Painel Administrativo)

A estratificacao e configurada pelo **administrador no painel web**, definindo:
- Quais perguntas do questionario serao controladas por cotas
- Qual a meta (quantidade alvo) para cada opcao de resposta
- O sistema calcula automaticamente o progresso conforme os formularios sao enviados

---

*Versao 2.0 - AppColeta*
