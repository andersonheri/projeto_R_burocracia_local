# =============================================================================
# 03_validacao_humana.R
# VALIDACAO DA CODIFICACAO LLM CONTRA O BANCO HUMANO (GOLD STANDARD COMPLETO)
#
# O QUE ESTE SCRIPT FAZ, EM UMA FRASE:
#   Compara, variavel por variavel, o que o LLM classificou (script 02) com
#   o que foi codificado manualmente, calcula a concordancia entre os dois,
#   gera um relatorio HTML unico com essa comparacao, e monta o banco final
#   que sera' usado na analise substantiva (script 04) -- escolhendo, para
#   cada variavel, se o valor que entra na analise vem do LLM ou do humano.
#
# A triagem foi feita manualmente, entao este script cobre apenas a
# validacao das 10 variaveis de CONTEUDO -- nao ha' etapa de triagem a
# validar aqui.
#
# Le data/banco_114_llm_x_humano.xlsx (gerado por 02_classificacao_llm_conteudo.R),
# que tem, lado a lado, na MESMA linha (mesmo `id`):
#   - as colunas codificadas manualmente (nomes do banco_final_114, ex.:
#     `setor_politica_publica`, `tipo_efeito`, `valoracao`, ...);
#   - as colunas classificadas pela LLM (sufixo "_llm", ex.:
#     `setor_politica_llm`, `consequencia_arranjo_llm`, ...).
#
# Como as duas codificacoes ja vem alinhadas por linha (mesmo `id`, mesmo
# arquivo-fonte), NAO e' preciso casar as duas bases por titulo -- so'
# comparar coluna humana x coluna LLM diretamente.
#
# IMPORTANTE -- nomenclatura: os slugs de variavel/categoria do `acR` (script
# 01, em snake_case sem acento) NAO sao identicos aos nomes/rotulos do banco
# humano (em portugues, com acento, vindos do codebook_burocracia_local.docx).
# O bloco 1 usa o crosswalk explicito entre os dois vocabularios (definido em
# 00b_crosswalk_categorias.R). Se voce alterar nomes de variavel ou categorias
# em 01_construir_codebooks_conteudo.R, atualize aquele crosswalk tambem --
# senao a comparacao falha silenciosamente (tudo vira NA).
#
# ATENCAO -- dimensao_teorica e' multilabel (ex.: "Tecnica | Politica") tanto
# no banco humano quanto no codebook (multilabel = TRUE em
# 01_construir_codebooks_conteudo.R). Kappa/IRR categorica classica nao se
# aplica bem a rotulos multiplos, entao essa variavel e' avaliada a parte,
# com sobreposicao exata e indice de Jaccard (secao 4), nao com
# ac_qual_reliability().
#
# MAPA DO SCRIPT:
#   Secao 1 -- carrega pacotes, codebooks e o crosswalk
#   Secao 2 -- le a base unica (humano + LLM lado a lado)
#   Secao 3 -- IRR variavel a variavel (variaveis de rotulo unico)
#   Secao 4 -- dimensao_teorica (multilabel): sobreposicao + Jaccard
#   Secao 5 -- relatorio HTML unico e consolidado
#   Secao 6 -- resumo no console
#   Secao 7 -- banco final para a analise substantiva (script 04)
#
# NOTA SOBRE ESTA VERSAO: assim como o script 02, este script foi reescrito
# para usar menos funcoes auxiliares. So' continuam sendo funcao os trechos
# curtos que sao chamados VARIAS vezes dentro do mesmo script (ex.: formatar
# um numero como percentual, ou puxar uma metrica de uma tabela) -- isso
# evita repetir a mesma formula varias vezes. Os laços que antes usavam
# `purrr::map_chr()`/`map2_dbl()`/`map2_lgl()` viraram `for` simples.
# =============================================================================


# =============================================================================
# Secao 1 -- Pacotes, codebooks e crosswalk
# =============================================================================
library(acR)
library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(scales)

source("scripts/01_construir_codebooks_conteudo.R")   # cria `codebooks_burocracia_local`
source("scripts/00b_crosswalk_categorias.R")           # cria `crosswalk_variaveis`, `crosswalk_categorias`, `rotulo_para_slug()`

# RELATORIO: este script NAO chama `ac_qual_report()` do acR (que gera um
# HTML por variavel, 9 arquivos separados, e tem um bug conhecido de nao
# resolver `path =` relativo -- reportado ao autor do pacote). Em vez
# disso, a Secao 5 monta UM UNICO relatorio HTML consolidado (todas
# as 10 variaveis, tabelas lado a lado), escrito a mao com HTML/CSS simples
# (sem depender de rmarkdown/pandoc), salvo em
# output/relatorio_metodo_consolidado.html.
dir.create("output", showWarnings = FALSE)
dir_output <- normalizePath("output", mustWork = TRUE)


# =============================================================================
# Secao 2 -- Ler a base unica (humano + LLM lado a lado, mesmo id)
# =============================================================================
caminho_base <- "data/banco_114_llm_x_humano.xlsx"

if (!file.exists(caminho_base)) {
  stop(
    "Nao encontrei '", caminho_base, "'. Rode antes 02_classificacao_llm_conteudo.R ",
    "(com RODAR_PILOTO <- FALSE)."
  )
}

base <- read.xlsx(caminho_base) %>% mutate(id = as.character(id))


# =============================================================================
# Secao 3 -- IRR variavel a variavel (categoricas de rotulo unico)
# =============================================================================
# "IRR" = Inter-Rater Reliability (confiabilidade entre avaliadores): o
# quanto duas fontes de codificacao (aqui, humano e LLM) concordam entre si.
# Esta secao roda um `for` -- uma volta por variavel -- que: (1) pega a
# coluna humana e a coluna LLM da mesma variavel; (2) traduz o rotulo humano
# para o mesmo "slug" (formato tecnico) que o LLM usa, via o crosswalk; (3)
# calcula a concordancia simples e chama ac_qual_reliability() do acR, que
# devolve varias metricas (Krippendorff alfa, Gwet AC1, F1 macro) de uma vez.
variaveis_single_label <- setdiff(names(crosswalk_variaveis), "dimensao_teorica")

resultados_irr <- list()

for (nm in variaveis_single_label) {

  col_humana <- crosswalk_variaveis[[nm]]
  col_llm    <- paste0(nm, "_llm")
  mapa       <- crosswalk_categorias[[nm]]

  if (!col_humana %in% names(base)) {
    message("Pulando '", nm, "': coluna '", col_humana, "' nao existe no banco.")
    next
  }
  if (!col_llm %in% names(base)) {
    message("Pulando '", nm, "': coluna '", col_llm, "' nao existe no banco (rode 02 primeiro).")
    next
  }

  humano <- base %>%
    transmute(
      doc_id    = id,
      categoria = rotulo_para_slug(.data[[col_humana]], mapa)
    )

  llm <- base %>%
    transmute(doc_id = id, categoria = .data[[col_llm]])

  n_sem_mapa <- sum(is.na(humano$categoria))
  if (n_sem_mapa > 0) {
    warning(
      "'", nm, "': ", n_sem_mapa, " rotulo(s) humano(s) sem correspondencia no ",
      "crosswalk_categorias -- revise o dicionario antes de confiar na IRR."
    )
  }

  irr <- tryCatch(
    ac_qual_reliability(llm = llm, human = humano),
    error = function(e) {
      message("ac_qual_reliability falhou para '", nm, "': ", conditionMessage(e))
      NULL
    }
  )

  concordancia_simples <- mean(llm$categoria == humano$categoria, na.rm = TRUE)

  cat("\n== ", nm, " (n = ", nrow(humano), ") ==\n", sep = "")
  cat("Concordancia simples (% categorias identicas):",
      scales::percent(concordancia_simples, accuracy = 0.1), "\n")
  if (!is.null(irr)) print(irr)

  resultados_irr[[nm]] <- list(
    n = nrow(humano),
    concordancia_simples = concordancia_simples,
    irr = irr
  )
}


# =============================================================================
# Secao 4 -- dimensao_teorica (multilabel) -- sobreposicao exata + Jaccard
# =============================================================================
# Diferente da Secao 3, aqui cada artigo pode ter MAIS de um rotulo (ex.:
# "Tecnica | Politica"), entao nao da' para comparar "categoria A == categoria
# B" direto -- precisamos comparar CONJUNTOS de rotulos. Para cada artigo
# (linha do banco), calculamos:
#   - match_exato: os dois conjuntos (humano e LLM) sao EXATAMENTE iguais?
#   - jaccard: o quanto os dois conjuntos se sobrepoem, de 0 (nada em comum)
#     a 1 (identicos) -- intersecao dividida pela uniao.
# Um `for` simples percorre os artigos um a um (mais facil de acompanhar do
# que uma combinacao de map2_dbl()/map2_lgl() sobre colunas-lista).
col_llm_dim <- "dimensao_teorica_llm"

if (col_llm_dim %in% names(base) && "dimensao_teorica" %in% names(base)) {

  mapa_dim <- crosswalk_categorias[["dimensao_teorica"]]

  # Regex usada para separar rotulos multiplos na mesma celula -- aceita
  # "|", "," ou ";" como separador, com ou sem espacos ao redor.
  separador_rotulos <- "\\s*\\|\\s*|\\s*,\\s*|\\s*;\\s*"

  n_artigos_dim   <- nrow(base)
  jaccard_valores <- numeric(n_artigos_dim)
  match_exato_valores <- logical(n_artigos_dim)

  for (i in seq_len(n_artigos_dim)) {

    # Rotulo humano (ex.: "Tecnica | Politica") -> slugs (ex.:
    # c("tecnica", "politica")), traduzidos pelo crosswalk e sem NA.
    partes_humano <- stringr::str_split(base$dimensao_teorica[i], separador_rotulos)[[1]]
    slugs_humano  <- unique(na.omit(rotulo_para_slug(partes_humano, mapa_dim)))

    # Resposta do LLM (ja' vem em slug, ex.: "tecnica|politica") -> vetor
    # de slugs, sem NA.
    partes_llm <- stringr::str_split(base[[col_llm_dim]][i], separador_rotulos)[[1]]
    slugs_llm  <- unique(partes_llm[!is.na(partes_llm)])

    # Indice de Jaccard = tamanho da intersecao / tamanho da uniao.
    if (length(slugs_humano) == 0 && length(slugs_llm) == 0) {
      jaccard_valores[i] <- NA_real_
    } else {
      tamanho_uniao <- length(union(slugs_humano, slugs_llm))
      jaccard_valores[i] <- if (tamanho_uniao == 0) {
        1
      } else {
        length(intersect(slugs_humano, slugs_llm)) / tamanho_uniao
      }
    }

    # Match exato = os dois conjuntos de rotulos sao identicos (mesma
    # composicao, independente da ordem).
    match_exato_valores[i] <- setequal(slugs_humano, slugs_llm)
  }

  comparacao_dim <- tibble::tibble(
    doc_id      = base$id,
    jaccard     = jaccard_valores,
    match_exato = match_exato_valores
  )

  cat("\n== dimensao_teorica (multilabel, n = ", nrow(comparacao_dim), ") ==\n", sep = "")
  cat("Match exato do conjunto de rotulos:",
      scales::percent(mean(comparacao_dim$match_exato, na.rm = TRUE), accuracy = 0.1), "\n")
  cat("Indice de Jaccard medio:", round(mean(comparacao_dim$jaccard, na.rm = TRUE), 3), "\n")

  resultados_irr[["dimensao_teorica"]] <- list(
    n = nrow(comparacao_dim),
    match_exato = mean(comparacao_dim$match_exato, na.rm = TRUE),
    jaccard_medio = mean(comparacao_dim$jaccard, na.rm = TRUE)
  )
} else {
  message(
    "Pulando dimensao_teorica: coluna '", col_llm_dim, "' nao encontrada ",
    "(rode 02_classificacao_llm_conteudo.R primeiro)."
  )
}


# =============================================================================
# Secao 5 -- Relatorio HTML unico e consolidado (todas as variaveis, um so' arquivo)
# =============================================================================
# As 4 funcoes pequenas abaixo (.pegar_metric, .fmt_pct, .fmt_num, .esc_html)
# continuam sendo funcoes porque cada uma e' chamada MUITAS vezes (uma vez
# por variavel, ou mais de uma vez por variavel) -- vira-las em funcao evita
# repetir a mesma formula de arredondar/formatar em varios lugares do script.

# Extrai uma metrica (linha) do tibble retornado por ac_qual_reliability()
# (colunas: metric, estimate, ci_lower, ci_upper, interpretation). Devolve
# NA em tudo se `irr_tbl` for NULL ou nao tiver essa metrica.
.pegar_metric <- function(irr_tbl, metric_nm) {
  vazio <- list(estimate = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_, interpretation = NA_character_)
  if (is.null(irr_tbl)) return(vazio)
  linha <- irr_tbl[irr_tbl$metric == metric_nm, , drop = FALSE]
  if (nrow(linha) == 0) return(vazio)
  list(
    estimate       = linha$estimate[1],
    ci_lower       = linha$ci_lower[1],
    ci_upper       = linha$ci_upper[1],
    interpretation = linha$interpretation[1]
  )
}

.fmt_pct <- function(x) if (is.na(x)) "--" else scales::percent(x, accuracy = 0.1)
.fmt_num <- function(x, dig = 3) if (is.na(x)) "--" else format(round(x, dig), nsmall = dig)
.esc_html <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x
}

# Monta uma linha de tabela HTML por variavel de rotulo unico. Um `for`
# simples percorre as variaveis, uma de cada vez, preenchendo o vetor
# `linhas_tabela1` posicao por posicao.
linhas_tabela1 <- character(length(variaveis_single_label))

for (idx in seq_along(variaveis_single_label)) {

  nm <- variaveis_single_label[idx]
  r  <- resultados_irr[[nm]]

  if (is.null(r)) {
    linhas_tabela1[idx] <- sprintf(
      "<tr><td>%s</td><td colspan='6' class='pulada'>Pulada (coluna humana ou LLM ausente no banco)</td></tr>",
      .esc_html(nm)
    )
  } else {
    alpha <- .pegar_metric(r$irr, "krippendorff_alpha")
    ac1   <- .pegar_metric(r$irr, "gwet_ac1")
    f1    <- .pegar_metric(r$irr, "f1_macro")
    linhas_tabela1[idx] <- sprintf(
      paste0(
        "<tr><td>%s</td><td class='num'>%d</td><td class='num'>%s</td>",
        "<td class='num'>%s<br><span class='ic'>IC95%% [%s, %s]</span></td>",
        "<td class='num'>%s</td><td class='num'>%s</td><td>%s</td></tr>"
      ),
      .esc_html(nm), r$n, .fmt_pct(r$concordancia_simples),
      .fmt_num(alpha$estimate), .fmt_num(alpha$ci_lower), .fmt_num(alpha$ci_upper),
      .fmt_num(ac1$estimate), .fmt_num(f1$estimate),
      .esc_html(ifelse(is.na(alpha$interpretation), "--", alpha$interpretation))
    )
  }
}

r_dim <- resultados_irr[["dimensao_teorica"]]
linha_tabela2 <- if (is.null(r_dim)) {
  "<tr><td>dimensao_teorica</td><td colspan='3' class='pulada'>Pulada (coluna humana ou LLM ausente no banco)</td></tr>"
} else {
  sprintf(
    "<tr><td>dimensao_teorica</td><td class='num'>%d</td><td class='num'>%s</td><td class='num'>%s</td></tr>",
    r_dim$n, .fmt_pct(r_dim$match_exato), .fmt_num(r_dim$jaccard_medio)
  )
}

data_relatorio <- format(Sys.time(), "%d/%m/%Y %H:%M")

relatorio_html <- paste0(
  "<!DOCTYPE html><html lang='pt-BR'><head><meta charset='utf-8'>",
  "<title>Codificacao LLM x banco humano - relatorio consolidado</title>",
  "<style>",
  "body{font-family:Georgia,'Times New Roman',serif;max-width:960px;margin:2rem auto;",
  "padding:0 1rem;color:#1a1a1a;line-height:1.5;}",
  "h1{font-size:1.6rem;border-bottom:2px solid #333;padding-bottom:.4rem;}",
  "h2{font-size:1.25rem;margin-top:2rem;border-bottom:1px solid #999;padding-bottom:.2rem;}",
  "table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.92rem;}",
  "th,td{border:1px solid #ccc;padding:.5rem .6rem;text-align:left;vertical-align:top;}",
  "th{background:#f0f0f0;}",
  "td.num{text-align:center;}",
  "span.ic{color:#666;font-size:.8rem;}",
  "td.pulada{color:#a00;font-style:italic;text-align:center;}",
  ".meta{color:#444;font-size:.9rem;margin-bottom:1.2rem;}",
  ".nota{color:#444;font-size:.85rem;margin-top:.6rem;}",
  "</style></head><body>",

  "<h1>Codificacao LLM x banco humano -- relatorio consolidado</h1>",
  "<p class='meta'>Autor: Anderson Henrique &middot; Gerado em: ", data_relatorio, "</p>",

  "<p>", sprintf(
    paste0(
      "Revisao sistematica de burocracia local (n = %d referencias, corpus final ",
      "apos triagem PRISMA), classificadas com Google Gemini (gemini-2.5-flash) via ",
      "ellmer, k_consistency = 3 rodadas de self-consistency (Wang et al., 2023), ",
      "comparadas ao banco_final_114 (100%% do corpus final, codificado manualmente ",
      "-- padrao-ouro/gold standard)."
    ),
    nrow(base)
  ), "</p>",

  "<h2>1. Variaveis de rotulo unico (IRR classica)</h2>",
  "<table><thead><tr><th>Variavel</th><th>n</th><th>Concordancia simples</th>",
  "<th>Krippendorff &alpha;</th><th>Gwet AC1</th><th>F1 macro</th>",
  "<th>Interpretacao (&alpha;)</th></tr></thead><tbody>",
  paste(linhas_tabela1, collapse = "\n"),
  "</tbody></table>",

  "<h2>2. Dimensao teorica (multilabel -- sobreposicao/Jaccard)</h2>",
  "<p class='nota'>Kappa/IRR categorica classica nao se aplica bem a rotulos ",
  "multiplos (o artigo pode mobilizar mais de uma dimensao teorica ao mesmo ",
  "tempo); por isso essa variavel e' avaliada a parte, por sobreposicao exata ",
  "do conjunto de rotulos e indice de Jaccard.</p>",
  "<table><thead><tr><th>Variavel</th><th>n</th><th>Match exato</th>",
  "<th>Jaccard medio</th></tr></thead><tbody>",
  linha_tabela2,
  "</tbody></table>",

  "<h2>3. Regra pratica de leitura</h2>",
  "<p class='nota'>Seguindo Landis e Koch (1977) e a recomendacao metodologica de ",
  "Krippendorff (2018): trate concordancia simples &lt; 80% (ou Krippendorff ",
  "&alpha; &lt; 0,67) como sinal para revisar o codebook ",
  "(<code>01_construir_codebooks_conteudo.R</code>) ou os exemplos ",
  "positivos/negativos de cada categoria antes de reportar a variavel no artigo ",
  "como validada.</p>",

  "</body></html>"
)

caminho_relatorio <- file.path(dir_output, "relatorio_metodo_consolidado.html")
writeLines(relatorio_html, caminho_relatorio, useBytes = TRUE)
message("Relatorio unico e consolidado salvo em: ", caminho_relatorio)


# =============================================================================
# Secao 6 -- Resumo consolidado (console)
# =============================================================================
cat("\n", strrep("=", 78), "\n", sep = "")
cat("RESUMO -- IRR LLM x BANCO HUMANO (data/banco_114_llm_x_humano.xlsx)\n")
cat(strrep("=", 78), "\n")
for (nm in names(resultados_irr)) {
  r <- resultados_irr[[nm]]
  if (!is.null(r$concordancia_simples)) {
    cat(sprintf("%-32s n=%-4d concordancia=%s\n", nm, r$n,
                scales::percent(r$concordancia_simples, accuracy = 0.1)))
  } else {
    cat(sprintf("%-32s n=%-4d match_exato=%s jaccard=%s\n", nm, r$n,
                scales::percent(r$match_exato, accuracy = 0.1),
                round(r$jaccard_medio, 3)))
  }
}
cat(
  "\nRelatorio unico e consolidado (todas as variaveis) em: ", caminho_relatorio, "\n",
  "Regra pratica (Krippendorff, 2018): trate concordancia < 0.80 (ou IRR < 0.67)\n",
  "como sinal para revisar o codebook (01) ou os exemplos antes de reportar a\n",
  "variavel no artigo como validada.\n",
  sep = ""
)


# =============================================================================
# Secao 7 -- Banco final para analise substantiva -- decide LLM ou humano POR
#             VARIAVEL, com base na confiabilidade calculada acima (secoes 3-4)
# =============================================================================
# REGRA (decidida apos revisar o relatorio da secao 5/6): para cada
# variavel single-label, se Krippendorff alfa >= LIMIAR_ALPHA_LLM, usa a
# classificacao LLM; caso contrario (alfa abaixo do limiar, OU variavel
# multilabel sem alfa comparavel -- e' o caso de dimensao_teorica, avaliada
# so' por Jaccard/match exato, sem metrica categorica classica) usa a
# codificacao humana (gold standard). O limiar e' aplicado ao alfa real
# calculado nas secoes 3-4 (nao a nomes fixos), entao, se o codebook for
# revisado de novo e o alfa de outra variavel cruzar o limiar, este bloco
# reflete isso automaticamente na proxima execucao.
#
# Cada variavel de conteudo entra no banco final com DUAS colunas:
#   - "{variavel}_final": o valor efetivamente usado nas analises
#     substantivas do artigo (rotulo humano, ex.: "Tecnica | Politica" --
#     mesmo quando a fonte e' LLM, o slug e' traduzido para o mesmo
#     vocabulario do banco humano via `slugs_para_rotulo_multilabel()`, de
#     00b_crosswalk_categorias.R, para as duas fontes ficarem no mesmo
#     formato).
#   - "{variavel}_fonte": "LLM" ou "Humano" -- trilha de auditoria
#     obrigatoria para qualquer decisao de codificacao que entra nos
#     resultados de um artigo (Krippendorff, 2018).
LIMIAR_ALPHA_LLM <- 0.70

# .alfa_da_variavel() continua sendo funcao porque e' chamada duas vezes
# para cada variavel (uma vez para decidir a fonte, outra para imprimir o
# alfa usado na decisao).
.alfa_da_variavel <- function(nm) {
  r <- resultados_irr[[nm]]
  if (is.null(r) || is.null(r$irr)) return(NA_real_)  # multilabel (dimensao_teorica) ou variavel pulada
  linha <- r$irr[r$irr$metric == "krippendorff_alpha", , drop = FALSE]
  if (nrow(linha) == 0) return(NA_real_)
  linha$estimate[1]
}

# Um `for` simples decide, variavel por variavel, se a fonte final e' "LLM"
# ou "Humano", guardando a decisao num vetor NOMEADO (decisao_fonte["nome_da_variavel"]).
decisao_fonte <- character(length(crosswalk_variaveis))
names(decisao_fonte) <- names(crosswalk_variaveis)

for (nm in names(crosswalk_variaveis)) {
  alpha <- .alfa_da_variavel(nm)
  decisao_fonte[[nm]] <- if (!is.na(alpha) && alpha >= LIMIAR_ALPHA_LLM) "LLM" else "Humano"
}

cat("\n", strrep("=", 78), "\n", sep = "")
cat("DECISAO DE FONTE POR VARIAVEL (limiar Krippendorff alfa >= ", LIMIAR_ALPHA_LLM, ")\n", sep = "")
cat(strrep("=", 78), "\n")
for (nm in names(decisao_fonte)) {
  alpha <- .alfa_da_variavel(nm)
  alpha_txt <- if (is.na(alpha)) "multilabel/sem alfa comparavel" else sprintf("alfa=%.3f", alpha)
  cat(sprintf("%-32s -> %-7s (%s)\n", nm, decisao_fonte[[nm]], alpha_txt))
}

# Ponto de partida do banco final: so' os metadados do artigo (sem as
# colunas de conteudo humanas/LLM ainda -- essas entram no `for` abaixo,
# uma variavel de cada vez).
banco_final_analise <- base %>%
  select(any_of(c(
    "id", "title", "authors", "year", "doi", "journal", "abstract",
    "nivel_governo", "nivel_hierarquico_burocracia", "metodo", "papel_burocracia"
  )))

for (nm in names(crosswalk_variaveis)) {
  col_humana <- crosswalk_variaveis[[nm]]
  col_llm    <- paste0(nm, "_llm")
  fonte      <- decisao_fonte[[nm]]
  mapa_categ <- crosswalk_categorias[[nm]]

  valor_final <- if (fonte == "LLM" && col_llm %in% names(base)) {
    if (!is.null(mapa_categ)) {
      vapply(base[[col_llm]], slugs_para_rotulo_multilabel, character(1), mapa = mapa_categ)
    } else {
      base[[col_llm]]
    }
  } else if (col_humana %in% names(base)) {
    base[[col_humana]]
  } else {
    NA_character_
  }

  banco_final_analise[[paste0(nm, "_final")]] <- valor_final
  banco_final_analise[[paste0(nm, "_fonte")]]  <- fonte
}

caminho_banco_final <- "data/banco_final_analise_burocracia_local.xlsx"
dir.create("data", showWarnings = FALSE)
openxlsx::write.xlsx(banco_final_analise, caminho_banco_final, overwrite = TRUE)

message(
  "\nBanco final para analise substantiva salvo em: ", caminho_banco_final,
  " (", nrow(banco_final_analise), " linhas, ", length(crosswalk_variaveis),
  " variaveis de conteudo x 2 colunas cada [_final/_fonte]).\n",
  "Fonte por variavel -- LLM: ",
  paste(names(decisao_fonte)[decisao_fonte == "LLM"], collapse = ", "),
  " | Humano: ", paste(names(decisao_fonte)[decisao_fonte == "Humano"], collapse = ", "), "."
)


# =============================================================================
# Limpeza do ambiente: remove objetos de trabalho/scratch (variaveis de loop,
# tabelas intermediarias usadas so' para montar o HTML) -- evita confundir a
# aba Environment do RStudio depois. NAO mexe em nenhum arquivo em disco.
#
# Fica no ambiente, para inspecao/reuso: `base` (banco humano + LLM lado a
# lado), `resultados_irr` (o resultado em si -- lista com n/concordancia/IRR
# ou match_exato/jaccard por variavel), `caminho_relatorio`, `dir_output`,
# `codebooks_burocracia_local`, `crosswalk_categorias`/`crosswalk_variaveis`,
# `banco_final_analise` (o banco final em si), `caminho_banco_final`,
# `decisao_fonte` (qual variavel veio de onde), `LIMIAR_ALPHA_LLM`.
# =============================================================================
.objetos_de_trabalho_03 <- c(
  "nm", "col_humana", "col_llm", "mapa", "humano", "llm", "n_sem_mapa", "irr",
  "concordancia_simples", "r", "col_llm_dim", "mapa_dim", "separador_rotulos",
  "n_artigos_dim", "jaccard_valores", "match_exato_valores", "i",
  "comparacao_dim", "idx", "linhas_tabela1", "r_dim", "linha_tabela2",
  "data_relatorio", "relatorio_html", "variaveis_single_label",
  "mapa_categ", "fonte", "valor_final", "alpha", "alpha_txt", "alpha", "ac1", "f1"
)
rm(list = intersect(.objetos_de_trabalho_03, ls()))
rm(.objetos_de_trabalho_03)
message(
  "\nAmbiente limpo (objetos de trabalho intermediarios removidos).\n",
  "Continuam disponiveis: base, resultados_irr, caminho_relatorio, dir_output, ",
  "codebooks_burocracia_local, crosswalk_categorias, banco_final_analise, ",
  "caminho_banco_final, decisao_fonte."
)
