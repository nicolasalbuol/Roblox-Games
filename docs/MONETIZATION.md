# Guia de monetização

Princípio: **nada à venda decide uma partida.** Tudo é cosmético ou acelera moedas, que por sua vez
só compram cosméticos. Sem loot boxes, sem timers falsos, sem ofertas automáticas, sem pop-ups no
tutorial. Preços sempre visíveis; compras com moedas pedem confirmação; compras com Robux usam o
diálogo oficial do Roblox.

## Catálogo (preços = HIPÓTESES a validar)

### Game Passes

| Chave (`Config.Monetization.GamePasses`) | Preço sugerido | Benefício |
|---|---|---|
| `VIP` | R$ 199 | nome dourado + tag [VIP], título VIP, tinta Royal Gold, +25% moedas |
| `DoubleCoins` | R$ 299 | 2× moedas por rodada (soma com VIP: 2,25×) |
| `PrismPack` | R$ 149 | rastro arco-íris Prism + título Prismatic |

### Developer Products (consumíveis)

| Chave (`Config.Monetization.Products`) | Preço sugerido | Moedas | Moedas / Robux |
|---|---|---|---|
| `CoinsSmall` | R$ 49 | 500 | 10,2 |
| `CoinsMedium` | R$ 99 | 1.200 | 12,1 |
| `CoinsLarge` | R$ 249 | 3.500 | 14,1 |
| `CoinsHuge` | R$ 499 | 8.000 | 16,0 |

A loja exibe o preço **ao vivo** do Roblox (`GetProductInfo`); o valor do Config é só fallback.

### Por que esses preços (hipótese)

* 1 rodada ≈ 40–70 moedas; cosmético médio ≈ 600–1.200 moedas ≈ 1 h. O pack de R$ 99 equivale a
  ~1 cosmético médio — âncora de "pequena ajuda", não de "pagar para ter".
* Passes na faixa R$ 149–299 são comuns em experiências de sessão curta; validar por teste.

## Configuração (exige ação humana — ver EXTERNAL_SETUP.md)

1. Creator Hub → sua experiência → Monetization → Passes: criar os 3 passes, copiar IDs.
2. Monetization → Developer Products: criar os 4 produtos, copiar IDs.
3. Preencher `id = ...` em `src/shared/Config.luau`, rebuild, publicar.
4. Testar em Studio (compras de teste não cobram) e num servidor privado.

## Entrega e segurança

* Passes: verificados no servidor na entrada; concessão imediata após compra.
* Produtos: `ReceiptLogic` idempotente por `PurchaseId`, ack só após `UpdateAsync` bem-sucedido.
  Testado: compra única, recibo duplicado, falha de save + retry, produto desconhecido, sem perfil.
* O cliente só pede "prompt kind/key"; o servidor valida a chave, recusa passes já possuídos e
  itens com ID 0.

## Métricas (como medir)

| Métrica | Fonte |
|---|---|
| Visualizações da loja | funil `Store` passo 1 `OpenStore` (AnalyticsService) |
| Interesse por item | passo 2 `ViewItem` |
| Intenção de compra | passo 3 `PromptPurchase` |
| Compras concluídas | passo 4 `PurchaseComplete` + Monetization dashboard |
| Conversão | pagantes únicos / DAU (Creator Analytics) |
| ARPDAU / ARPPU | receita Robux do dia ÷ DAU / ÷ pagantes |
| Preferência por categoria | `LogEconomyEvent` Sink com `itemSKU` = id do cosmético; `PassPurchased` custom |
| Fluxo de moedas | `LogEconomyEvent` Source/Sink (Gameplay, IAP, Shop, TimedReward) |

## Testes de otimização sugeridos

1. Preço do VIP: 149 vs 199 (Price Optimization do Creator Hub quando disponível).
2. Ordem das abas da loja (Inks primeiro vs Passes primeiro) → taxa ViewItem→Prompt.
3. Bônus percentual dos packs maiores (atual 16 moedas/R$ no topo).

Regras: nunca medir sucesso só por receita; acompanhar D1/D7 e duração de sessão na mesma janela.

## Assinaturas e Roblox Plus

* Não lançamos assinatura no v1 (benefício recorrente ainda não claro). Candidata futura: "Turf
  Club" mensal com 1 cosmético exclusivo/mês (ver ROADMAP).
* Jogadores Roblox Plus recebem desconto do próprio Roblox em compras in-experience — nada a fazer
  no código.
