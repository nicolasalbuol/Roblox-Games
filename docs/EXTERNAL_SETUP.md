# Configurações externas necessárias (ação humana)

Itens que dependem da conta Roblox do dono. Nada aqui foi feito automaticamente; nenhuma senha ou
token deve ser compartilhado com ferramentas de IA.

| # | Ação | Onde | Bloqueia |
|---|---|---|---|
| 1 | Publicar a place (File → Publish to Roblox) | Studio | tudo abaixo |
| 2 | Ativar *Enable Studio Access to API Services* | Game Settings → Security | testes de save em Studio |
| 3 | Criar game passes `VIP`, `DoubleCoins`, `PrismPack` | Creator Hub → Monetization → Passes | venda de passes |
| 4 | Criar developer products `CoinsSmall/Medium/Large/Huge` | Creator Hub → Monetization → Developer Products | venda de moedas |
| 5 | Colar os IDs em `src/shared/Config.luau` (`Config.Monetization`) e republicar | repositório | itens aparecem como "Coming soon" até lá |
| 6 | (Opcional) Criar badges e colar IDs em `Config.Badges` | Creator Hub → Badges (pode ter custo) | badges oficiais |
| 7 | Enviar SFX/música originais e trocar `Config.Audio` | Creator Hub → Audio | áudio final |
| 8 | Enviar ícone e thumbnails (`assets/marketing/`) | Creator Hub → Places → Thumbnails | página da loja |
| 9 | Preencher questionário de maturidade | Creator Hub → Experience Questionnaire | listagem pública |
| 10 | Max players = 12, Private servers on, devices on | Creator Hub → Places / Access | descoberta, servidores de amigos |
| 11 | Revisar textos da página (PUBLISHING.md) | Creator Hub → Basic Info | página da loja |
| 12 | Ativar Monetization → Price Optimization (se disponível) | Creator Hub | testes de preço |

Mapeamento de IDs (exemplo):

```lua
Config.Monetization.GamePasses.VIP.id = 123456789
Config.Monetization.Products.CoinsSmall.id = 987654321
```

Os campos `price` no Config são apenas fallback de exibição; o preço real é o configurado no
Creator Hub e é lido ao vivo pela loja.
