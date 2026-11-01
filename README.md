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

## Moedas e Arsenal (progresso salvo)

Jogando você ganha **moedas** (salvas na nuvem): 1 por abate, 1 por headshot e 10 por rodada que a
partida alcançou (`Config.CoinsPer...`). Bônus, que se multiplicam:

- **1ª partida do dia** (vira à meia-noite de Brasília): moedas x2
- **Em grupo** (2 ou mais jogadores na partida): +20%
- **Passe VIP Moedas em Dobro**: x2 sempre

No fim da partida aparece quanto ganhou e quanto falta pra próxima arma; no lobby isso fica embaixo
das moedas. A banca **Arsenal** (atrás do spawn) abre uma janela com todas as armas: dá pra
**liberar pra sempre** com moedas e escolher com qual **começar a partida** (no lugar da pistola).
Preço de cada arma: `CoinPrice` em `Weapons.luau`. A ideia é demorar: um jogador médio (~290 moedas
por partida até a rodada 10, ~1.450 por hora) libera a primeira arma na primeira partida, mas leva
umas 34 horas pra juntar o Micro-ondas e umas 90 pra liberar tudo.

| Arma | Moedas | Arma | Moedas |
|---|---|---|---|
| Pistola | grátis | Metralhadora | 6.000 |
| Submetralhadora | 100 | Cano Duplo | 9.000 |
| Revólver | 300 | Fuzil de Batalha | 13.000 |
| Escopeta | 700 | Besta | 18.000 |
| Fuzil | 1.500 | Metralhadora Giratória | 25.000 |
| Rifle de Precisão | 2.500 | Micro-ondas Portátil | 50.000 |
| Escopeta Automática | 4.000 | Armas VIP | só com o passe |

## Cargos de aura

Os **pontos** de todas as partidas somados (gastar na loja não diminui) dão um cargo. O cargo aparece
em cima do nome do jogador (no lugar do nome padrão) e ele ganha uma **aura** em volta do corpo. Quando
sobe de cargo, aparece um aviso pra ele e pra todo mundo do servidor. No lobby, a **Galeria das Auras**
(lado direito da praça) tem um manequim com cada aura e mostra quanto falta pra você chegar lá.

**Escolher a aura**: na Galeria, aperte **E** no pedestal de qualquer cargo que você já tem pra usar
aquela aura (o cargo e a aura escolhida aparecem em cima do seu nome). Quando sobe de cargo, troca
sozinho pra aura nova (dá pra voltar). No Studio dá pra usar todas, pra testar
(`Progression.StudioAllAuras`).

| Cargo | Pontos | Aura |
|---|---|---|
| Iniciante | 0 | folhinhas voando em volta |
| Café com Leite | 20.000 | poeirinha nos pés |
| Espanta-Zumbi | 75.000 | bolhas verdes subindo |
| Zé Bala | 200.000 | faíscas saindo do chão |
| Mira Laser | 500.000 | bolas de luz azul em órbita |
| Pesadelo dos Zumbis | 1.200.000 | fumaça roxa |
| Raio Ambulante | 2.500.000 | raios amarelos em volta |
| Lenda do Bairro | 5.000.000 | fogo azul e purpurina |
| Matador | 10.000.000 | aura vermelha fortíssima (chamas + contorno vermelho) |

Um jogador médio faz uns 17 mil pontos por partida (~85 mil por hora): Raio Ambulante em ~30 horas,
Matador em ~120. Nomes e pontos: `src/shared/Progression.luau`; efeitos: `src/client/AuraController.luau`.

Dados de cada jogador: `src/server/PlayerDataService.luau` (DataStore `PlayerData_v1`). No Studio
precisa do mesmo acesso às APIs do ranking; sem ele o jogo funciona, mas não salva.

## Armas VIP (Game Pass)

Cada arma VIP tem o seu passe, e o **Arsenal Lendário** é o pacote com todas (mais barato que
separado). São as armas mais fortes do jogo:

| Arma | Passe (Robux) | Preço na parede | Efeito |
|---|---|---|---|
| Canhão de Confete | 199 | 2500 pts | 12 projéteis de 300 que atravessam 4 zumbis; o zumbi morto explode em confete |
| Raio Congelante | 249 | 3000 pts | automática, 350 por tiro, pente de 150; cada tiro congela o zumbi por 3s |
| Corrente Elétrica | 299 | 3500 pts | 1500 de dano e o raio pula pra até 8 zumbis por perto |
| Metralhadora Dragão | 399 | 4000 pts | **2000 balas no pente**, 250 por tiro, tiros de fogo; o zumbi morto vira brasa |
| Canhão Furacão | 499 | 5000 pts | vendaval em leque que mata tudo na frente e arremessa os zumbis longe |
| **Arsenal Lendário** (pacote) | **999** | | as 5 armas |

Fora das armas tem o passe **Moedas em Dobro** (149 Robux): dobra as moedas de toda partida. É
vendido pelo botão dourado no topo da janela do Arsenal. No Studio (`StudioOwnsAll`) todo mundo tem
ele, então as moedas vêm em dobro nos testes.

- Ficam na **parede dourada** de cada fase: quem tem o passe compra com pontos; quem não tem vê a
  janela de compra do passe. Não saem na Caixa Surpresa.
- No **Treinamento** ficam de graça pra todo mundo experimentar, e no lobby tem a **vitrine** do
  pacote. Quem tem o passe também pode escolher a arma VIP como arma inicial no Arsenal.
- Configuração dos passes: `src/shared/Premium.luau`. Pra vender de verdade, crie cada passe no
  Creator Hub (create.roblox.com → seu jogo → Monetização → Passes) com o preço da tabela e cole
  o ID lá. Com `StudioOwnsAll = true`, no Studio todo mundo testa como se tivesse os passes.

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
No Studio o ranking e o progresso dos jogadores ficam em cópias separadas (sufixo `_Studio`), pra os
testes não aparecerem no jogo publicado.

Pra publicar e atualizar o jogo no Roblox: [docs/publicar.md](docs/publicar.md).

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

**Celular e tablet** (`src/client/MobileControls.luau`): o analógico da Roblox anda (lado esquerdo) e
arrastar o dedo na tela gira a câmera. No lado direito ficam os botões **TIRO** (segure; arrastando o
mesmo dedo também gira a câmera), **MIRA** e **CORRER** (um toque liga/desliga), **RECARGA**,
**TROCAR** (só com 2 armas) e **PREGAR** (aparece perto de barricada; segure). Os botões aparecem
quando a pessoa toca na tela e somem se ela usar teclado. Pontos, arma e munição sobem pro canto de
cima. Pra testar no Studio: aba **Testar → Dispositivo**, escolha um celular e aperte Play.

**Controle de videogame**: R2 atira, L2 mira, B recarrega, Y troca de arma, L3 corre, segurar X prega
tábuas (X também usa portas, paredes e a caixa).

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
  shared/      -> ReplicatedStorage.Shared (Config, Weapons, WeaponModels, Sounds, Ambience, Progression)
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
