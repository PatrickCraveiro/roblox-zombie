# Estádio Gol de Placa

Estádio de futebol abandonado, à noite, com os refletores piscando. O código está em
`src/server/Maps/Stadium.luau`; a entrada da fase no lobby é a fachada ao lado do supermercado.

## Planta (vista de cima)

```
 x: -128   -88                                     88   128
    ┌────────────── ARQUIBANCADA NORTE ───────────────┐ z = -104
    ├─porta─┬──── alambrado (portão pro gramado) ┬─porta─┤ z = -60
    │VESTIÁ-│ túnel                        túnel │VESTIÁ-│
    │RIO DA │      GRAMADO (176 x 120)           │RIO VI-│
    │ CASA  │                                    │SITANTE│
    ├─porta─┴─atalho──────┬CAMAROTES┬────────────┴─porta─┤ z = 60
    │        ENTRADA (catracas e lanchonete)             │
    └────────────────────────────────────────────────────┘ z = 104
```

Caminho: **Entrada → Vestiário (750) → Arquibancada (1000) → Gramado (1250) → Camarotes (1500)**.
Das catracas não dá pra ir direto pro gramado; o **atalho pras catracas (500)** só abre pelo lado
do gramado (é uma porta com o atributo `OpenFrom`).

| Área | O que tem |
|---|---|
| Entrada | saguão com parede de vidro pro gramado (vê o campo, não passa), 12 catracas detalhadas com pórtico e luzes, bilheteria, loja do torcedor, taça na vitrine, escudo no chão, bandeirinhas, mirante com bancos, lanchonete, Pistola e SMG, Colete Blindado |
| Vestiário da casa (verde) | armários numerados, camisas, banco, banheiro fechado (chuveiros com boxes e sanitários com cabines, pias e espelho), lousa tática, maca, saco de bolas, bebedouro, Escopeta |
| Vestiário visitante (azul) | igual ao da casa, Revólver, Munição |
| Arquibancada norte | corredor plano, degraus com cadeiras coloridas, cabine de imprensa, faixas da torcida, Fuzil e Rifle de Precisão no alambrado, Mão Rápida |
| Gramado | listras, linhas do campo, gols com rede, bandeirinhas, bancos de reservas, placar eletrônico, 4 refletores, túneis nos cantos (zumbis), Escopeta Automática |
| Camarotes | vidro de frente pro campo, sofás, TV "AO VIVO", frigobar, Metralhadora, Segunda Chance, **Máquina de Upgrade** |

Caixa Surpresa: um lugar em cada uma das 6 áreas.
Zumbis: portões da fachada, buracos e janelas dos vestiários, saídas da arquibancada e os dois
túneis do gramado.
