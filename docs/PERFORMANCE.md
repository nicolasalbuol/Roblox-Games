# Performance — metas e medições

## Metas (a validar no Studio / dispositivos reais)

| Alvo | Meta |
|---|---|
| Tick do servidor (`ChromaTurf.MatchTick`), 12 jogadores | < 2 ms |
| Cliente PC intermediário | 60 FPS |
| Celular intermediário | ≥ 30 FPS estáveis, memória < 600 MB |
| Rede por cliente (in-round) | < 5 KB/s |
| Instâncias locais do cliente | ~1.600 tiles + ~250 do mundo + UI |

## Medido (fora do Roblox — Lune, CPU do ambiente de build)

Simulação headless de rodada de 180 s com 6 bots (`tests/match.spec.luau`):

* 0,087 ms/tick médio de lógica de partida (não inclui física/replicação do Roblox).
* Deltas de grid: ~75 B/s; posições de bots: ~610 B/s.
* 1.133 tiles ocupados no fim; 8 eliminações; invariantes do grid conferidas a cada 10 s simulados.

Esses números **não** são FPS nem tempo de servidor Roblox. Servem como ordem de grandeza.

## Não medido (pendente)

* FPS e memória em dispositivos (exige Studio/dispositivo).
* MicroProfiler com 12 jogadores reais.
* Tempo de construção dos 1.600 tiles no cliente.

## Otimizações implementadas

* Tiles só no cliente, sem colisão/query/touch/sombra; recolor só das células alteradas.
* Animação de "pop" em lote (`BulkMoveTo`), máx. 260 tiles, desativável.
* Bots sem Humanoid/física, renderizados localmente com interpolação.
* Pool de 6 emissores de partículas reutilizados; efeitos reduzidos desligam Bloom e FX cosméticos.
* Snapshot binário (3,2 KB) só no início/entrada; deltas de 4 B por célula.
* Autosave escalonado (0,5 s entre jogadores).
