# Plano de Implementação — AppColeta Web (PWA de coleta)

## Objetivo

Versão web instalável (PWA) do AppColeta para APLICADORES, com tudo que o app
nativo faz — questionários offline, foto, GPS, estratificação, bloqueio de
permissões, sincronização — e áudio gravado **enquanto a tela estiver ativa**
(wake lock + gravação em segmentos). Compilada do MESMO projeto Flutter.

**Alvos:** Android/Chrome e iPhone/Safari 16.4+.

**Hospedagem (definida):** `https://institutoalveslima.com.br/app` — mesmo
domínio da API (`/painel/api`), portanto SEM necessidade de CORS em produção
(liberar apenas localhost para desenvolvimento). HTTPS é obrigatório (GPS,
câmera, microfone e offline só funcionam em página segura).
Build de produção: `flutter build web --base-href /app/` → copiar `build/web`
para a pasta `/app` do servidor.

**Pré-requisito de produto:** cliente ciente de que o áudio web cobre o período
de tela ativa (interrupções — ligação, troca de app — geram lacunas; o que já
foi gravado é preservado em segmentos).

---

## Fase 0 — Fundação (1 dia)

- [ ] Confirmar com o cliente o modelo de áudio por segmentos.
- [ ] Backend: liberar **CORS** para o origin do PWA (`Access-Control-Allow-Origin`,
      headers `Authorization`/`Content-Type`, métodos GET/POST). Sem isso nenhuma
      chamada de API funciona no navegador — item mais esquecido.
- [ ] Adicionar dependências: `idb_shim` (IndexedDB), `wakelock_plus`.
- [ ] Criar `lib/services/platform_caps.dart`: helper central com `kIsWeb` e
      capacidades (temAudioContinuo, temArquivos, temPermissionHandler) para as
      ramificações ficarem num lugar só.

## Fase 1 — Compilar e abrir na web (1–2 dias)

- [ ] `flutter build web` e corrigir erros de compilação. Pontos conhecidos com
      `dart:io` (6 arquivos): `api_service.dart`, `photo_capture_screen.dart`,
      `form_provider.dart`, `question_analysis_screen.dart`,
      `form_completed_screen.dart`, `photo_storage_service.dart`.
      Nesta fase, apenas condicionar imports/trechos (guards `kIsWeb`) para
      compilar — a refatoração de verdade vem na Fase 2.
- [ ] Guard nos usos de `permission_handler` e `path_provider` (não rodam na web).
- [ ] Desligar gravação de áudio nativa no `question_screen.dart` sob `kIsWeb`
      (a versão web dela chega na Fase 4).
- [ ] Smoke test: login → dashboard → listar questionários → abrir prévia
      (valida API + CORS + parsing).

**Marco M1: app abre e navega no navegador.**

## Fase 2 — Armazenamento offline de mídia (3–4 dias)

A maior tarefa. Hoje fotos/áudios são ARQUIVOS (`path_provider` +
`dart:io File`); na web serão blobs no IndexedDB.

- [ ] Criar interface `MediaStore`:
      `save(bytes, {tipo, formId}) → id`, `listPending(tipo)`,
      `readBytes(id)`, `markSynced(id)`, `delete(id)`.
- [ ] Implementação IO: encapsula o comportamento atual (arquivos em
      `offline_photos/` / `offline_audios/` + metadados) — o nativo continua
      idêntico.
- [ ] Implementação Web: IndexedDB via `idb_shim` (blob + metadados + status).
- [ ] Refatorar `photo_storage_service.dart` e os `savePhotoOffline`/
      `saveAudioOffline`/`syncPendingAudios` do `form_provider.dart` para a
      interface.
- [ ] `api_service.dart`: uploads com `MultipartFile.fromBytes` (unifica IO e
      web; backend não muda).
- [ ] `photo_capture_screen.dart`: trabalhar com `XFile`/bytes em vez de
      `File`; exibir com `Image.memory`.
- [ ] Solicitar armazenamento persistente ao navegador
      (`navigator.storage.persist()`) no primeiro uso — mitiga limpeza do Safari.

**Marco M2 (com Fase 3): coleta completa com foto offline na web.**

## Fase 3 — Permissões e localização (1–2 dias)

- [ ] `_ensurePermissionsBeforeStart` (questionnaire_preview_screen) com ramo
      web: microfone via `record.hasPermission()` (dispara o prompt do
      navegador), GPS via `Geolocator.checkPermission/requestPermission`
      (suportado na web), câmera deixada para o prompt no momento do uso.
- [ ] Diálogo de impedimento adaptado: na web não existe "Abrir Configurações" —
      orientar pelo cadeado/ajustes do site no navegador.
- [ ] Testar captura de GPS na finalização (já usa geolocator, deve funcionar
      sem mudança; exige HTTPS).

## Fase 4 — Áudio "tela ativa" (2–3 dias)

- [ ] `wakelock_plus`: ativar ao entrar no `question_screen`, desativar ao sair
      (tela não apaga durante a aplicação — nos dois lados, nativo incluso, é
      melhoria bem-vinda).
- [ ] Gravação em segmentos na web: chunks do MediaRecorder a cada ~5s, salvos
      no `MediaStore` — interrupção nunca perde o que já foi falado.
- [ ] `visibilitychange`: página oculta → fecha o segmento; visível de novo →
      abre segmento novo automaticamente.
- [ ] Upload por segmento: `audio_<form>_<seq>.<webm|m4a>`, reaproveitando a
      Fase 3 de sincronização já existente.
- [ ] Backend/painel: aceitar `webm` (Chrome) e `mp4/m4a` (Safari) e listar
      múltiplos segmentos por formulário (item pequeno, paralelo).

**Marco M3: áudio funcionando na web.**

## Fase 5 — PWA e offline de verdade (1–2 dias)

- [ ] `web/manifest.json`: nome AppColeta, cores da marca, `display: standalone`,
      orientação portrait (ícones já são gerados pelo flutter_launcher_icons).
- [ ] Testar o ciclo offline completo: abrir sem rede (após 1º acesso) →
      preencher → foto → GPS → finalizar → voltar a rede → sincronizar.
- [ ] Instrução/banner de instalação ("Adicionar à tela inicial").

## Fase 6 — Testes e homologação (2–3 dias)

- [ ] Matriz: Android/Chrome e iPhone/Safari 16.4+ × online/offline ×
      permissões concedidas/negadas.
- [ ] Teste de resiliência: ligação no meio da entrevista, troca de app,
      recarregar a página com formulário pendente.
- [ ] **Regressão do app nativo** (a Fase 2 toca código compartilhado):
      `flutter test` + roteiro manual no Android (foto, áudio, sync).
- [ ] Homologação com 1–2 aplicadores reais antes de liberar geral.

**Marco M4: liberado para campo.**

---

## Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Safari apaga dados offline (~7 dias sem uso) | `storage.persist()` + orientar sincronização diária + alerta no app quando houver pendências antigas |
| iOS < 16.4 sem wake lock (tela pode apagar) | Detectar e avisar; orientar tempo de bloqueio maior; áudio segue em segmentos |
| CORS/certificado mal configurado | Fase 0 resolve antes de tudo; testar cedo com o backend real |
| Regressão no nativo pela refatoração | Interface `MediaStore` preserva o comportamento IO; testes de regressão na Fase 6 |
| Formatos de áudio diferentes por navegador | Backend aceita ambos; players web reproduzem os dois |

## Cronograma e entregas

~12–17 dias úteis (1 dev), com 4 marcos demonstráveis (M1 navegação, M2 coleta
com foto, M3 áudio, M4 homologado). O deploy é `flutter build web` + copiar a
pasta `build/web` para o servidor HTTPS — sem Mac, sem lojas, atualização
instantânea para todos.

## Itens de backend (paralelos, pequenos)

1. CORS para o origin do PWA (Fase 0 — bloqueia tudo).
2. Upload de áudio: aceitar `webm`/`m4a` e múltiplos segmentos por formulário;
   painel listar/reproduzir os segmentos (Fase 4).
3. (Opcional) flag por questionário "permite aplicação web", para o cliente
   controlar onde a coleta web é aceita.
