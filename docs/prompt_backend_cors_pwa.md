# PROMPT PARA O AGENTE DO BACKEND — Habilitar CORS para o AppColeta Web (PWA)

Você é o desenvolvedor da API/painel do AppColeta. Está sendo criada uma versão
web (PWA) do aplicativo de coleta, compilada do mesmo projeto Flutter. Para o
navegador poder chamar a API, configure o CORS conforme abaixo.

## O que fazer

1. **Toda rota da API** (`/api/...`) deve responder com os cabeçalhos:
   - `Access-Control-Allow-Origin: <origin do PWA>` — ver lista abaixo
   - `Access-Control-Allow-Headers: Authorization, Content-Type`
   - `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`

2. **Preflight**: requisições `OPTIONS` em qualquer rota da API devem responder
   200/204 com os mesmos cabeçalhos, SEM exigir autenticação.

3. **Origins a liberar**:
   - `http://localhost:5000` (desenvolvimento — `flutter run -d chrome --web-port 5000`)
   - PRODUÇÃO NÃO PRECISA DE CORS: o PWA ficará em
     `https://institutoalveslima.com.br/app` — mesma origem da API
     (`https://institutoalveslima.com.br/painel/api`).
   - NÃO usar `*`, pois a API usa Authorization.

3b. **Hospedagem do PWA** (mesmo servidor):
   - Servir os arquivos estáticos da build web na pasta `/app`.
   - OBRIGATÓRIO servir por HTTPS (redirecionar http→https): o navegador só
     libera GPS, câmera, microfone e o modo offline em páginas seguras.

4. Se o upload de fotos/áudios (`/api/photos/upload`, `/api/audios/upload`)
   passar por outro serviço/proxy (Nginx, etc.), garantir os mesmos cabeçalhos
   lá também — multipart POST também sofre preflight.

## Alternativa que dispensa CORS em produção

Se for aceitável hospedar o PWA no MESMO domínio da API (ex.:
`painel.<dominio>/app` servindo os arquivos estáticos da build web), o CORS só
precisa ser liberado para `localhost` (desenvolvimento). Avaliar com o
responsável pela hospedagem.

## Como validar

```bash
curl -i -X OPTIONS https://<api>/api/questionnaires \
  -H "Origin: http://localhost:5000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization"
```

Deve retornar 200/204 com `Access-Control-Allow-Origin: http://localhost:5000`
no cabeçalho da resposta.
