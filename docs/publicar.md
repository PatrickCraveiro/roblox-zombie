# Publicar e atualizar o jogo no Roblox

## 1. Primeira publicação

1. No VSCode, deixe o Rojo rodando (**Rojo: Open menu** → `default.project.json`) e no Studio abra o
   seu place e clique **Plugins → Rojo → Connect**. Confira no Explorer se aparecem
   `ServerScriptService > Server`, `ReplicatedStorage > Shared` e `StarterPlayerScripts > Client`.
   O que for publicado é o que está no Studio nessa hora.
2. **Arquivo → Publicar no Roblox como...** → **Criar novo jogo**: nome, descrição e gênero
   (Survival/Shooter). Se você já tinha publicado esse place antes (pra testar o ranking), use só
   **Arquivo → Publicar no Roblox** (Alt+P), que atualiza o mesmo jogo.
3. **Início → Configurações do jogo** (Game Settings):
   - **Informações básicas → Dispositivos**: deixe só **Computador** por enquanto (ainda não tem
     controle de toque pra celular/tablet nem de controle de videogame).
   - **Permissões**: deixe **Privado** até testar; depois mude pra **Público**.
   - **Segurança**: ligue **Permitir acesso do Studio aos serviços de API** (pra testar o salvamento
     e o ranking no Studio).
   - **Lugares** → o lugar → **Máximo de jogadores: 8**. Cada servidor roda uma partida por vez,
     então servidor muito cheio deixa gente esperando no lobby.
   - **Monetização → Servidores privados**: deixe desligado.
4. No **Creator Hub** (create.roblox.com → Criações → o jogo):
   - **Público → Maturidade e conformidade**: responda o questionário (é obrigatório pra liberar o
     jogo pra todo mundo). Responda com sinceridade: tem tiro em zumbi, sangue e membros arrancados.
   - Envie o **ícone** (512x512) e as **miniaturas** (1920x1080). Dá pra tirar print no Studio: o
     estádio, o supermercado com zumbis e a Galeria das Auras ficam bonitos.
5. Teste o jogo publicado pelo site (ainda privado), de preferência com alguém junto: jogue, ganhe
   moedas, saia e entre de novo (as moedas têm que continuar lá) e veja o quadro do ranking.

## 2. Passes (Robux)

1. Creator Hub → o jogo → **Monetização → Passes → Criar um passe**: imagem (512x512), nome e
   descrição.
2. Abra o passe → **Vendas** → ligue **Item à venda** → coloque o preço → Salvar.
3. Copie o **ID** do passe (o número no endereço da página) e cole no `Id` dele em
   `src/shared/Premium.luau`:

   | Passe | Chave no Premium.luau | Robux |
   |---|---|---|
   | Arsenal Lendário (pacote) | `Arsenal` | 999 |
   | Canhão de Confete | `Confetti` | 199 |
   | Raio Congelante | `Freeze` | 249 |
   | Corrente Elétrica | `Chain` | 299 |
   | Metralhadora Dragão | `Dragon` | 399 |
   | Canhão Furacão | `Hurricane` | 499 |
   | Moedas em Dobro | `DoubleCoins` | 149 |

4. Publique de novo (seção 3). Enquanto o ID for 0, o jogo mostra "em breve na loja".
   A Roblox fica com 30% de cada venda.

## 3. Atualizar (toda vez que mudar alguma coisa)

1. Rojo conectado no Studio (os scripts do VSCode sincronizados).
2. **Arquivo → Publicar no Roblox** (Alt+P).
3. Os servidores que já estão abertos continuam na versão antiga. Pra todo mundo pegar a nova: Creator
   Hub → o jogo → menu **⋯** → **Reiniciar servidores** (os jogadores voltam sozinhos).

## Dados salvos

- Jogo publicado: `PlayerData_v1` (moedas, armas, cargo) e `Ranking_*_v1`.
- **Studio**: usa cópias separadas (`PlayerData_v1_Studio`, `Ranking_*_v1_Studio`). Os testes, com
  todos os passes e as auras liberadas, não mexem no progresso de ninguém no jogo de verdade.
