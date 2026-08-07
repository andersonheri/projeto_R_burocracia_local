# =============================================================================
# 02_classificacao_llm_conteudo.R
#
# O QUE ESTE SCRIPT FAZ, EM UMA FRASE:
#   Le o banco de 114 artigos JA codificados manualmente, manda o titulo +
#   resumo de cada um para um modelo de linguagem (LLM, no caso o Google
#   Gemini) classificar nas mesmas 10 variaveis do codebook, e salva tudo
#   num unico arquivo -- codificacao humana e codificacao do LLM lado a
#   lado, prontas para comparar em 03_validacao_humana.R.
#
# ESTE SCRIPT E' A APLICACAO PRATICA DO PACOTE `acR`. As funcoes do acR
# usadas aqui sao:
#   - ac_corpus()     -- empacota o banco de artigos no formato que o acR
#                        entende (usada na PARTE 5).
#   - ac_qual_code()  -- roda a classificacao por LLM de UMA variavel do
#                        codebook contra o corpus (usada dentro da funcao
#                        `classificar_variavel()`, na PARTE 4.2).
# Os codebooks em si (`ac_qual_codebook()`) sao criados no script anterior,
# 01_construir_codebooks_conteudo.R.
#
# BUGS DO acR CONTORNADOS AQUI (reportados ao autor do pacote para correcao
# na origem; os contornos abaixo sao so' para este projeto continuar
# funcionando enquanto isso -- detalhes de cada um nos comentarios das
# PARTES 4.1 e 4.2, mais adiante):
#   1. `live = "terminal"` do ac_qual_code() quebra com um erro de barra de
#      progresso. Contorno: PARTE 4.2.
#   2. O parametro `temperature` do ac_qual_code() e' aceito mas nunca
#      chega a ser usado de fato (bug so' documentado, sem contorno
#      possivel do nosso lado).
#   3. Quando uma variavel do codebook e' multilabel (pode ter mais de uma
#      categoria por artigo -- e' o caso so' de `dimensao_teorica`), o
#      ac_qual_code() as vezes quebra a classificacao INTEIRA daquela
#      variavel. Contorno: PARTE 4.1 (rotina propria, sem usar
#      ac_qual_code() so' para essa variavel).
#
# MAPA DO SCRIPT (PARTES, em ordem de execucao):
#   PARTE 1 -- Pacotes que este script usa
#   PARTE 2 -- Carrega os codebooks (01) e o dicionario de traducao (00b)
#   PARTE 3 -- Opcoes que voce pode mudar (o que rodar, quanto, etc.)
#   PARTE 4 -- Funcoes auxiliares (o "motor" do script)
#   PARTE 5 -- Monta o corpus no formato do acR
#   PARTE 6 -- Conecta com o modelo de linguagem (Gemini)
#   PARTE 7 -- Piloto (teste rapido e barato antes de rodar tudo)
#   PARTE 8 -- Classificacao completa (o corpus inteiro, as variaveis que
#              ainda faltam) + salva o banco final + gera copia legivel
#   PARTE 9 -- Limpeza do ambiente (so' organizacao, nao afeta os arquivos)
#
# NOTA SOBRE ESTA VERSAO: em relacao a versoes anteriores, este script foi
# reescrito para usar MENOS funcoes auxiliares. So' viraram funcao de verdade
# os pedacos de codigo que sao CHAMADOS MAIS DE UMA VEZ no script (senao
# copiar/colar o mesmo trecho toda hora); tudo que so' roda uma unica vez foi
# escrito direto, em sequencia, no lugar onde acontece -- fica mais facil de
# ler de cima para baixo, como uma receita.
#
# CHAVE DE API: leia de ".Renviron" (nunca do script). Se ainda nao criou o
# seu, veja ".Renviron.example" na raiz do projeto ou rode 00_setup_pacotes.R.
# O ellmer le GEMINI_API_KEY (ou GOOGLE_API_KEY) automaticamente do ambiente.
# =============================================================================


# =============================================================================
# PARTE 1 -- Pacotes que este script usa
# =============================================================================
# Cada `library()` abaixo "liga" um pacote ja instalado (ver
# 00_setup_pacotes.R). Sem isso, as funcoes desses pacotes nao existem no
# script. O comentario ao lado de cada um diz PARA QUE ele e' usado aqui.

library(acR)        # ac_corpus(), ac_qual_code() -- o pacote sendo testado
library(ellmer)     # chat_google_gemini() -- conexao com o modelo Gemini
library(dplyr)      # %>%, mutate(), select(), left_join() etc.
library(openxlsx)   # ler e escrever arquivos .xlsx
library(rlang)      # necessario para !!nm := valor dentro de select()/rename()
library(stringr)    # extracao do JSON na resposta bruta do modelo
library(jsonlite)   # transformar texto JSON em lista do R
library(tibble)     # tibble() -- versao moderna do data.frame
library(cli)        # barra de progresso da rotina propria (mesmo padrao do acR)


# =============================================================================
# PARTE 2 -- Carrega os codebooks (01) e o dicionario de traducao (00b)
# =============================================================================
# `source()` roda outro arquivo .R inteiro, como se voce tivesse colado o
# codigo dele aqui. Isso cria, no ambiente deste script, os objetos que
# aqueles arquivos definem -- sem precisar copiar/colar o codigo.

source("scripts/01_construir_codebooks_conteudo.R")
# ^ cria `codebooks_burocracia_local`: uma lista com os 10 codebooks
#   (ac_qual_codebook()) das variaveis de conteudo.

source("scripts/00b_crosswalk_categorias.R")
# ^ cria `crosswalk_categorias` (dicionario slug -> rotulo humano) e a
#   funcao `slugs_para_rotulo_multilabel()`, usadas no final da PARTE 8 para
#   deixar a copia de leitura sem "_" nem "|" cru.


# =============================================================================
# PARTE 3 -- Opcoes que voce pode mudar
# =============================================================================
# Estas 4 variaveis controlam o comportamento do script. Sao a UNICA parte
# que voce normalmente precisa editar entre uma rodada e outra.

# RODAR_PILOTO: TRUE roda primeiro um teste rapido (PARTE 7) antes da
# classificacao completa (PARTE 8), na MESMA execucao do script -- nao
# precisa rodar duas vezes. FALSE pula direto para a classificacao completa.
RODAR_PILOTO <- TRUE

# N_PILOTO: quantos artigos (dos 114) entram no teste rapido da PARTE 7.
N_PILOTO <- 25

# VARIAVEIS_PILOTO: quais variaveis testar no piloto. Por padrao, so'
# "dimensao_teorica" -- e' a unica que usa a rotina propria (PARTE 4.1, por
# causa do bug #3 acima) e vale a pena confirmar que esta funcionando antes
# de rodar nos 114 artigos.
VARIAVEIS_PILOTO <- "dimensao_teorica"

# FORCAR_RECLASSIFICAR: nomes de variavel aqui SEMPRE sao reclassificados
# no corpus completo (PARTE 8), MESMO que ja tenham uma coluna pronta em
# "data/banco_114_llm_x_humano.xlsx" de uma rodada anterior. Use isso
# depois de mudar a definicao de uma categoria em
# 01_construir_codebooks_conteudo.R e querer testar se a mudanca melhorou a
# concordancia com o humano. As variaveis que NAO estiverem aqui e ja
# tiverem coluna pronta NAO sao reclassificadas -- ou seja, nao gastam
# token de novo.
#
# As 6 abaixo foram revisadas depois de uma analise da matriz de confusao
# humano x LLM (concordancia moderada/fraca em cada uma): 3 tinham uma
# categoria "meio-termo" (ambivalente/ambos) que o LLM quase nunca escolhia
# (enquadramento_normativo, valoracao_burocracia, grau_agencia); as outras
# 3 tinham categorias especificas que o LLM nao reconhecia e classificava
# como "sem causa"/"nao aborda" por padrao (explicacao_arranjo,
# relacao_politica_burocracia, consequencia_arranjo).
FORCAR_RECLASSIFICAR <- c(
  "enquadramento_normativo",
  "valoracao_burocracia",
  "grau_agencia",
  "explicacao_arranjo",
  "relacao_politica_burocracia",
  "consequencia_arranjo"
)


# =============================================================================
# PARTE 4 -- Funcoes auxiliares
# =============================================================================
# Esta parte so' DEFINE funcoes -- nenhuma delas roda ainda. Elas sao
# chamadas mais adiante, nas PARTES 7 e 8. So' viraram funcao aqui os
# trechos que sao usados em MAIS DE UM lugar do script (o piloto e a
# classificacao completa chamam exatamente a mesma rotina); o resto do
# script (montar o corpus, rodar o piloto, gerar a copia legivel etc.) e'
# escrito direto, em sequencia, la' na frente, no lugar onde acontece.


# -----------------------------------------------------------------------------
# PARTE 4.1 -- Rotina propria para classificar "dimensao_teorica"
# -----------------------------------------------------------------------------
# "dimensao_teorica" e' diferente das outras 9 variaveis: um artigo pode se
# encaixar em MAIS DE UMA categoria ao mesmo tempo (ex.: "Tecnica" e
# "Politica" juntas). Isso se chama "multilabel". O ac_qual_code() do acR
# tem um bug com variaveis multilabel (bug #3 da nota do topo do arquivo):
# as vezes o modelo devolve as categorias como uma lista (array) em vez de
# texto unico, e o acR quebra ao tentar montar a tabela de resultado.
#
# Por isso, so' para esta variavel, NAO usamos ac_qual_code() -- em vez
# disso, esta funcao fala com o `ellmer` diretamente (o pacote que o acR
# tambem usa por baixo dos panos), com um prompt bem explicito sobre o
# formato de resposta esperado. O resultado final tem o MESMO FORMATO que
# ac_qual_code() devolveria (colunas doc_id / categoria / confidence_score)
# -- assim, o resto do script nem precisa saber que o caminho foi diferente.
#
# A funcao inteira roda em 4 passos, todos comentados abaixo:
#   Passo 1 -- monta o texto de instrucao (system prompt), uma unica vez.
#   Passo 2 -- acha as colunas de id e de texto no corpus.
#   Passo 3 -- para CADA documento, faz k_consistency perguntas
#              independentes ao modelo (self-consistency, Wang et al.,
#              2023) e combina as respostas em uma categoria final e um
#              confidence_score.
#   Passo 4 -- junta o resultado de todos os documentos numa tabela so'.
classificar_dimensao_teorica <- function(corpus, codebook, chat, k_consistency = 3, live = "terminal") {

  categorias_validas <- names(codebook$categories)

  # --- Passo 1: monta o system prompt -------------------------------------
  # Para cada categoria do codebook, monta uma linha de texto com o nome, a
  # definicao e (se existirem) os exemplos positivos/negativos. Um `for`
  # simples percorre as categorias, uma de cada vez, e vai enchendo o vetor
  # `linhas_categorias` -- e' aqui que corrigimos o bug #3 do acR (o prompt
  # do acR nao deixava claro que a resposta multilabel devia ser uma UNICA
  # STRING separada por "|").
  nomes_categorias  <- names(codebook$categories)
  linhas_categorias <- character(length(nomes_categorias))

  for (i in seq_along(nomes_categorias)) {

    nm_categoria <- nomes_categorias[i]
    categoria    <- codebook$categories[[nm_categoria]]

    texto_exemplos_pos <- ""
    if (!is.null(categoria$examples_pos) && length(categoria$examples_pos) > 0) {
      texto_exemplos_pos <- paste0(
        " Exemplo positivo: \"", paste(categoria$examples_pos, collapse = "\" / \""), "\"."
      )
    }

    texto_exemplos_neg <- ""
    if (!is.null(categoria$examples_neg) && length(categoria$examples_neg) > 0) {
      texto_exemplos_neg <- paste0(
        " Exemplo negativo (NAO conta como esta categoria): \"",
        paste(categoria$examples_neg, collapse = "\" / \""), "\"."
      )
    }

    linhas_categorias[i] <- paste0(
      "- \"", nm_categoria, "\": ", categoria$definition,
      texto_exemplos_pos, texto_exemplos_neg
    )
  }

  system_prompt <- paste0(
    codebook$instructions, "\n\n",
    "Categorias validas (use exatamente estes nomes, em minusculas, com underscore, sem acentos):\n",
    paste(linhas_categorias, collapse = "\n"), "\n\n",
    "FORMATO DE RESPOSTA (obrigatorio): responda APENAS com um objeto JSON, ",
    "sem nenhum texto antes ou depois, exatamente neste formato:\n",
    "{\"categoria\": \"nome1|nome2\", \"raciocinio\": \"...\"}\n\n",
    "O campo \"categoria\" e' SEMPRE uma UNICA STRING de texto -- nunca um ",
    "array JSON. Se mais de uma categoria se aplicar ao texto, junte os ",
    "nomes NA MESMA STRING separados pelo caractere \"|\" (exemplo: ",
    "\"tecnica|politica\"). Se nenhuma categoria se aplicar claramente, use ",
    "a categoria que mais se aproxima -- nao deixe o campo vazio. NUNCA ",
    "responda \"categoria\": [\"tecnica\", \"politica\"] (isso e' invalido). ",
    "NUNCA inclua um nome de categoria que nao esteja na lista acima."
  )

  # --- Passo 2: acha as colunas de id e de texto no corpus ----------------
  # O corpus vem de ac_corpus() (PARTE 5). Em teoria a coluna de id sempre
  # se chama "doc_id" e a de texto "text" -- mas, por seguranca (caso uma
  # versao futura do acR mude esses nomes internos), procuramos entre
  # alguns nomes possiveis em vez de assumir um unico nome fixo.
  candidatos_doc_id <- intersect(c("doc_id", "docid", "id"), names(corpus))
  candidatos_texto  <- intersect(c("text", "texto", "texto_classificacao"), names(corpus))

  if (length(candidatos_doc_id) == 0) {
    stop("Nao encontrei nenhuma coluna de id de documento no corpus (tentei: doc_id, docid, id).")
  }
  if (length(candidatos_texto) == 0) {
    stop("Nao encontrei nenhuma coluna de texto no corpus (tentei: text, texto, texto_classificacao).")
  }

  docs <- tibble::tibble(
    doc_id = as.character(corpus[[candidatos_doc_id[1]]]),
    texto  = as.character(corpus[[candidatos_texto[1]]])
  )

  n_docs <- nrow(docs)

  # Barra de progresso (opcional, so' para acompanhar no terminal).
  pb <- NULL
  if (identical(live, "terminal")) {
    pb <- cli::cli_progress_bar(
      "Classificando dimensao_teorica (rotina propria)",
      total = n_docs, clear = FALSE
    )
  }

  # --- Passo 3: um documento de cada vez -----------------------------------
  # `linhas` vai guardar uma linha de resultado (doc_id / categoria /
  # confidence_score) por documento. Comecamos com uma lista vazia do
  # tamanho certo (`vector("list", n_docs)`) e vamos preenchendo posicao
  # por posicao dentro do loop `for` abaixo -- e' o jeito mais basico do R
  # de "guardar o resultado de cada volta de um loop".
  linhas <- vector("list", n_docs)

  for (i in seq_len(n_docs)) {

    doc_id_i <- docs$doc_id[i]
    texto_i  <- docs$texto[i]

    # Para este documento, faz k_consistency perguntas independentes ao
    # modelo. `rodadas[[k]]` guarda as categorias que saíram na rodada k.
    rodadas <- vector("list", k_consistency)

    for (k in seq_len(k_consistency)) {

      # `$clone()` cria uma copia nova da conversa, para cada rodada
      # comecar do zero (sem "lembrar" da rodada anterior).
      chat_k <- chat$clone()
      chat_k$set_system_prompt(system_prompt)

      resposta <- tryCatch(
        chat_k$chat(texto_i, echo = "none"),
        error = function(e) {
          message(
            "Aviso: falha na rodada ", k, "/", k_consistency, " do doc '",
            doc_id_i, "' (dimensao_teorica): ", conditionMessage(e)
          )
          NA_character_  # se der erro (ex.: rede), essa rodada conta como "sem categoria"
        }
      )

      # Le o JSON que o modelo devolveu. O modelo deveria responder SO' com
      # o JSON pedido, mas as vezes cerca a resposta com texto extra ou com
      # marcacao de bloco de codigo (```json ... ```) -- por isso pescamos
      # so' o trecho entre o primeiro "{" e o ultimo "}".
      categorias_da_rodada <- character(0)

      if (!is.null(resposta) && !is.na(resposta) && nzchar(resposta)) {

        bloco_json <- stringr::str_extract(resposta, stringr::regex("\\{.*\\}", dotall = TRUE))

        if (!is.na(bloco_json)) {

          resposta_lida <- tryCatch(jsonlite::fromJSON(bloco_json), error = function(e) NULL)

          if (!is.null(resposta_lida) && !is.null(resposta_lida$categoria)) {
            # Funciona tanto se o modelo respondeu certo (string
            # "tecnica|politica") quanto se errou e respondeu um array de
            # verdade (defesa extra contra o bug #3) -- e ignora qualquer
            # nome que nao esteja na lista de categorias validas.
            bruto  <- unlist(resposta_lida$categoria, use.names = FALSE)
            partes <- unlist(strsplit(as.character(bruto), "\\|"))
            partes <- trimws(tolower(partes))
            partes <- partes[nzchar(partes) & partes %in% categorias_validas]
            categorias_da_rodada <- sort(unique(partes))
          }
        }
      }

      rodadas[[k]] <- categorias_da_rodada
    }

    if (!is.null(pb)) cli::cli_progress_update(id = pb)

    # Categoria final = as categorias que apareceram em pelo menos metade
    # das rodadas (ex.: 2 de 3).
    todas_categorias   <- unlist(rodadas)
    contagem_categorias <- table(todas_categorias)
    limiar              <- k_consistency / 2

    categorias_finais <- sort(names(contagem_categorias)[contagem_categorias >= limiar])
    categoria_final   <- if (length(categorias_finais) == 0) {
      NA_character_
    } else {
      paste(categorias_finais, collapse = "|")
    }

    # confidence_score = o quanto as rodadas concordaram entre si, medido
    # pela media do indice de Jaccard entre cada par de rodadas (1 =
    # concordancia total; 0 = nenhuma categoria em comum). Precisa de pelo
    # menos 2 rodadas para dar para comparar.
    if (k_consistency < 2) {
      confidence <- NA_real_
    } else {
      pares_de_rodadas <- utils::combn(k_consistency, 2, simplify = FALSE)
      jaccards <- numeric(length(pares_de_rodadas))

      for (p in seq_along(pares_de_rodadas)) {
        a <- rodadas[[pares_de_rodadas[[p]][1]]]
        b <- rodadas[[pares_de_rodadas[[p]][2]]]
        if (length(a) == 0 && length(b) == 0) {
          jaccards[p] <- 1
        } else {
          uniao <- length(union(a, b))
          jaccards[p] <- if (uniao == 0) 1 else length(intersect(a, b)) / uniao
        }
      }

      confidence <- mean(jaccards)
    }

    linhas[[i]] <- tibble::tibble(
      doc_id = doc_id_i, categoria = categoria_final, confidence_score = confidence
    )
  }

  if (!is.null(pb)) cli::cli_progress_done(id = pb)

  # --- Passo 4: junta o resultado de todos os documentos numa tabela so' --
  # dplyr::bind_rows() empilha a lista `linhas` (uma tabelinha de 1 linha
  # por documento) num unico tibble.
  dplyr::bind_rows(linhas)
}


# -----------------------------------------------------------------------------
# PARTE 4.2 -- Chamar o acR (ac_qual_code) com contorno do bug da barra de
#              progresso
# -----------------------------------------------------------------------------
# Para as outras 9 variaveis (tudo, exceto dimensao_teorica), usamos
# ac_qual_code() do acR normalmente -- e' a funcao "de fabrica" do pacote
# para classificar um corpus inteiro contra um codebook. O UNICO ajuste
# aqui e' um contorno para o bug #1 (ver topo do arquivo): `live =
# "terminal"` as vezes quebra com um erro de barra de progresso que nao
# tem a ver com a classificacao em si. Se isso acontecer, tentamos de novo
# com `live = "off"` (sem barra de progresso, mas sem perder nenhum
# resultado). Vira funcao porque e' chamada uma vez PARA CADA variavel, em
# duas etapas diferentes do script (piloto e classificacao completa).
classificar_variavel <- function(corpus, codebook, chat, k_consistency = 3) {
  tryCatch(
    ac_qual_code(
      corpus        = corpus,
      codebook      = codebook,
      chat          = chat,
      k_consistency = k_consistency,
      live          = "terminal"
    ),
    error = function(e) {
      if (grepl("progress bar", conditionMessage(e), fixed = TRUE)) {
        message(
          "Aviso: bug conhecido do acR em live = \"terminal\" (barra de progresso). ",
          "Rodando de novo com live = \"off\"."
        )
        ac_qual_code(
          corpus        = corpus,
          codebook      = codebook,
          chat          = chat,
          k_consistency = k_consistency,
          live          = "off"
        )
      } else {
        stop(e)  # outro tipo de erro -- nao e' o bug conhecido, deixa parar o script
      }
    }
  )
}


# -----------------------------------------------------------------------------
# PARTE 4.3 -- Despachante: escolhe qual das duas rotinas usar
# -----------------------------------------------------------------------------
# classificar_uma_variavel_com_log() e' a funcao que as PARTES 7 e 8 chamam
# de fato. Ela decide qual caminho usar para a variavel `nm`:
#   - se for "dimensao_teorica" -> usa a rotina propria (PARTE 4.1);
#   - qualquer outra variavel   -> usa ac_qual_code() do acR (PARTE 4.2).
# E tambem protege o script inteiro: se ESSA variavel der erro, avisa e
# devolve NULL, em vez de travar a classificacao das outras variaveis.
# Tambem vira funcao porque e' chamada uma vez POR VARIAVEL, em duas
# etapas diferentes do script (piloto e classificacao completa).
classificar_uma_variavel_com_log <- function(corpus, codebook, chat, nm, k_consistency = 3) {
  tryCatch(
    {
      if (identical(nm, "dimensao_teorica")) {
        classificar_dimensao_teorica(corpus, codebook, chat, k_consistency = k_consistency, live = "terminal")
      } else {
        classificar_variavel(corpus, codebook, chat, k_consistency = k_consistency)
      }
    },
    error = function(e) {
      message(
        "\n!! Falha ao classificar '", nm, "': ", conditionMessage(e),
        "\n   Pulando esta variavel -- as demais continuam normalmente.\n"
      )
      NULL
    }
  )
}


# =============================================================================
# PARTE 5 -- Monta o corpus no formato do acR (ac_corpus())
# =============================================================================
# A partir daqui o script comeca a EXECUTAR de fato (as PARTES 1-4 so'
# prepararam o terreno).

caminho_base <- "data/banco_final_114_burocracia_local.xlsx"

if (!file.exists(caminho_base)) {
  stop("Nao encontrei '", caminho_base, "' em data/.")
}

base <- openxlsx::read.xlsx(caminho_base)

base <- base %>%
  mutate(
    id                    = as.character(id),  # doc_id do ac_corpus() e' sempre character
    texto_classificacao   = paste0(title, ". ", coalesce(abstract, ""))
  )

# ac_corpus() e' a primeira funcao do acR que aparece neste script: ela
# empacota o data.frame `base` no formato que o resto do pacote espera,
# dizendo qual coluna e' o texto a classificar (`texto_classificacao`) e
# qual e' o identificador unico de cada linha (`id`).
corpus <- ac_corpus(base, text = texto_classificacao, docid = id)


# =============================================================================
# PARTE 6 -- Conecta com o modelo de linguagem (Gemini)
# =============================================================================
# chat_google_gemini() e' do pacote `ellmer` (nao do acR) -- cria a conexao
# que sera reaproveitada em todas as chamadas de classificacao abaixo.
# Troque `model =` aqui se quiser usar outra versao do Gemini; use
# ellmer::models_google_gemini() para listar as disponiveis.
chat <- chat_google_gemini(model = "gemini-2.5-flash")


# =============================================================================
# PARTE 7 -- Piloto (teste rapido e barato antes de rodar tudo)
# =============================================================================
# Roda so' os primeiros N_PILOTO artigos, so' para as variaveis em
# VARIAVEIS_PILOTO (PARTE 3), e mostra a distribuicao de categorias e o
# confidence_score mediano -- da' para conferir se esta plausivel antes de
# gastar token nos 114 artigos inteiros. Este bloco NUNCA impede a PARTE 8
# de rodar: mesmo com RODAR_PILOTO <- TRUE, a classificacao completa
# acontece depois, na mesma execucao do script.
#
# Tambem tem um "atalho de economia": se a(s) variavel(is) do piloto ja
# estiverem 100% classificadas no corpus completo (e nao estiverem em
# FORCAR_RECLASSIFICAR), o piloto e' pulado -- nao faz sentido gastar
# token testando de novo algo que ja esta pronto.

resultado_piloto <- list()  # fica vazio se RODAR_PILOTO <- FALSE ou se o piloto for pulado

# Confere o que ja esta pronto no arquivo de trabalho (se ele existir).
.caminho_saida_check <- "data/banco_114_llm_x_humano.xlsx"
.colunas_ja_prontas_piloto <- character(0)
if (file.exists(.caminho_saida_check)) {
  .nomes_banco_existente <- names(openxlsx::read.xlsx(.caminho_saida_check))
  .colunas_ja_prontas_piloto <- names(codebooks_burocracia_local)[
    paste0(names(codebooks_burocracia_local), "_llm") %in% .nomes_banco_existente
  ]
}
# Variaveis em FORCAR_RECLASSIFICAR NAO contam como "ja prontas" -- serao
# testadas/reclassificadas de proposito.
.colunas_ja_prontas_piloto <- setdiff(.colunas_ja_prontas_piloto, FORCAR_RECLASSIFICAR)

if (RODAR_PILOTO && length(setdiff(VARIAVEIS_PILOTO, .colunas_ja_prontas_piloto)) == 0) {

  message(
    "Piloto pulado: todas as variaveis em VARIAVEIS_PILOTO (",
    paste(VARIAVEIS_PILOTO, collapse = ", "),
    ") ja estao classificadas no corpus completo, em '", .caminho_saida_check, "' -- ",
    "nada a testar de novo. Seguindo direto para a PARTE 8."
  )

} else if (RODAR_PILOTO) {

  # corpus[1:N_PILOTO, ] pega so' as primeiras N_PILOTO linhas do corpus.
  corpus_piloto <- corpus[1:N_PILOTO, ]

  variaveis_piloto <- setdiff(
    intersect(VARIAVEIS_PILOTO, names(codebooks_burocracia_local)),
    .colunas_ja_prontas_piloto
  )
  if (length(variaveis_piloto) == 0) {
    stop("VARIAVEIS_PILOTO nao bate com nenhum nome em codebooks_burocracia_local.")
  }
  message(
    "Piloto (sanity-check) restrito a: ", paste(variaveis_piloto, collapse = ", "),
    " -- as demais variaveis vao direto pro corpus completo na PARTE 8."
  )

  # Um `for` simples classifica cada variavel do piloto, uma de cada vez, e
  # guarda o resultado na lista `resultado_piloto`, usando o nome da
  # variavel como chave (ex.: resultado_piloto[["dimensao_teorica"]]).
  for (nm in variaveis_piloto) {
    message("Piloto -- classificando variavel: ", nm)
    resultado_piloto[[nm]] <- classificar_uma_variavel_com_log(
      corpus        = corpus_piloto,
      codebook      = codebooks_burocracia_local[[nm]],
      chat          = chat,
      nm            = nm,
      k_consistency = 3
    )
  }

  # Se uma variavel falhou, `classificar_uma_variavel_com_log()` devolveu
  # NULL para ela -- e, no R, atribuir NULL a um elemento de lista faz
  # aquele nome simplesmente NAO aparecer na lista. Por isso,
  # `names(resultado_piloto)` ja' contem so' as variaveis que DERAM CERTO.
  variaveis_ok     <- names(resultado_piloto)
  variaveis_falhas <- setdiff(variaveis_piloto, variaveis_ok)

  # Mostra a distribuicao de categorias e o confidence_score mediano de
  # cada variavel testada -- e' o que voce deve olhar para decidir se esta
  # tudo plausivel.
  for (nm in variaveis_ok) {
    message("== ", nm, " (piloto, ", N_PILOTO, " artigos) ==")
    print(table(resultado_piloto[[nm]]$categoria, useNA = "always"))
    message("confidence_score mediano: ", median(resultado_piloto[[nm]]$confidence_score, na.rm = TRUE))
  }

  if (length(variaveis_falhas) > 0) {
    warning(
      "Variaveis que falharam no piloto: ", paste(variaveis_falhas, collapse = ", "),
      ". A PARTE 8, a seguir, vai tentar classifica-las de novo no corpus completo."
    )
  }

  message("Piloto concluido -- seguindo direto para a classificacao do corpus completo (PARTE 8).")
}


# =============================================================================
# PARTE 8 -- Classificacao completa + salvar o banco final + copia legivel
# =============================================================================
# Esta parte roda SEMPRE, nesta mesma execucao do script, logo apos a
# PARTE 7 -- nao depende de rodar o script de novo. Ela classifica, no
# corpus completo (114 artigos), so' as variaveis que ainda faltam.
#
# "Ainda faltam" quer dizer duas coisas ao mesmo tempo (para economizar
# token):
#   (a) por VARIAVEL: se o arquivo de trabalho ja existir de uma rodada
#       anterior, variaveis que ja tem coluna "{nome}_llm" nele NAO sao
#       reclassificadas -- A NAO SER que estejam em FORCAR_RECLASSIFICAR
#       (PARTE 3).
#   (b) por DOCUMENTO: se uma variavel rodou no piloto (PARTE 7), os
#       N_PILOTO artigos que ja foram classificados ali NAO sao
#       reclassificados aqui -- so' os artigos restantes do corpus
#       completo. Os dois pedacos (piloto + restante) sao juntados antes
#       de entrar no banco final.
#
# As chaves { } abaixo NAO sao uma funcao -- sao so' um "bloco" para
# organizar visualmente onde a PARTE 8 comeca e termina.
{
  caminho_saida <- "data/banco_114_llm_x_humano.xlsx"

  colunas_ja_prontas <- character(0)
  base_llm_existente  <- NULL

  if (file.exists(caminho_saida)) {

    base_llm_existente <- openxlsx::read.xlsx(caminho_saida) %>%
      mutate(id = as.character(id))

    colunas_ja_prontas <- names(codebooks_burocracia_local)[
      paste0(names(codebooks_burocracia_local), "_llm") %in% names(base_llm_existente)
    ]
    # variaveis em FORCAR_RECLASSIFICAR NAO contam como "ja prontas" mesmo
    # que tenham coluna no arquivo -- vao ser reclassificadas de proposito.
    colunas_ja_prontas <- setdiff(colunas_ja_prontas, FORCAR_RECLASSIFICAR)

    if (length(colunas_ja_prontas) > 0) {
      message(
        "Reaproveitando de '", caminho_saida, "' (sem gastar token de novo): ",
        paste(colunas_ja_prontas, collapse = ", ")
      )
    }
    if (length(intersect(FORCAR_RECLASSIFICAR, names(codebooks_burocracia_local))) > 0) {
      message(
        "Reclassificacao FORCADA (substitui a coluna antiga, mesmo ja pronta): ",
        paste(intersect(FORCAR_RECLASSIFICAR, names(codebooks_burocracia_local)), collapse = ", ")
      )
    }
  }

  # Quais variaveis efetivamente vao ser classificadas nesta rodada.
  variaveis_a_rodar <- setdiff(names(codebooks_burocracia_local), colunas_ja_prontas)

  if (length(variaveis_a_rodar) == 0) {

    message("Todas as variaveis ja estao classificadas em '", caminho_saida, "'. Nada a rodar.")

  } else {

    message(
      "Classificando agora as variaveis pendentes no corpus completo (",
      nrow(base), " artigos): ", paste(variaveis_a_rodar, collapse = ", ")
    )

    # Descobre quais artigos ainda NAO foram cobertos pelo piloto (se ele
    # rodou nesta mesma execucao). Se RODAR_PILOTO <- FALSE, `corpus_piloto`
    # nem existe e o "restante" e' o corpus inteiro.
    if (exists("corpus_piloto") && nrow(corpus_piloto) < nrow(corpus)) {
      corpus_restante <- corpus[(nrow(corpus_piloto) + 1):nrow(corpus), ]
    } else if (exists("corpus_piloto")) {
      corpus_restante <- corpus[0, ]  # piloto ja cobriu o corpus inteiro
    } else {
      corpus_restante <- corpus
    }

    # Para cada variavel pendente (um `for` simples, uma variavel por
    # volta), classifica so' o que falta (reaproveita o piloto quando
    # existir) e ja' deixa as colunas com o sufixo certo ("_llm" /
    # "_llm_confianca"). Guarda o resultado de cada variavel na lista
    # `resultados`, usando o nome da variavel como chave -- exatamente como
    # fizemos com `resultado_piloto` na PARTE 7.
    resultados <- list()

    for (nm in variaveis_a_rodar) {

      res_piloto_nm <- resultado_piloto[[nm]]  # NULL se essa variavel nao foi testada no piloto

      res <- if (!is.null(res_piloto_nm) && nrow(corpus_restante) > 0) {

        message(
          "Classificando variavel: ", nm, " -- reaproveitando ", nrow(res_piloto_nm),
          " artigos ja classificados no piloto, rodando so' os ", nrow(corpus_restante),
          " restantes."
        )
        res_restante <- classificar_uma_variavel_com_log(
          corpus        = corpus_restante,
          codebook      = codebooks_burocracia_local[[nm]],
          chat          = chat,
          nm            = nm,
          k_consistency = 3
        )
        if (is.null(res_restante)) {
          NULL
        } else {
          dplyr::bind_rows(
            res_piloto_nm  %>% select(doc_id, categoria, confidence_score),
            res_restante   %>% select(doc_id, categoria, confidence_score)
          )
        }

      } else if (!is.null(res_piloto_nm)) {
        # o piloto ja' cobriu o corpus inteiro -- nada restante para rodar
        res_piloto_nm %>% select(doc_id, categoria, confidence_score)

      } else {
        message("Classificando variavel: ", nm, " (", nrow(corpus), " documentos)")
        classificar_uma_variavel_com_log(
          corpus        = corpus,
          codebook      = codebooks_burocracia_local[[nm]],
          chat          = chat,
          nm            = nm,
          k_consistency = 3
        )
      }

      if (!is.null(res)) {
        # Renomeia as colunas "categoria"/"confidence_score" para
        # "{nome_da_variavel}_llm" / "{nome_da_variavel}_llm_confianca", que
        # e' o formato final esperado no banco.
        resultados[[nm]] <- res %>%
          select(id = doc_id, categoria, confidence_score) %>%
          rename(
            !!paste0(nm, "_llm")             := categoria,
            !!paste0(nm, "_llm_confianca")   := confidence_score
          )
      }
      # se `res` for NULL (variavel falhou), nao atribuimos nada a
      # `resultados[[nm]]` -- assim como na PARTE 7, isso significa que o
      # nome da variavel simplesmente nao aparece em `resultados`.
    }

    variaveis_falhas <- setdiff(variaveis_a_rodar, names(resultados))
    resultados_ok    <- resultados

    if (length(variaveis_falhas) > 0) {
      warning(
        "As seguintes variaveis falharam nesta rodada e continuam pendentes: ",
        paste(variaveis_falhas, collapse = ", "),
        ". Rode o script de novo -- as que ja deram certo (incluindo as reaproveitadas ",
        "de rodadas anteriores) NAO serao reclassificadas nem vao gastar token outra vez."
      )
    }

    if (length(resultados_ok) > 0) {

      # Junta os resultados novos (cada um com sufixo "_llm") num unico
      # dataframe largo, por id. Comeca com a primeira tabela da lista e
      # vai juntando (full_join) as demais, uma de cada vez -- e' o mesmo
      # resultado que reduce()/Reduce() dariam, so' escrito como um `for`
      # explicito.
      base_variaveis_llm_novas <- resultados_ok[[1]]
      if (length(resultados_ok) > 1) {
        for (j in seq(2, length(resultados_ok))) {
          base_variaveis_llm_novas <- full_join(base_variaveis_llm_novas, resultados_ok[[j]], by = "id")
        }
      }

      # IMPORTANTE: o ponto de partida do banco final e' SEMPRE `base` (o
      # corpus completo) -- nunca `base_llm_existente`. Se so' fossemos a
      # partir do arquivo salvo antes, um arquivo anterior menor (ex.:
      # salvo por engano so' com os N_PILOTO artigos) truncaria o banco
      # final. Aqui so' aproveitamos do arquivo antigo as COLUNAS
      # "_llm"/"_llm_confianca" ja prontas, por id -- as LINHAS sempre vem
      # do corpus completo.
      base_codificada <- base %>% select(-texto_classificacao)

      if (!is.null(base_llm_existente)) {
        # Descarta do arquivo antigo as colunas das variaveis em
        # FORCAR_RECLASSIFICAR -- senao o left_join abaixo colide com a
        # coluna nova (mesmo nome) e gera duplicata ".x"/".y" em vez de
        # substituir pelo resultado recem-classificado.
        colunas_forcadas <- c(
          paste0(FORCAR_RECLASSIFICAR, "_llm"),
          paste0(FORCAR_RECLASSIFICAR, "_llm_confianca")
        )
        colunas_llm_existentes <- base_llm_existente %>%
          select(id, matches("_llm(_confianca)?$")) %>%
          select(-any_of(colunas_forcadas))
        base_codificada <- base_codificada %>%
          left_join(colunas_llm_existentes, by = "id")
      }

      base_codificada <- base_codificada %>%
        left_join(base_variaveis_llm_novas, by = "id")

      # Trava de seguranca: o banco final tem que ter uma linha por artigo
      # do corpus completo -- nunca menos (ex.: por causa de um join com
      # um arquivo antigo truncado).
      if (nrow(base_codificada) != nrow(base)) {
        stop(
          "Banco final ficou com ", nrow(base_codificada), " linhas, mas o ",
          "corpus completo tem ", nrow(base), ". Alguma coisa truncou o ",
          "resultado (provavelmente um '", caminho_saida, "' antigo salvo ",
          "so' com o piloto) -- apague ou corrija esse arquivo antes de ",
          "rodar de novo."
        )
      }

      dir.create("data", showWarnings = FALSE)
      write.xlsx(base_codificada, caminho_saida, overwrite = TRUE)

      total_prontas <- length(colunas_ja_prontas) + length(resultados_ok)
      message(
        "Banco salvo em ", caminho_saida, " (", nrow(base_codificada), " linhas).\n",
        total_prontas, "/", length(codebooks_burocracia_local), " variaveis completas (",
        length(colunas_ja_prontas), " reaproveitadas do arquivo + ", length(resultados_ok),
        " classificadas nesta rodada).\n",
        "Proximo passo: 03_validacao_humana.R."
      )

    } else {
      message("Nenhuma variavel pendente foi classificada com sucesso nesta rodada -- nada novo para salvar.")
    }
  }

  # ---------------------------------------------------------------------
  # Gera uma copia do banco so' para LEITURA, sem "_" nem "|" cru
  # ---------------------------------------------------------------------
  # O arquivo "de trabalho" (data/banco_114_llm_x_humano.xlsx) precisa
  # manter nomes de coluna em snake_case (ex.: "setor_politica_llm") e
  # valores em slug cru (ex.: "gestao_fiscal_administrativa_geral") porque
  # e' assim que o restante do pipeline (este script e o 03) reconhece as
  # colunas automaticamente. Mas isso e' feio de ler. Por isso, sempre que
  # o arquivo de trabalho existir (recem-salvo ou de rodada anterior),
  # geramos uma SEGUNDA copia, so' para os olhos humanos, com cabecalho e
  # valores traduzidos -- SEM chamar o LLM de novo, e' so' uma traducao de
  # rotulo em cima do que ja foi classificado.
  #
  # Os dois dicionarios abaixo fazem essa traducao: nome tecnico da
  # variavel/coluna -> rotulo em portugues, sem "_".
  rotulos_legiveis_variaveis <- c(
    setor_politica               = "Setor de Politica Publica",
    dimensao_teorica             = "Dimensao Teorica",
    relacao_politica_burocracia  = "Relacao Politica-Burocracia",
    explicacao_arranjo           = "Explicacao do Arranjo",
    consequencia_arranjo         = "Consequencia do Arranjo (Tipo de Efeito)",
    valoracao_burocracia         = "Valoracao da Burocracia",
    enquadramento_normativo      = "Enquadramento Normativo",
    grau_agencia                 = "Grau de Agencia",
    referencia_federal           = "Referencia Federal",
    escopo_empirico              = "Escopo Empirico"
  )

  # Mesma ideia, mas para as colunas do banco ORIGINAL (metadados do artigo
  # + as 10 colunas ja codificadas manualmente). Os nomes das chaves aqui
  # tem que bater exatamente com o cabecalho de
  # data/banco_final_114_burocracia_local.xlsx.
  rotulos_legiveis_colunas_humanas <- c(
    id                              = "ID",
    title                           = "Titulo",
    authors                         = "Autores",
    year                            = "Ano",
    doi                             = "DOI",
    journal                         = "Periodico",
    abstract                        = "Resumo",
    nivel_governo                   = "Nivel de Governo",
    nivel_hierarquico_burocracia    = "Nivel Hierarquico da Burocracia",
    metodo                          = "Metodo",
    papel_burocracia                = "Papel da Burocracia",
    setor_politica_publica          = "Setor de Politica Publica",
    dimensao_teorica                = "Dimensao Teorica",
    relacao_politica_burocracia     = "Relacao Politica-Burocracia",
    explicacao_arranjo              = "Explicacao do Arranjo",
    tipo_efeito                     = "Tipo de Efeito (Consequencia do Arranjo)",
    valoracao                       = "Valoracao",
    enquadramento_normativo         = "Enquadramento Normativo",
    grau_agencia                    = "Grau de Agencia",
    referencia_federal              = "Referencia Federal",
    escopo_empirico                 = "Escopo Empirico",
    justificativa_codificacao       = "Justificativa da Codificacao"
  )

  if (file.exists(caminho_saida)) {

    banco_legivel <- openxlsx::read.xlsx(caminho_saida)

    # Passo 1: para cada variavel classificada pelo LLM, troca o VALOR (o
    # slug cru, ex. "tecnica|politica") pelo rotulo humano (ex. "Tecnica |
    # Politica"), e so' depois renomeia o cabecalho da coluna.
    for (nm in names(rotulos_legiveis_variaveis)) {

      col_llm       <- paste0(nm, "_llm")            # ex.: "dimensao_teorica_llm"
      col_confianca <- paste0(nm, "_llm_confianca")  # ex.: "dimensao_teorica_llm_confianca"
      rotulo        <- rotulos_legiveis_variaveis[[nm]]
      mapa_categ    <- crosswalk_categorias[[nm]]    # NULL se a variavel nao estiver no dicionario

      if (col_llm %in% names(banco_legivel)) {
        if (!is.null(mapa_categ)) {
          # vapply() aplica slugs_para_rotulo_multilabel() a CADA valor da
          # coluna, um por um, e devolve um vetor de texto do mesmo tamanho.
          banco_legivel[[col_llm]] <- vapply(
            banco_legivel[[col_llm]],
            slugs_para_rotulo_multilabel,
            character(1),
            mapa = mapa_categ
          )
        }
        names(banco_legivel)[names(banco_legivel) == col_llm] <- paste0(rotulo, " (LLM)")
      }

      if (col_confianca %in% names(banco_legivel)) {
        names(banco_legivel)[names(banco_legivel) == col_confianca] <- paste0(rotulo, " (LLM) - Confianca")
      }
    }

    # Passo 2: colunas humanas/metadados -- so' o cabecalho muda, porque o
    # VALOR ja' e' texto legivel (vem do codebook_burocracia_local.docx, nao
    # de um slug do acR).
    for (nm in names(rotulos_legiveis_colunas_humanas)) {
      if (nm %in% names(banco_legivel)) {
        names(banco_legivel)[names(banco_legivel) == nm] <- rotulos_legiveis_colunas_humanas[[nm]]
      }
    }

    # Passo 3 (trava de seguranca): se sobrar algum cabecalho com "_", avisa
    # -- e' sinal de que apareceu uma coluna nova que ainda nao esta em
    # nenhum dos dois dicionarios acima. Isso NAO interrompe o script, so'
    # avisa.
    restantes_com_underscore <- grep("_", names(banco_legivel), value = TRUE)
    if (length(restantes_com_underscore) > 0) {
      warning(
        "Colunas com '_' ainda sem rotulo legivel (adicione a ",
        "'rotulos_legiveis_variaveis' ou 'rotulos_legiveis_colunas_humanas'): ",
        paste(restantes_com_underscore, collapse = ", ")
      )
    }

    # Passo 4: salva a copia legivel, num arquivo com nome parecido mas com
    # "_legivel" no final (ex.: "banco_114_llm_x_humano_legivel.xlsx").
    caminho_legivel <- sub("\\.xlsx$", "_legivel.xlsx", caminho_saida)
    openxlsx::write.xlsx(banco_legivel, caminho_legivel, overwrite = TRUE)
    message(
      "Copia com cabecalho e valores legiveis (sem '_' cru nem '|' colado) salva em: ",
      caminho_legivel
    )
  }
}


# =============================================================================
# PARTE 9 -- Limpeza do ambiente (so' organizacao, nao toca em arquivos)
# =============================================================================
# rm() remove objetos do "ambiente" do R (a lista de variaveis que aparece
# na aba Environment do RStudio). Isso NAO desfaz nada que ja foi salvo em
# disco -- os arquivos .xlsx continuam exatamente como foram gravados. E'
# so' para nao deixar dezenas de variaveis de trabalho temporarias
# poluindo a tela depois que o script termina.
#
# Continuam disponiveis DEPOIS desta limpeza (para voce inspecionar ou
# reusar no console, se quiser): `base`, `corpus`, `chat`, `caminho_saida`,
# `codebooks_burocracia_local`, `crosswalk_categorias`, e `base_codificada`
# (se alguma variavel foi classificada nesta rodada).
.objetos_de_trabalho_02 <- c(
  "corpus_piloto", "variaveis_piloto", "resultado_piloto", "variaveis_ok",
  "variaveis_falhas", "nm", "colunas_ja_prontas", "base_llm_existente",
  "variaveis_a_rodar", "corpus_restante", "resultados", "resultados_ok",
  "base_variaveis_llm_novas", "colunas_llm_existentes", "total_prontas",
  ".caminho_saida_check", ".colunas_ja_prontas_piloto", ".nomes_banco_existente",
  "colunas_forcadas", "rotulos_legiveis_variaveis", "rotulos_legiveis_colunas_humanas",
  "banco_legivel", "col_llm", "col_confianca", "rotulo", "mapa_categ",
  "restantes_com_underscore", "caminho_legivel", "j", "res", "res_piloto_nm",
  "res_restante"
)
rm(list = intersect(.objetos_de_trabalho_02, ls()))
rm(.objetos_de_trabalho_02)

message(
  "\nAmbiente limpo (objetos de trabalho intermediarios removidos).\n",
  "Continuam disponiveis: base, corpus, chat, caminho_saida, ",
  "codebooks_burocracia_local, crosswalk_categorias",
  if (exists("base_codificada")) ", base_codificada" else "", "."
)
