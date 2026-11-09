# Guia de publicação e material de loja

> Publicar, criar produtos pagos e alterar configurações financeiras exige a conta do dono.
> Nada disso foi feito automaticamente.

## Passo a passo

1. `./scripts/build.sh` → abre `release/ChromaTurf.rbxlx` no Roblox Studio.
2. Play Solo (F5) e "Start Server + 2 Players" (aba Test) para checar a lista de QA abaixo.
3. File → Publish to Roblox As… → nova experiência "Chroma Turf".
4. Game Settings → Security: **Enable Studio Access to API Services** (DataStores em Studio).
5. Creator Hub → configurar passes/produtos (MONETIZATION.md), colar IDs no `Config.luau`, rebuild,
   publicar de novo.
6. Creator Hub → Questionnaire de maturidade (sugestão: Mild — violência cartunesca sem sangue).
7. Ícone e thumbnails: `assets/marketing/` (substituir depois por capturas reais do Studio).
8. Habilitar Private Servers (sugestão: grátis ou R$ 50 — hipótese) e devices: Phone, Tablet,
   Computer, Console.
9. Publicar como **Public** só após o QA.

## QA manual antes de abrir ao público

- [ ] Rodada completa com 1 jogador + bots; resultados, moedas e XP aparecem.
- [ ] Laço fecha e conquista o interior; cortar rastro de bot o elimina.
- [ ] Reset do personagem durante a rodada → renasce na arena.
- [ ] Sair e voltar: moedas/cosméticos persistem (com API Services ligada).
- [ ] Loja: comprar cosmético com moedas (confirmação), equipar, ver no personagem.
- [ ] Compra de teste de produto e passe em Studio; moedas creditadas uma vez.
- [ ] Mobile (Device Emulator): botões alcançáveis, sem sobrepor joystick/pulo; texto legível.
- [ ] Gamepad: Y loja, X quests, B fecha.
- [ ] MicroProfiler: `ChromaTurf.MatchTick` com 12 jogadores (ver PERFORMANCE.md).

## Texto da página (EN)

**Nome:** Chroma Turf
**Descrição curta:** Draw a loop. Claim the land. Cut their trail!

**Descrição completa:**
Paint the arena in your color! Step out of your zone to draw a glowing trail, then loop back home
to claim everything inside. But careful — if anyone touches your trail, SPLAT, your turf is gone.

- Fast 3-minute rounds — jump straight into the action
- Cut rivals' trails to wipe out their whole territory
- Power-ups: Dash, Shield and Ink Bomb
- 3 arenas: Neon Plaza, Sunset Docks, Frost Grid
- Daily quests, daily gifts, 7 achievements, 100 levels
- 34 inks, trails and titles to show off
- Fair play: nothing you buy helps you win a round

Invite your friends and see who owns the map!

## Texto da página (PT-BR)

**Descrição curta:** Desenhe um laço. Conquiste a terra. Corte o rastro deles!
**Descrição:** Pinte a arena com a sua cor! Saia da sua zona para desenhar um rastro brilhante e
volte para conquistar tudo o que ficou dentro. Mas cuidado: se alguém tocar no seu rastro, SPLAT,
seu território some. Rodadas de 3 minutos, power-ups, 3 arenas, missões diárias e 34 cosméticos.
Nada que você compra ajuda a vencer.

**Palavras-chave/tags:** territory, paint, io, arena, loop, color, strategy, party, friends, casual,
multiplayer, competitive.

## Conceitos de ícone e thumbnails

* Ícone (`icon_512.png`): blob menta sobre o tabuleiro colorido, laço de rastro aberto, "TURF".
* Thumbnail 1 (`thumbnail_1_draw_a_loop.png`): "DRAW A LOOP. CLAIM THE LAND." com laço branco.
* Thumbnail 2 (`thumbnail_2_cut_their_trail.png`): "CUT THEIR TRAIL" + "SNAP!".
* A arte foi renderizada a partir do grid de uma rodada simulada real (`scripts/render_marketing.py`).
* Próximo passo: 3–5 capturas reais do Studio (vista top-down, mapa Sunset Docks ao pôr do sol).

## Texto de atualização (v1.0)

"Chroma Turf is live! 3 arenas, power-ups, daily quests and 34 cosmetics. Loop big, cut fast,
own the map!"

## Divulgação orgânica — ideias de vídeos curtos (9:16, 8–20 s)

1. Timelapse top-down de uma rodada inteira: mapa vazio → colorido (4× speed).
2. "O maior laço possível": jogador contorna metade do mapa, corte no último segundo.
3. Corte de vingança: amigo corta você, você renasce e corta ele 10 s depois.
4. Ink Bomb salvando um laço impossível.
5. "Rank 6 para 1 em 20 segundos" com o placar ao vivo na tela.
6. Duo de amigos cercando o rastro de um terceiro (cercar = eliminar).
7. Comparativo dos 3 mapas em 3 cortes rápidos.

Canais: TikTok/Shorts/Reels com o nome do jogo no texto; clipes enviados por jogadores podem ser
destacados nas atualizações (com permissão deles).
