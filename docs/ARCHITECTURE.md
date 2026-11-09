# Arquitetura técnica

Projeto Rojo (`default.project.json`), Luau, sem dependências externas.

```
src/shared  -> ReplicatedStorage.Shared      (puro, usado por servidor e cliente)
  Config        todos os números de jogo, economia, IDs de loja, áudio, limites
  Grid          regras de território: walk 4-conexo, capture (flood-fill), claim, clear, spawn
  GridCodec     buffers binários: snapshot 2 B/célula, delta 4 B/célula alterada
  Cosmetics     catálogo + regras de desbloqueio
  Progression   XP/níveis, recompensas, conquistas, quests diárias, presente diário
  Maps          temas e obstáculos
  Net           RemoteEvents/Function (servidor cria, cliente espera)
  Signal        sinal síncrono mínimo
src/server  -> ServerScriptService.Server
  Main.server   bootstrap: require -> Init(registry) -> Start
  Core/         lógica pura testável: DataSchema, ProfileStore, ReceiptLogic, RateLimiter, MemoryStore
  Services/     TelemetryService, DataService, MonetizationService, EconomyService, QuestService,
                WorldBuilder, AvatarService, PowerupService, BotService, MatchService,
                LeaderboardService, RequestRouter
src/client  -> StarterPlayerScripts.Client
  Main.client   bootstrap
  Controllers/  State (espelho + sinais), GridRenderer, BotRenderer, CameraController,
                SoundController, EffectsController
  UI/           Kit (tema, builder, modais, escala), HUD, Shop, Quests, Results, Settings, Onboarding
```

## Autoridade do servidor

* O servidor amostra a posição de cada participante a 10 Hz, anda o caminho 4-conexo entre
  amostras e aplica as regras no `Grid`. O cliente **nunca** envia posição, tiles, moedas ou preços.
* Antiexploit de movimento: deslocamento acima de `velocidade × 1,6 + 10 studs/s` não pinta o
  trecho (teleporte/speed hack não desenha linhas); altura > 14 studs acima do piso não pinta.
* Ações do cliente passam por `RequestRouter` (uma RemoteFunction): validação de tipos/tamanho,
  token bucket por jogador (10 burst, 4/s), handler em `pcall`. Eventos de telemetria têm outro
  limitador.

## Rede

| Canal | Conteúdo | Medido na simulação (6 bots, Lune) |
|---|---|---|
| GridDelta (reliable) | 4 B por célula alterada, por tick | ~75 B/s médio |
| BotPos (unreliable) | 1 + 10 B por bot, por tick | ~610 B/s |
| GridSnapshot | 3.200 B no início da rodada / ao entrar | — |
| Roster / Match / Profile | tabelas pequenas por evento | — |

Os tiles (1.600 parts) e os bots existem **só no cliente**; o servidor tem só piso, paredes e
obstáculos para física.

## Persistência

* `ProfileStore` sobre `DataStore:UpdateAsync` com **trava de sessão** (`jobId`, `time`).
  Perfil travado por outro servidor e não expirado (< 600 s) → tentativas com backoff; falha final →
  jogador é desconectado com mensagem (nunca joga com save em branco que sobrescreveria o real).
* Autosave a cada 90 s, save ao sair, `BindToClose` com espera de até 25 s.
* Servidor que perde a trava para de gravar e desconecta o jogador (evita duplicação).
* `DataSchema`: versão, migrações encadeadas (`Migrations[n]` → n+1), reconciliação de chaves,
  saneamento de NaN/limites, recusa de dados de versão **mais nova** (rollback seguro).
* Studio sem API de DataStore: perfil temporário em memória com aviso.

## Compras

* `ProcessReceipt` → `ReceiptLogic.process`: concede uma única vez por `PurchaseId`, só responde
  `PurchaseGranted` **depois** de salvar; senão `NotProcessedYet` (Roblox tenta de novo).
  Histórico limitado aos 60 recibos mais recentes.
* Passes: `UserOwnsGamePassAsync` na entrada, `PromptGamePassPurchaseFinished` concede na hora.
* IDs `0` = não configurado: a loja mostra "Coming soon" e nunca abre prompt.

## Performance (decisões)

* StreamingEnabled desligado: arena pequena e tiles locais (decisão em DECISIONS.md).
* Tiles sem colisão/query/touch/sombra; animação "pop" via `workspace:BulkMoveTo`, limitada a 260
  tiles e desligada em "Efeitos reduzidos".
* Bots sem física/Humanoid; um pool de 6 emissores de partículas reutilizados.
* Tick do servidor marcado no MicroProfiler como `ChromaTurf.MatchTick`.
