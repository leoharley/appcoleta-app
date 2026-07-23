# PROMPT PARA O AGENTE DO BACKEND/PAINEL — Ajustes solicitados pelo cliente

Você é o desenvolvedor do painel administrativo e da API do AppColeta. Implemente
os ajustes abaixo. Todos são do lado do servidor/painel — o app móvel já foi
ajustado na parte que lhe cabe.

## 1. Permissão de acesso aos questionários (CRÍTICO)

**Problema:** os aplicadores veem TODOS os questionários cadastrados, mesmo com a
"seleção de pesquisadores" configurada no painel.

**Causa:** `GET /api/questionnaires` retorna todos os questionários ativos sem
filtrar pelo usuário do token. O app não recebe nenhuma informação de atribuição
e portanto não tem como filtrar.

**Correção:** no endpoint `GET /api/questionnaires`, quando o usuário do token
for aplicador/pesquisador, retornar somente os questionários atribuídos a ele
(tabela de atribuição usada pela "seleção de pesquisadores" do painel).
Administradores continuam vendo todos. Nenhuma mudança é necessária no app.

## 2. Áudio não reproduz no painel ("arquivo não foi baixado")

**Contexto:** o app agora envia os áudios via `POST /api/audios/upload`
(multipart, campo `audio`) durante a sincronização, e o nome do arquivo vai no
campo `audio_path` do JSON de `POST /api/forms/submit`.

**Correção necessária no servidor:**
- Garantir que `POST /api/audios/upload` existe, salva o arquivo **mantendo o
  nome original** (mesmo comportamento do upload de fotos) e retorna
  `{"success": true, "filename": "..."}`.
- O painel deve localizar o arquivo pelo `audio_path` do formulário e servir o
  arquivo para reprodução/download.
- Áudios de coletas antigas que ainda estavam no celular serão enviados na
  próxima sincronização do app — o vínculo continua sendo pelo nome do arquivo.

## 3. Falhas de sincronização — aceitar formulário sem `id`

**Contexto:** o app gerava um `id` local com `millisecondsSinceEpoch` (~10^12) e
o enviava no `POST /api/forms/submit`; se a coluna for INTEGER (máx ~2,1×10^9),
a inserção estoura. O app foi corrigido para NÃO enviar `id` em formulários
novos — só envia em edição (id real do servidor).

**Correção/verificação no servidor:**
- `POST /api/forms/submit` sem `id` → INSERT normal.
- Com `id` existente → UPDATE (fluxo de edição).
- Recomendado: aceitar um campo opcional `client_id` (o id local do app) e criar
  um índice único para descartar reenvios duplicados do mesmo formulário
  (idempotência), evitando duplicatas quando o app reenviar após falha parcial.

## 4. Exclusão de questionários pelo painel

Adicionar ação de exclusão de questionário no painel administrativo
(preferencialmente soft delete / arquivamento, preservando respostas já
coletadas para auditoria). Hoje só é possível limpar registros exportando a
planilha, o que é inviável.

## 5. Exportação por pesquisador

**Problema:** ao exportar dados de UM pesquisador, saem todos os pesquisadores
que aplicaram o questionário no mesmo dia.

**Correção:** o filtro da exportação deve usar o campo `applied_by` (id do
pesquisador) do formulário, e não agrupar por data. Conferir a cláusula WHERE do
endpoint de exportação.

## 6. Estratificação por pesquisador

**Pedido do cliente:** metas/cotas individualizadas por pesquisador, para cada um
acompanhar o próprio desempenho.

**Backend:** `GET /api/stratification/<questionnaire_id>` deve passar a aceitar o
usuário do token (ou um parâmetro `?user_id=`) e retornar, além do progresso
geral, os contadores do próprio pesquisador (`current_count` filtrado por
`applied_by`). Sugerir estrutura: manter os campos atuais e acrescentar
`my_current_count`/`my_target_quota` em cada estrato, para o app exibir as duas
visões. Avisar quando estiver pronto para o app ser atualizado em conjunto.

## 7. Contagem de questionários no painel geral

Separar a contagem de entrevistas realizadas POR questionário (hoje aparece
agrupada). Ajuste de consulta/visualização no dashboard do painel.

## 8. Edição de questionário em andamento

**Problema:** após o início da coleta, editar/excluir uma alternativa no painel
gera erro e bloqueia a alteração.

**Correção:** permitir edição de textos e alternativas mesmo com respostas já
registradas. Cuidado com integridade: ao excluir uma alternativa que já possui
respostas, preferir desativação (a alternativa some para novas coletas mas as
respostas antigas permanecem válidas). Identificar e corrigir o erro atual
(provável violação de chave estrangeira nas respostas existentes).

## 9. Localização (lembrete — já solicitado antes)

Conferme `docs/prompt_backend_fix_localizacao.md`: receber, salvar e exibir
`latitude`/`longitude`/`location_name` de `POST /api/forms/submit`.
