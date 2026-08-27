# Informações metodológicas do capítulo: "A política da burocracia local: dimensões analíticas, mapeamento e direções" (codificação e análise do banco final)

Autores: Mariana Batista (UFPE), Amanda Domingos (Universidade de Oxford) e Anderson Henrique (USP).

Pipeline para (1) rodar uma classificação automática (LLM, via pacote `acR`)
das 10 variáveis de conteúdo do `codebook_burocracia_local.docx` sobre o
corpus final, (2) comparar essa classificação com a codificação manual já
existente (concordância/IRR por variável), e (3) produzir a análise
descritiva/bibliométrica final do artigo a partir do banco manual.

## A triagem PRISMA foi feita manualmente

O corpus final do estudo (114 artigos, resultado das duas etapas de triagem
do fluxograma PRISMA: identificação n=495 → elegibilidade analítica → nível
de governo) **já está pronto e codificado manualmente** em
`data/banco_final_114_burocracia_local.xlsx`. Não há etapa de triagem via
LLM no pipeline; os scripts que a reconstruiriam foram removidos por não
serem mais necessários.

## Estrutura

```
projeto_R_burocracia_local/
├── .Renviron.example                          # modelo p/ chave de API (copie para .Renviron)
├── .gitignore                                  # ignora .Renviron e saidas geradas
├── data/
│   ├── raw_local_buro.csv                      # copia intacta do CSV original (495, com colunas tecnicas)
│   ├── local_buro.csv                          # 495 registros de identificacao (referencia/contexto)
│   ├── banco_final_114_burocracia_local.xlsx   # BANCO FINAL: 114 artigos, codificados manualmente
│   └── banco_114_llm_x_humano.xlsx             # [gerado por 02] banco final + colunas LLM (sufixo "_llm")
├── scripts/
│   ├── 00_setup_pacotes.R                      # instala/checa dependencias
│   ├── 00b_crosswalk_categorias.R              # dicionario slug (acR) <-> rotulo humano
│   ├── 01_construir_codebooks_conteudo.R       # define os 10 codebooks de conteudo
│   ├── 02_classificacao_llm_conteudo.R         # classifica o banco final nas 10 variaveis via LLM
│   ├── 03_validacao_humana.R                   # compara LLM x banco manual (IRR por variavel)
│   ├── 04_analise_descritiva.R                 # ANALISE FINAL -- le banco_final_114_burocracia_local.xlsx
│   └── 05_graficos_paper.R                     # graficos p/ o paper -- mesma leitura, sem os cruzamentos
├── codebooks/
│   ├── codebook_burocracia_local.docx          # codebook original (variaveis/categorias do artigo)
│   └── *.yaml                                  # codebooks acR salvos (ac_qual_save_codebook)
└── output/
    ├── relatorio_metodo_*.html                 # [gerado por 03]
    └── figuras/                                # [geradas por 05]
```

## Banco final já codificado

`data/banco_final_114_burocracia_local.xlsx` é o banco final do estudo: os
114 artigos do corpus final, **codificados manualmente** segundo o
`codebooks/codebook_burocracia_local.docx`. É esse arquivo que
`04_analise_descritiva.R` lê para produzir a análise final do artigo. A
classificação LLM (scripts 01-03) serve apenas para **validar** essa
codificação manual, não para substituí-la.

Os nomes de coluna do banco final não são idênticos aos slugs usados pelos
codebooks do `acR` (scripts 01/02), porque o banco final segue a
nomenclatura do `codebook_burocracia_local.docx`. O `03_validacao_humana.R`
faz essa "tradução" entre os dois vocabulários (crosswalk explícito em
`00b_crosswalk_categorias.R`) para comparar a codificação automática com a
manual, variável por variável.

## Configurar a chave de API com segurança

A chave nunca deve ser escrita em nenhum script. Ela mora no `.Renviron`,
lido automaticamente pelo R na inicialização da sessão e **fora do controle
de versão** (já listado no `.gitignore`).

```r
# 1. Copie o modelo
file.copy(".Renviron.example", ".Renviron")

# 2. Abra para editar (mais seguro que abrir no editor comum)
usethis::edit_r_environ(scope = "project")
# Cole: GEMINI_API_KEY=...   (sua chave real do Google AI Studio)

# 3. Reinicie a sessão do R (Session > Restart R no RStudio)

# 4. Confirme
Sys.getenv("GEMINI_API_KEY") != ""
```

## Ordem de execução

1. **`00_setup_pacotes.R`**: roda uma vez, instala `acR`, `ellmer` e demais
   pacotes (inclui `irr`, usado pelo cálculo de Alpha de Krippendorff em `03`).
2. **`01_construir_codebooks_conteudo.R`**: define os 10 codebooks das
   variáveis de conteúdo do `codebook_burocracia_local.docx`. Revise os
   `examples_pos`/`examples_neg` (ilustrativos) antes de rodar em escala.
3. **`02_classificacao_llm_conteudo.R`**: requer `GEMINI_API_KEY` (ou
   `GOOGLE_API_KEY`). Classifica o banco final (114 artigos, lido
   diretamente de `data/banco_final_114_burocracia_local.xlsx`) nas 10
   variáveis, com `chat_google_gemini(model = "gemini-2.5-flash")` e
   `k_consistency = 3`, seguindo o padrão de uso da [vinheta oficial do
   `acR`](https://ahenriquecp.com/acR/articles/qualitativo-llm.html). Roda
   primeiro em modo PILOTO (25 artigos, `RODAR_PILOTO <- TRUE`); confira a
   distribuição de categorias e o `confidence_score` antes de rodar tudo
   (`RODAR_PILOTO <- FALSE`). Gera `data/banco_114_llm_x_humano.xlsx`, com
   as colunas humanas originais e as novas colunas LLM (sufixo `_llm`) lado
   a lado, na mesma linha.

   **Bugs conhecidos do `acR`** (não são deste script, mas afetam qualquer
   provedor, e já foram reportados ao autor do pacote para correção na
   origem): `live = "terminal"` quebra com "Cannot find progress bar" porque
   `.ac_live_start()` não fixa `.envir` em `cli::cli_progress_bar()`; o
   script já contorna isso automaticamente (função `classificar_variavel()`,
   com fallback para `live = "off"`). Além disso, o parâmetro `temperature`
   de `ac_qual_code()` é aceito mas nunca repassado ao modelo dentro de
   `.ac_classify_one()`, então as rodadas de self-consistency não variam a
   temperatura de fato. Ambos exigem correção no código-fonte do `acR` (ver
   comentários no topo do script).
4. **`03_validacao_humana.R`**: compara, variável por variável, a
   codificação LLM (`<slug>_llm`) com a manual (nome original do banco
   final), calcula IRR (percent agreement, Alpha de Krippendorff, AC1 de
   Gwet, F1 macro) e gera um relatório metodológico HTML por variável em
   `output/`. `dimensao_teorica` (multilabel, mais de uma categoria por
   artigo) é avaliada à parte, por sobreposição exata e índice de Jaccard.
5. **`04_analise_descritiva.R`**: script único de análise do banco final,
   lê diretamente `data/banco_final_114_burocracia_local.xlsx` (o banco já
   codificado manualmente) e produz frequências, completude, tendência
   temporal, perfil bibliométrico e tabelas cruzadas descritivas. Saída
   apenas no console (não gera gráficos nem arquivos).
6. **`05_graficos_paper.R`**: le a mesma base do script `04` e gera os
   gráficos usados no artigo (perfil bibliométrico, frequências por
   variável e tendência temporal), um `.png` por tabela, salvos em
   `output/figuras/`. Não inclui os cruzamentos entre variáveis (seção 5
   do `04`): são muitas combinações, e o mapa de calor por par não entra
   no artigo.

## Variáveis do codebook

A tabela abaixo mostra, para cada variável do artigo, o nome usado no
**banco final** (o que importa para a análise em `04`) e o slug
correspondente no **codebook do `acR`** (o que importa para a
classificação/validação automática em `01`-`03`, onde aparece com o sufixo
`_llm`). Onde os nomes divergem, o crosswalk explícito em
`00b_crosswalk_categorias.R` faz a tradução.

A coluna "Fonte no banco final" mostra de onde vem, de fato, o valor usado
nas análises: `03_validacao_humana.R` decide isso variável por variável,
usando a classificação do LLM sempre que o Alpha de Krippendorff daquela
variável for maior ou igual a 0,70 (`LIMIAR_ALPHA_LLM`), e a codificação
manual (gold standard) caso contrário. `dimensao_teorica`, por ser
multilabel, não tem alfa categórico comparável e por isso usa sempre a
codificação humana. Os valores abaixo refletem a última rodada do pipeline,
salva em `data/banco_final_analise_burocracia_local.xlsx`.

| Variável (banco final)          | Slug no codebook `acR` (01/02/03)  | Fonte no banco final |
|-----------------------------------|--------------------------------------|------------------------|
| `nivel_governo`                  | (não aplicável)                       | Humano (definida na triagem manual) |
| `nivel_hierarquico_burocracia`   | (não aplicável)                       | Humano |
| `metodo`                         | (não aplicável)                       | Humano |
| `papel_burocracia`               | (não aplicável)                       | Humano |
| `setor_politica_publica`         | `setor_politica`                      | LLM |
| `dimensao_teorica` (multilabel)  | `dimensao_teorica`                    | Humano (multilabel, sem alfa comparável) |
| `relacao_politica_burocracia`    | `relacao_politica_burocracia`         | Humano |
| `explicacao_arranjo`             | `explicacao_arranjo`                  | Humano |
| `tipo_efeito`                    | `consequencia_arranjo`                | Humano |
| `valoracao`                      | `valoracao_burocracia`                | Humano |
| `enquadramento_normativo`        | `enquadramento_normativo`             | Humano |
| `grau_agencia`                   | `grau_agencia`                        | Humano |
| `referencia_federal`             | `referencia_federal`                  | LLM |
| `escopo_empirico`                | `escopo_empirico`                     | LLM |
| `year`                            | (não aplicável)                       | Humano (metadado bibliográfico) |

**Notas importantes sobre o crosswalk:**

- `explicacao_arranjo` ganhou a categoria `nao_aplicavel` (ausente na versão
  anterior do codebook) porque ela responde por cerca de 32% dos casos no
  banco humano. Sem essa categoria, o LLM seria forçado a "chutar" uma causa
  onde o artigo não aponta nenhuma.
- `dimensao_teorica` é **multilabel**: o banco humano registra combinações
  (ex.: `"Técnica | Política"`). O codebook em `01` foi ajustado para
  `multilabel = TRUE` e a validação em `03` usa sobreposição exata + Jaccard
  em vez de concordância categórica simples.

As colunas técnicas de triagem automática (`bureau_match`, `level_match`,
`federal_match`, `local_bureaucracy`, `title_norm`, `abstract_norm`,
`corpus_text`, `has_abstract`, `has_doi`, `title_len`, `abstract_len`) foram
removidas do banco de trabalho (`data/local_buro.csv`), mas seguem
preservadas em `data/raw_local_buro.csv`.

## Custo estimado

Com `gemini-2.5-flash` (modelo rápido/econômico da família Gemini) e
`k_consistency = 3`: o corpus final é pequeno (114 artigos) e não há mais
etapa de triagem sobre os 495 registros originais, então o custo total das
10 variáveis de conteúdo tende a ficar na faixa de poucos dólares. Confira
o preço atual por token em <https://ai.google.dev/pricing> antes de rodar a
base inteira (`RODAR_PILOTO <- FALSE`), já que os preços por provedor mudam
com frequência.

## Uso de Inteligência Artificial

Os autores utilizaram o modelo de linguagem Claude (Sonnet 5 da Anthropic),
operado por meio do ambiente Claude Code/Cowork, como ferramenta de apoio à
depuração e à estruturação dos scripts em R do pipeline computacional do
estudo, incluindo a identificação e correção de erros no pacote `acR` e a
organização dos scripts de classificação, validação e análise descritiva. A
ferramenta não foi utilizada para a codificação de conteúdo final do
corpus, para a interpretação dos resultados ou para a redação analítica do
capítulo. Todo o código gerado ou revisado com auxílio de IA foi verificado,
testado e validado pelos autores, que assumem integral responsabilidade
pela correção técnica e científica do material produzido.
