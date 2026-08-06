# PROMPT PARA O AGENTE DO BACKEND — Validade do token de autenticação

Você é o desenvolvedor da API/painel do AppColeta
(`https://institutoalveslima.com.br/painel/api`). Precisamos mudar a política
de validade do token de autenticação usado pelo aplicativo de coleta.

## O problema em campo

O token está expirando cedo demais. O aplicativo, por decisão de projeto, NÃO
faz logout automático quando o servidor recusa o token — se fizesse, o
aplicador perderia o acesso aos questionários que ainda não subiram. O
resultado é que ele continua coletando normalmente, offline, e só descobre que
a sessão venceu quando tenta sincronizar. Já aconteceu de um dia inteiro de
trabalho ficar parado no aparelho por causa disso.

O app já foi ajustado para avisar assim que percebe (aviso fixo no dashboard +
botão de login). Falta o lado do servidor: o token precisa durar o suficiente
para que isso quase nunca aconteça.

## O que fazer

### 1. Validade mínima de 4 semanas

O token emitido em `POST /auth/login` deve valer **no mínimo 28 dias**.

- Se for JWT: `exp` = emissão + 28 dias (ou mais).
- Se for token opaco em banco: a coluna de expiração deve receber
  `NOW() + INTERVAL 28 DAY` (ou mais).
- Se hoje existe algum TTL menor (sessão do PHP, `session.gc_maxlifetime`,
  cookie, cache), ele não pode encurtar essa validade por tabela.

### 2. Renovação deslizante em `GET /auth/verify`

Esta é a parte que resolve de vez, e o app **já está preparado para ela**.

O aplicativo chama `GET /auth/verify` toda vez que é aberto com internet.
Nessa resposta, quando o token estiver válido, **inclua um token novo** com
prazo cheio (mais 28 dias a partir de agora):

```json
{
  "success": true,
  "user": { "...": "..." },
  "token": "<novo token, validade renovada por 28 dias>"
}
```

O app grava esse token no lugar do anterior automaticamente. O efeito é que
um aplicador que abrir o aplicativo pelo menos uma vez a cada 4 semanas nunca
expira — e quem ficar mais tempo sem abrir volta a depender do prazo fixo do
item 1.

Regras:

- O campo `token` é **opcional** na resposta. Se ele não vier, o app mantém o
  token atual e nada quebra — dá para implementar o item 1 primeiro e o 2
  depois.
- Só renove quando o token apresentado for **válido**. Token expirado ou
  inválido continua respondendo o que responde hoje (ver item 3).
- O token antigo pode continuar válido até o prazo original; não é necessário
  invalidá-lo no momento da troca.

### 3. Manter o contrato de erro atual

Não mude o comportamento de token inválido. Hoje é assim, e o app depende
disso para mostrar o aviso de sessão expirada:

```
HTTP 401
{"success": false, "message": "Invalid token"}
```

O app reconhece pelo **status 401**, não pelo texto — então traduzir a
mensagem é seguro, mas o status precisa continuar 401.

## Como testar

1. **Validade**: fazer login, decodificar o token (ou consultar a tabela) e
   conferir que a expiração está a 28 dias ou mais.
2. **Renovação**: chamar `GET /auth/verify` com um token válido e conferir que
   a resposta traz um `token` diferente do enviado, com prazo recontado.
3. **Erro preservado**: chamar qualquer rota com token inválido e conferir que
   ainda responde `401` com `success: false`.

```bash
# Deve responder 401
curl -i -X POST https://institutoalveslima.com.br/painel/api/forms/submit \
  -H "Authorization: Bearer token_invalido" \
  -H "Content-Type: application/json" -d '{}'
```

## O que NÃO fazer

- **Não** remova a expiração nem use prazos do tipo 10 anos. Token de coleta
  fica em aparelho de campo, que se perde e é emprestado; 4 a 8 semanas é o
  equilíbrio entre não atrapalhar o trabalho e não deixar credencial eterna
  circulando.
- **Não** troque o token em requisições que não sejam `/auth/verify`. O app só
  sabe capturar a renovação nesse ponto; um token novo devolvido em
  `/forms/submit`, por exemplo, seria ignorado e o aparelho continuaria com o
  antigo.
