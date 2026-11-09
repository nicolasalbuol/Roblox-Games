# Telemetria e otimização

Tudo passa por `TelemetryService` (wrapper de `AnalyticsService` à prova de falha). Nenhum dado
pessoal é enviado (sem nomes, chat ou IDs em campos customizados; o Roblox associa o evento ao
jogador internamente).

## Eventos

| Evento | API | Quando |
|---|---|---|
| Onboarding 1 `Spawned` | LogOnboardingFunnelStepEvent | primeiro spawn na arena |
| Onboarding 2 `LeftZone` | idem | primeira célula de rastro |
| Onboarding 3 `FirstCapture` | idem | primeiro laço fechado (= tutorial concluído) |
| Onboarding 4 `FirstRoundComplete` | idem | primeira rodada terminada |
| `SessionStart` (valor = dias desde a 1ª entrada; campo new/returning) | LogCustomEvent | cada carregamento de perfil |
| `RoundEnd` (valor = colocação; campos mapa, %, cortes) | LogCustomEvent | fim de rodada |
| `Achievement`, `QuestClaim`, `DailyClaim`, `InvitePrompt`, `PassPurchased` | LogCustomEvent | ação |
| Funil `Store` 1–4 | LogFunnelStepEvent | abrir loja → ver item → prompt → compra |
| Coins Source/Sink | LogEconomyEvent | toda criação/gasto de moedas |

Em Studio, contadores locais são impressos no `BindToClose`.

## KPIs — como calcular

* **D1 / D7 / D30**: Creator Analytics → Retention (nativo). Validação cruzada: fração de jogadores
  com `SessionStart` valor = 1 / 7 / 30 dentro da coorte do dia 0.
* **Duração média de sessão**: Creator Analytics → Engagement (nativo).
* **Conclusão do tutorial**: Onboarding passo 3 ÷ passo 1.
* **Abandono por etapa**: queda entre passos consecutivos dos funis Onboarding e Store.
* **Conversão de compradores**: pagantes únicos ÷ jogadores ativos (período).
* **ARPU / ARPPU**: receita (Robux) ÷ ativos / ÷ pagantes.
* **Frequência de retorno**: média de `SessionStart` por jogador por semana.

## Hipóteses de otimização (com validação)

| # | Hipótese | Métrica | Como testar |
|---|---|---|---|
| H1 | Entrar direto numa rodada (sem fila) eleva o passo 3 do onboarding | Onb3/Onb1 | comparar versões por período / experimento |
| H2 | Zona inicial 5×5 é pequena demais para novatos | mortes antes do Onb3 | Config `SpawnRadius` 2 vs 3 |
| H3 | 6 participantes mínimos (bots) é o ponto ideal | duração de sessão em servidores com ≤ 2 humanos | `MinParticipants` 4 vs 6 vs 8 |
| H4 | Rodadas de 180 s vs 150 s | rodadas/sessão, D1 | `RoundSeconds` |
| H5 | Presente diário sem reset aumenta retorno sem pressão | D7 | comparar com histórico |
| H6 | Mostrar a loja só após 1ª rodada não reduz conversão | Store passo 1 por DAU | flag de UI |

Nenhuma projeção de receita é feita; todas as metas são hipóteses até haver dados.
