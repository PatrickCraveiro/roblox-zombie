# Roblox Zombies

Sobrevivência em ondas, cooperativa e em primeira pessoa: zumbis vêm em rodadas cada vez mais difíceis,
você ganha pontos acertando e matando, e gasta os pontos comprando armas na parede.

## Como rodar

1. No VSCode: `Ctrl+Shift+P` → **Rojo: Open menu** → escolha `default.project.json`.
   Se pedir pra instalar o Rojo, aceite. No mesmo menu, instale o plugin do Studio.
2. No Roblox Studio: crie um place (Baseplate) → aba **Plugins** → **Rojo** → **Connect**.
3. Aperte **Play** (F5). Você nasce no lobby; pare na porta do supermercado pra começar uma partida.

Os scripts ficam no VSCode (sincronizados pelo Rojo). Lobby e fases são montados por código
quando o servidor inicia (`src/server/Maps`).

## Lobby

- Primeira pessoa com a arma na mão em todo lugar, como na partida. No lobby os tiros não dão ponto.
- **Fachada de cada fase** (hoje só o supermercado): parou na porta (tapete ou entrada), começa uma
  contagem de 5s (aparece no meio da tela) e quem estiver na porta entra junto. Com partida rolando,
  parar na porta da fase atual coloca você nela. No fim, todos voltam pro lobby.
- **Treinamento** (prédio à esquerda, entra andando pela porta automática): todas as armas de graça
  (inclusive as da Caixa Surpresa), Máquina de Upgrade grátis e zumbis de treino com a vida dos zumbis
  das rodadas 1, 5, 10 e 20. Mostra o dano de cada tiro.
  Ao entrar numa partida, as armas do Treinamento são trocadas pela pistola inicial.
- Portas automáticas: partes com a tag `AutoDoor` e o atributo `OpenOffset` (ver `AutoDoorService`).
- Fases disponíveis: lista `MapService.Maps` em `src/server/MapService.luau`.

## Loja de melhorias (no Supermercado)

Quiosques espalhados pelo mapa (itens e preços em `src/shared/Shop.luau`, efeitos em `Config.luau`):

| Item | Onde | Preço | Efeito |
|---|---|---|---|
| Colete Blindado | Entrada | 2500 | Vida em dobro |
| Mão Rápida | Estacionamento | 3000 | Recarga 2x mais rápida e ~33% mais tiros por segundo |
| Segunda Chance | Câmara Fria | 4000 | Se cair, levanta de novo com vida cheia e empurra os zumbis (1 vez) |
| Munição | Doca | 2000 | Enche a munição da arma na mão (qualquer arma, até da caixa) |

As melhorias aparecem como selos coloridos no canto da tela e somem quando você cai.
Placar: Abates, Headshots (abate com tiro na cabeça, +50 pontos de bônus) e Pontos.

## Premium: Arsenal Lendário (Game Pass)

Passe pago com 3 armas exclusivas, mais fortes e com mais munição que as melhores da parede:

| Arma | Preço na parede | Efeito |
|---|---|---|
| Canhão de Confete | 2500 pts | escopeta de 10 projéteis; o zumbi morto explode em confete |
| Raio Congelante | 3000 pts | automática; cada tiro congela o zumbi (para de andar e de bater) |
| Corrente Elétrica | 3500 pts | o raio pula pra até 3 zumbis por perto |

- Ficam na **parede dourada** de cada fase: quem tem o passe compra com pontos; quem não tem vê a
  janela de compra do passe. Não saem na Caixa Surpresa.
- No **Treinamento** ficam de graça pra todo mundo experimentar, e no lobby tem a **vitrine** do passe.
- Configuração dos passes: `src/shared/Premium.luau`. Pra vender de verdade, crie o passe no
  Creator Hub (create.roblox.com → seu jogo → Monetização → Passes) e cole o ID lá.
  Com `StudioOwnsAll = true`, no Studio todo mundo testa como se tivesse o passe.

## Ranking (salvo na nuvem da Roblox)

O quadro "RANKING DOS SOBREVIVENTES" no lobby mostra os 5 melhores em abates, headshots e pontos
(pontos **ganhos**, gastar na loja não diminui), de dois jeitos:

- **Recorde em uma partida**: o máximo que alguém já fez numa partida só
- **Total geral**: a soma de todas as partidas

Salva quando a partida acaba (ou quando o jogador sai no meio dela) e o quadro atualiza a cada
minuto e meio. Usa o DataStore da Roblox (`src/server/RankingService.luau`).

**Pra funcionar no Studio**: publique o jogo (Arquivo → Publicar no Roblox) e ligue
**Game Settings → Security → Enable Studio Access to API Services**. Sem isso o quadro mostra
"Ranking indisponível". Pra zerar o ranking, troque `VERSION` no RankingService.

## Controles

| Tecla | Ação |
|---|---|
| Botão esquerdo | Atirar |
| Botão direito | Mirar |
| R | Recarregar |
| 1 / 2 / rodinha | Trocar de arma |
| Shift | Correr |
| E | Comprar arma na parede / abrir porta / Caixa Surpresa |
| Segurar E | Pregar tábuas na barricada (perto do buraco) |

## Editando uma fase no Studio (opcional)

As fases são geradas sozinhas. Se quiser decorar uma no Studio, gere uma cópia editável: na barra de
comando, **fora** do modo de teste, rode

```lua
require(game.ServerScriptService.Server.Maps.Supermarket)().Parent = workspace
```

e salve o place. Se existir um modelo com o nome da fase (ex: `Supermercado`) no Workspace,
o jogo usa ele em vez de gerar.

## Estrutura

```
src/
  shared/      -> ReplicatedStorage.Shared (Config, Weapons, WeaponModels, Sounds, Ambience)
  server/      -> ServerScriptService.Server (partidas, lobby, zumbis, armas, pontos, portas, caixa)
    Maps/      -> geradores do lobby e das fases
  client/      -> StarterPlayerScripts.Client (HUD, armas em 1ª pessoa, efeitos)
  character/   -> StarterCharacterScripts (regeneração de vida)
```

- Balanceamento geral (pontos, vida, rodadas, zumbis): `src/shared/Config.luau`
- Armas (dano, cadência, pente, preço, som do tiro): `src/shared/Weapons.luau`.
  A tabela `Upgrade` de cada arma define uma versão turbinada especial (ex: a Pistola Lendária)
- Outros sons (recarga, acerto, gore): `src/shared/Sounds.luau`
- Desmembramento (quanto dano arranca um membro, velocidade mancando/rastejando): `src/shared/Config.luau`
- Iluminação (lobby de tarde, fases à noite; mais claro/escuro): `src/shared/Ambience.luau`

## Montando um mapa no Studio

Use tags (Properties → Tags) nas partes:

- **`Barricade`** (num Model): entrada dos zumbis, um vão na parede tampado com até 6 tábuas
  (`Config.BarricadePlanks`). O zumbi nasce do lado de fora, arranca uma tábua por vez e entra quando
  acabam; qualquer jogador perto do buraco, do lado de dentro, **segura E** e vai pregando uma tábua
  atrás da outra (+10 pontos cada; distância em `Config.BarricadeRepairRange`). Os tiros atravessam
  a barricada (ela segura os zumbis, não as balas).
  O modelo tem `Opening` (parte invisível no vão, com a frente pra dentro), `Plank1..6` e um
  `ZombieSpawn` do lado de fora. Pronto em `MapKit.barricade`; no Supermercado, a lista `BARRICADES`
  já corta os vãos nas paredes.
- **`ZombieSpawn`**: lugar onde os zumbis nascem (normalmente dentro de uma barricada). Atributo
  opcional `Zone` (texto): o spawn só funciona depois que uma porta libera essa área. Sem `Zone`,
  funciona sempre.
- **`WallBuy`**: arma na parede. Precisa do atributo `WeaponId` (ex: `SMG`, `Revolver`, `Sniper`, `LMG`;
  veja `Weapons.luau`). Atributo opcional `Price` muda o preço. Na face **Front** aparece a arma em 3D,
  com nome e preço embaixo (placa pronta: `MapKit.wallBuy`, 7x4 studs).
  Não coloque na parede as armas que só existem na Caixa Surpresa (as que têm `BoxOnly`).
- **`Door`**: porta paga. Atributos `Price` (número), `Zones` (áreas que libera, separadas por vírgula)
  e `Label` (nome que aparece). Ao comprar, sobe e some; volta no começo de cada partida.
- **`BoxSpot`**: lugar possível da Caixa Surpresa. Coloque um por área do mapa; a cada partida um é
  sorteado e a caixa fica lá até o fim. Atributo `Area` (nome que aparece no aviso "Caixa Surpresa: ...").
  A frente da caixa fica pro -Z.
- **`UpgradeMachine`**: Máquina de Upgrade (turbina a arma da mão: vermelha, dano x2, munição x2 e cheia).
  Atributo opcional `Price` (padrão 5000 em `Config.UpgradePrice`; 0 = grátis). O visual pronto está em
  `MapKit.upgradeMachine`. No Supermercado ela fica no Estoque; no estande de tiro tem uma grátis.
- **`ShopItem`**: quiosque da loja de melhorias. Atributo `ItemId` (`Armor`, `FastHands`,
  `SecondChance`, `Ammo`; ver `Shop.luau`). Visual pronto em `MapKit.shopStand`.
- **`Flicker`**: em lâmpadas (parte com uma luz dentro), faz piscar de vez em quando.
- Um **SpawnLocation** pra onde os jogadores nascem.

Caixa Surpresa: sai qualquer arma com `BoxWeight` em `Weapons.luau` (todas menos a pistola inicial;
as premium também vão ficar de fora).
