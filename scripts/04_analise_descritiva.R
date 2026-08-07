# =============================================================================
# 04_analise_descritiva.R
# SCRIPT UNICO DE ANALISE DO BANCO FINAL -- revisao sistematica sobre
# burocracia local. n = 114 artigos (corpus final, triagem PRISMA feita
# manualmente), codificados manualmente segundo o codebook_burocracia_local.docx.
#
# Le data/banco_final_114_burocracia_local.xlsx (banco final ja codificado --
# NAO o output do pipeline LLM em data/banco_114_llm_x_humano.xlsx, que serve
# apenas para a validacao de concordancia em 03_validacao_humana.R) e produz:
#   1. Perfil bibliometrico (producao por ano, periodico, cobertura da amostra)
#   2. Completude da codificacao (quanto de cada variavel ja foi preenchido)
#   3. Frequencias de cada variavel categorica do codebook (dimensao_teorica
#      e' multilabel -- contada por rotulo individual, nao por combinacao)
#   4. Tendencia temporal (evolucao das correntes teoricas e metodos por ano)
#   5. Tabelas cruzadas descritivas entre variaveis-chave do codebook
#
# SAIDA: apenas tabelas no console. Nenhum arquivo e' exportado por este
# script.
# =============================================================================

library(dplyr)
library(tidyr)
library(janitor)
library(openxlsx)
library(scales)
library(stringr)
library(rlang)     # necessario para !!rlang::sym(v) dentro de tabyl()

# imprimir_tudo(): imprime uma tabela (data.frame ou tibble) por completo,
# sem truncar linhas. Usamos isso em vez de print(x, n = Inf) porque
# `n = Inf` so' e' entendido pelo METODO DE PRINT DO TIBBLE -- se `x` for
# um data.frame comum (o que pode acontecer dependendo da versao do dplyr
# instalada), o R nao reconhece "n" como argumento de print.data.frame(),
# tenta casar "n" com "na.print" por aproximacao de nome, e quebra com o
# erro confuso "invalid 'na.print' specification". as.data.frame() sempre
# imprime a tabela inteira, sem depender de `x` ser tibble ou data.frame --
# por isso e' a forma mais segura de garantir que nada fica escondido.
imprimir_tudo <- function(x) {
  print(as.data.frame(x))
}

# -----------------------------------------------------------------------------
# 0. Leitura da base final
# -----------------------------------------------------------------------------
caminho_base <- "data/banco_final_114_burocracia_local.xlsx"

if (!file.exists(caminho_base)) {
  stop(
    "Nao encontrei '", caminho_base, "'. Confirme que o banco final codificado ",
    "esta salvo em data/banco_final_114_burocracia_local.xlsx."
  )
}

base <- read.xlsx(caminho_base)

# Variaveis categoricas de rotulo unico (uma categoria por artigo)
variaveis_categoricas_single <- c(
  "nivel_governo", "nivel_hierarquico_burocracia", "metodo", "papel_burocracia",
  "setor_politica_publica", "relacao_politica_burocracia", "explicacao_arranjo",
  "tipo_efeito", "valoracao", "enquadramento_normativo", "grau_agencia",
  "referencia_federal", "escopo_empirico"
)

# Variavel multilabel (mais de uma categoria por artigo, separadas por "|")
variavel_multilabel <- "dimensao_teorica"

variaveis_categoricas <- c(variaveis_categoricas_single, variavel_multilabel)

cat(strrep("=", 78), "\n")
cat("BANCO FINAL -- BUROCRACIA LOCAL\n")
cat(strrep("=", 78), "\n")
cat("Total de referencias:", nrow(base), "\n")
cat("Periodo:", min(base$year, na.rm = TRUE), "-", max(base$year, na.rm = TRUE), "\n\n")

# -----------------------------------------------------------------------------
# 1. Perfil bibliometrico
# -----------------------------------------------------------------------------
cat(strrep("-", 78), "\n")
cat("1. PERFIL BIBLIOMETRICO\n")
cat(strrep("-", 78), "\n\n")

cat("-- Producao por ano --\n")
producao_ano <- base %>%
  count(year, name = "n_artigos") %>%
  arrange(year)
imprimir_tudo(producao_ano)

cat("\n-- Top 15 periodicos --\n")
top_periodicos <- base %>%
  count(journal, name = "n_artigos", sort = TRUE) %>%
  mutate(pct = percent(n_artigos / sum(n_artigos), accuracy = 0.1)) %>%
  slice_head(n = 15)
imprimir_tudo(top_periodicos)

cat("\n-- Cobertura de metadados --\n")
cobertura <- base %>%
  summarise(
    pct_com_doi      = percent(mean(!is.na(doi) & doi != ""), accuracy = 0.1),
    pct_com_abstract = percent(mean(!is.na(abstract) & abstract != ""), accuracy = 0.1)
  )
print(cobertura)

# -----------------------------------------------------------------------------
# 2. Completude da codificacao
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("2. COMPLETUDE DA CODIFICACAO (% de referencias com valor preenchido)\n")
cat(strrep("-", 78), "\n\n")

completude <- sapply(variaveis_categoricas, function(v) {
  if (!v %in% names(base)) return(NA)
  mean(!is.na(base[[v]]) & base[[v]] != "")
})
completude_tbl <- tibble::tibble(
  variavel       = names(completude),
  pct_preenchido = percent(unname(completude), accuracy = 0.1)
) %>% arrange(desc(pct_preenchido))
imprimir_tudo(completude_tbl)

# -----------------------------------------------------------------------------
# 3. Frequencias por variavel do codebook
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("3. FREQUENCIAS POR VARIAVEL DO CODEBOOK\n")
cat(strrep("-", 78), "\n")

for (v in variaveis_categoricas_single) {
  if (!v %in% names(base)) next
  cat("\n-- ", v, " --\n", sep = "")
  tab <- base %>%
    tabyl(!!rlang::sym(v)) %>%
    adorn_pct_formatting(digits = 1)
  print(tab)
}

# dimensao_teorica: multilabel ("Tecnica | Politica") -- conta cada rotulo
# individualmente. O total de contagens pode superar n porque um artigo pode
# mobilizar mais de uma dimensao teorica ao mesmo tempo.
if (variavel_multilabel %in% names(base)) {
  cat("\n-- ", variavel_multilabel, " (multilabel; % sobre n = ", nrow(base), " artigos) --\n", sep = "")
  freq_multilabel <- base %>%
    filter(!is.na(.data[[variavel_multilabel]]), .data[[variavel_multilabel]] != "") %>%
    mutate(rotulo = str_split(.data[[variavel_multilabel]], "\\s*\\|\\s*")) %>%
    tidyr::unnest(rotulo) %>%
    mutate(rotulo = str_squish(rotulo)) %>%
    count(rotulo, name = "n_artigos", sort = TRUE) %>%
    mutate(pct_dos_artigos = percent(n_artigos / nrow(base), accuracy = 0.1))
  imprimir_tudo(freq_multilabel)
}

# -----------------------------------------------------------------------------
# 4. Tendencia temporal
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("4. TENDENCIA TEMPORAL\n")
cat(strrep("-", 78), "\n\n")

cat("-- Metodo por ano (contagem) --\n")
metodo_ano <- base %>%
  filter(!is.na(metodo)) %>%
  count(year, metodo) %>%
  pivot_wider(names_from = metodo, values_from = n, values_fill = 0) %>%
  arrange(year)
imprimir_tudo(metodo_ano)

if (variavel_multilabel %in% names(base)) {
  cat("\n-- Dimensao teorica mobilizada por ano (contagem; multilabel) --\n")
  teoria_ano <- base %>%
    filter(!is.na(.data[[variavel_multilabel]]), .data[[variavel_multilabel]] != "") %>%
    mutate(rotulo = str_split(.data[[variavel_multilabel]], "\\s*\\|\\s*")) %>%
    tidyr::unnest(rotulo) %>%
    mutate(rotulo = str_squish(rotulo)) %>%
    count(year, rotulo) %>%
    pivot_wider(names_from = rotulo, values_from = n, values_fill = 0) %>%
    arrange(year)
  imprimir_tudo(teoria_ano)
}

# -----------------------------------------------------------------------------
# 5. Tabelas cruzadas descritivas (sem teste de hipotese, so' descricao)
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("5. TABELAS CRUZADAS DESCRITIVAS\n")
cat(strrep("-", 78), "\n")

cruzamentos <- list(
  c("metodo", "nivel_hierarquico_burocracia"),
  c("relacao_politica_burocracia", "enquadramento_normativo"),
  c("explicacao_arranjo", "tipo_efeito"),
  c("grau_agencia", "referencia_federal"),
  c("escopo_empirico", "metodo"),
  c("papel_burocracia", "valoracao")
)

for (par in cruzamentos) {
  v1 <- par[1]; v2 <- par[2]
  if (!all(c(v1, v2) %in% names(base))) next
  cat("\n-- ", v1, " x ", v2, " --\n", sep = "")
  tab <- base %>%
    filter(!is.na(.data[[v1]]), !is.na(.data[[v2]])) %>%
    tabyl(!!rlang::sym(v1), !!rlang::sym(v2)) %>%
    adorn_totals(c("row", "col")) %>%
    adorn_percentages("row") %>%
    adorn_pct_formatting(digits = 1) %>%
    adorn_ns()
  print(tab)
}

# dimensao_teorica (multilabel) x valoracao -- expande um registro por rotulo
# antes de cruzar, ja que tabyl() nao lida com celulas multivaloradas.
if (variavel_multilabel %in% names(base) && "valoracao" %in% names(base)) {
  cat("\n-- ", variavel_multilabel, " x valoracao (multilabel, 1 linha por rotulo) --\n", sep = "")
  tab_dim_base <- base %>%
    filter(!is.na(.data[[variavel_multilabel]]), .data[[variavel_multilabel]] != "",
           !is.na(valoracao)) %>%
    mutate(rotulo = str_split(.data[[variavel_multilabel]], "\\s*\\|\\s*")) %>%
    tidyr::unnest(rotulo) %>%
    mutate(rotulo = str_squish(rotulo))

  tab_dim <- tab_dim_base %>%
    tabyl(rotulo, valoracao) %>%
    adorn_totals(c("row", "col")) %>%
    adorn_percentages("row") %>%
    adorn_pct_formatting(digits = 1) %>%
    adorn_ns()
  print(tab_dim)
}

cat("\n", strrep("=", 78), "\n", sep = "")
cat("FIM DA ANALISE\n")
cat(strrep("=", 78), "\n")
