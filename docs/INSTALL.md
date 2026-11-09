# Instalação, build e testes

## Opção A — só abrir o jogo

O arquivo pronto está versionado: abra
`release/ChromaTurf.rbxl` (ou `.rbxlx`) no Roblox Studio (File → Open from File). Para regenerar: `./scripts/build.sh`.

## Opção B — ambiente de desenvolvimento

Ferramentas (versões usadas no desenvolvimento):

| Ferramenta | Versão | Instalação |
|---|---|---|
| Rojo | 7.7.1 | `cargo install rojo --locked` ou Aftman/Rokit |
| Lune | 0.11.1 | `cargo install lune --locked` |
| Selene | 0.31.0 | `cargo install selene --locked` |
| StyLua | 2.6.0 | `cargo install stylua --locked` |
| Python 3 + Pillow | 3.x / 12 | só para `scripts/render_marketing.py` |

Comandos (na raiz):

```bash
./scripts/build.sh      # gera release/ChromaTurf.rbxlx
./scripts/ci.sh         # sintaxe + lint + formatação + testes + build + verificação do .rbxlx
lune run tests/run.luau           # todos os testes
lune run tests/run.luau match     # só os specs cujo nome contém "match"
```

### Desenvolvimento ao vivo com Studio

1. Instale o plugin Rojo no Studio.
2. `rojo serve` na raiz do projeto.
3. No Studio: plugin Rojo → Connect. Edições em `src/` sincronizam.

### Studio: DataStores

Game Settings → Security → *Enable Studio Access to API Services*. Sem isso, o jogo roda com um
perfil temporário em memória (aviso no Output) — nada é salvo.

## Estrutura

Ver `docs/ARCHITECTURE.md`. Testes ficam em `tests/` e carregam os ModuleScripts reais sob Lune
via `tests/loader.luau` (emula `script`, `require(instance)` e `game:GetService`).
