# Chroma Turf — Game Design Document (v1.0)

**Pitch:** *Draw a loop. Claim the land. Cut their trail.*
Arena multiplayer de território em rodadas de 3 minutos. Todo o jogo é legível de cima: o mapa
é um tabuleiro que muda de cor.

**Público:** 9+ (sem violência gráfica; "eliminação" é um splash de tinta). Sessões curtas,
mobile-first, também PC e gamepad.

## 1. Mecânica central

* Cada participante começa com uma zona 5×5 da sua **tinta**.
* Fora da própria zona, você deixa um **rastro** (tiles neon).
* Ao voltar para a sua zona, o rastro vira território **e tudo o que ele cercar** também
  (flood-fill a partir das bordas, conectividade 4).
* **Cortar:** pisar no rastro de outro jogador elimina-o; o território dele volta a ser neutro.
* **Auto-corte:** cruzar o próprio rastro (exceto as 2 últimas células, tolerância a jitter).
* **Cercar:** se o seu laço englobar o rastro de alguém, ele é eliminado.
* **Engolido:** um rival cujo território chegue a zero é eliminado.
* Renascimento após 3 s com nova zona 5×5. Ninguém perde progresso persistente.
* Vence quem tiver o maior % do mapa ao fim da rodada.

Profundidade: risco × recompensa (laços maiores = mais terra e mais tempo vulnerável), leitura de
rivais, caça a rastros, uso de obstáculos como "paredes", timing de power-ups.

## 2. Power-ups (aparecem em células neutras, ≤ 4 simultâneos)

| Power-up | Efeito |
|---|---|
| DASH | +50% velocidade por 3,5 s |
| SHIELD | seu rastro não pode ser cortado por 6 s |
| INK BOMB | conquista instantânea 5×5 ao seu redor (cria "ilha" segura) |

## 3. Mapas (rotação a cada rodada)

| Mapa | Identidade | Obstáculos |
|---|---|---|
| Neon Plaza | noite neon, torres | 4 pilares 2×2 |
| Sunset Docks | pôr do sol, píeres, água | bloco central 4×4 + 2 barras |
| Frost Grid | gelo, cristais | 6 aglomerados de cristal |

## 4. Fluxo de sessão

1. Splash "CHROMA TURF — PLAY" (menu principal) enquanto o save carrega.
2. Entra direto numa rodada em andamento (sem fila): ação em < 10 s.
3. Coach do tutorial: "saia da zona" → "volte para fechar" → celebração. Nenhuma oferta de compra
   aparece em qualquer momento automaticamente; a loja só abre por ação do jogador.
4. Fim de rodada: tela de resultados, pódio físico no hub (top 3 humanos sobem no pódio), 15 s de
   intermissão social no hub.

## 5. Progressão

* **Curto prazo:** % do mapa, "+N TILES", cortes, ranking ao vivo.
* **Médio prazo:** 3 quests diárias (tipos distintos), presente diário (ciclo de 7 dias que
  **nunca zera** por faltar), níveis (XP 100 + 40·(n−1)), moedas.
* **Longo prazo:** 7 conquistas com títulos exclusivos, cosméticos por nível (10, 20, 25, 30),
  placar global de vitórias, estatísticas vitalícias.

Recompensa por rodada (hipótese de balanceamento): `10 + 1,5·% + 5·cortes + {30,20,10}` pela
colocação (só com ≥ 3 participantes). XP: `50 + 2·% + 10·cortes`.

## 6. Economia

* Moeda única **Coins** (soft). Só compra cosméticos. Fontes: rodadas, quests, conquistas, nível,
  presente diário, packs de Robux. Sumidouros: loja de cosméticos.
* Preço médio de cosmético ≈ 1 h de jogo (hipótese). Nenhum item afeta o resultado da partida.

## 7. Social

* Sem colisão entre jogadores (nada de bloqueio corporal/grief).
* Convite de amigos (SocialService), placar no hub, pódio, feed de cortes com nomes.
* Bots rotulados "Bot" completam a rodada até 6 participantes quando há poucos humanos e saem
  conforme humanos entram.
* Servidores privados: habilitar no Creator Hub (ver EXTERNAL_SETUP.md).

## 8. Cosméticos (lançamento: 34 itens)

16 tintas, 8 efeitos de rastro, 10 títulos — por moedas, nível, conquista ou passe. Ver
`src/shared/Cosmetics.luau`.

## 9. Fora do escopo v1 (roadmap)

Modo Duplas, emotes animados, temporadas/passe de batalha cosmético, mapas sazonais, tabuleiros
maiores para servidores grandes. Ver ROADMAP.md.
