import 'dart:io';

/// Corrige o service worker gerado pelo Flutter para funcionar quando o app
/// é publicado em um SUBDIRETÓRIO (ex.: /painel/app/) em vez da raiz.
///
/// PROBLEMA
/// O handler de fetch do Flutter deriva a chave do cache assim:
///
///     var key = event.request.url.substring(origin.length + 1);
///     if (... || key == '') { key = '/'; }
///
/// Na raiz, abrir o app pede "https://dominio.com/" → key == "" → vira "/",
/// que está em RESOURCES, e o worker responde do cache quando offline.
///
/// Em /painel/app/, a mesma navegação gera key == "painel/app/", que NÃO
/// está em RESOURCES. O worker faz `return`, o navegador assume e, sem
/// internet, mostra a tela "Você está off-line" — o app nem carrega.
///
/// CORREÇÃO
/// Acrescenta um handler ANTES do handler do Flutter que trata qualquer
/// requisição de navegação (`request.mode === 'navigate'`) como o
/// index.html: tenta a rede e cai para o cache quando ela falha. É o mesmo
/// contrato do onlineFirst do Flutter, só que sem depender de o app estar
/// na raiz.
///
/// Uso: dart run tool/patch_service_worker.dart [caminho]
/// (padrão: build/web/flutter_service_worker.js)
void main(List<String> args) {
  final caminho =
      args.isNotEmpty ? args.first : 'build/web/flutter_service_worker.js';
  final arquivo = File(caminho);

  if (!arquivo.existsSync()) {
    stderr.writeln('❌ Não encontrado: $caminho');
    stderr.writeln('   Rode o "flutter build web" antes.');
    exit(1);
  }

  final original = arquivo.readAsStringSync();

  if (original.contains(_marcador)) {
    print('ℹ️ Service worker já corrigido — nada a fazer.');
    return;
  }

  // O handler precisa vir ANTES do handler do Flutter: o primeiro que
  // chamar respondWith vence.
  const ancora = "self.addEventListener(\"fetch\", (event) => {";
  if (!original.contains(ancora)) {
    stderr.writeln('❌ Handler de fetch não encontrado — o formato do '
        'service worker mudou. Revise este script.');
    exit(1);
  }

  final corrigido = original.replaceFirst(ancora, '$_patch\n\n$ancora');
  arquivo.writeAsStringSync(corrigido);

  print('✅ Service worker corrigido para funcionar em subdiretório.');
  print('   O app agora abre offline em /painel/app/.');
}

const _marcador = 'APPCOLETA_OFFLINE_SUBDIR_FIX';

const _patch = '''
// $_marcador
// -----------------------------------------------------------------------
// Fazer o app funcionar offline quando publicado em um SUBDIRETÓRIO.
//
// O handler do Flutter calcula a chave do cache a partir do ORIGIN:
//
//     key = url.substring(origin.length + 1)
//
// Em /painel/app/ isso produz "painel/app/main.dart.js", enquanto
// RESOURCES guarda "main.dart.js" (caminhos relativos ao escopo). Nada
// bate, o worker devolve tudo ao navegador e, sem internet:
//   - a navegação dava a tela "Você está off-line" do navegador;
//   - com a navegação corrigida, os assets continuavam falhando e a
//     página ficava EM BRANCO.
//
// Este handler recalcula a chave relativa ao ESCOPO do worker e serve
// tudo do cache. Vem antes do handler do Flutter: o primeiro a chamar
// respondWith vence.
// -----------------------------------------------------------------------
(function () {
  // Escopo do worker: ".../painel/app/". A chave de cada recurso é a URL
  // menos esse prefixo.
  const SCOPE = new URL(self.registration ? self.registration.scope : './', self.location).pathname;

  function chaveDoEscopo(url) {
    const u = new URL(url);
    if (u.origin !== self.location.origin) return null;
    if (!u.pathname.startsWith(SCOPE)) return null;
    return u.pathname.substring(SCOPE.length);
  }

  self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET') return;

    // --- Navegação: sempre o index.html ---------------------------------
    if (event.request.mode === 'navigate') {
      event.respondWith(
        fetch(event.request)
          .then((response) => {
            if (response && response.ok) {
              const copia = response.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put('index.html', copia);
              });
            }
            return response;
          })
          .catch(() => {
            return caches.open(CACHE_NAME).then((cache) => {
              return cache.match('index.html').then((cached) => {
                if (cached) return cached;
                return cache.match('/').then((raiz) => {
                  if (raiz) return raiz;
                  return new Response(
                    '<h1>App indisponível offline</h1>' +
                    '<p>Abra o aplicativo uma vez com internet para que ele ' +
                    'fique disponível sem conexão.</p>',
                    { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
                  );
                });
              });
            });
          })
      );
      return;
    }

    // --- Demais recursos: cache primeiro, chave relativa ao escopo ------
    let key = chaveDoEscopo(event.request.url);
    if (key === null) return;                 // outro domínio: não é nosso
    if (key.indexOf('?v=') !== -1) key = key.split('?v=')[0];
    if (key === '') key = '/';
    if (!RESOURCES[key]) return;              // não é recurso do app

    // O Flutter cacheia com contentCache.addAll(caminhos relativos), que o
    // navegador resolve contra o escopo — o cache guarda a URL completa.
    // Então casar pela própria Request funciona; o que faltava era não
    // desistir antes disso por causa da chave calculada pelo origin.
    event.respondWith(
      caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((cached) => {
          if (cached) return cached;
          return fetch(event.request).then((response) => {
            if (response && response.ok) {
              cache.put(event.request, response.clone());
            }
            return response;
          });
        });
      })
    );
  });
})();''';
