# =============================================================================
# 05_graficos_paper.R
# GRAFICOS PARA O PAPER -- revisao sistematica sobre burocracia local.
# n = 114 artigos (corpus final, triagem PRISMA feita manualmente),
# codificados manualmente segundo o codebook_burocracia_local.docx.
#
# Recuperado do commit inicial do projeto (onde a geracao de graficos vivia
# dentro de 04_analise_descritiva.R) e separado num script proprio para nao
# mexer no 04 atual, que hoje so' imprime tabelas no console. Removida a
# secao de mapas de calor de cruzamento entre variaveis-chave (nao usada
# no paper).
#
# Le data/banco_final_114_burocracia_local.xlsx (banco final ja codificado --
# NAO o output do pipeline LLM em data/banco_114_llm_x_humano.xlsx, que serve
# apenas para a validacao de concordancia em 03_validacao_humana.R) e produz:
#   1. Perfil bibliometrico (producao por ano, top periodicos)
#   2. Frequencias de cada variavel categorica do codebook (dimensao_teorica
#      e' multilabel -- contada por rotulo individual, nao por combinacao)
#   3. Tendencia temporal (evolucao das correntes teoricas e metodos por ano)
#
# SAIDA: tabelas no console + um grafico ggplot2 para cada tabela, salvo
# como .png em output/figuras/.
# =============================================================================

library(dplyr)
library(tidyr)
library(janitor)
library(openxlsx)
library(scales)
library(stringr)
library(rlang)     # necessario para !!rlang::sym(v) dentro de tabyl()
library(ggplot2)   # os graficos deste script

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
# Graficos -- configuracao usada em TODOS os graficos deste script
# -----------------------------------------------------------------------------
# tema_grafico: define o "visual padrao" (fundo, grade, e o tamanho da
# letra) de todo grafico feito neste script. base_size = 14 deixa titulo,
# eixos e rotulos maiores -- mais legivel quando o grafico for reduzido
# dentro do artigo ou de uma apresentacao. Definido uma unica vez aqui e
# reaproveitado em cada grafico com `+ tema_grafico`.
tema_grafico <- theme_minimal(base_size = 14)

# Pasta onde todo grafico deste script e' salvo (criada uma unica vez, no
# inicio -- se ja existir, showWarnings = FALSE so' evita um aviso).
dir.create("output/figuras", showWarnings = FALSE, recursive = TRUE)

# salvar_grafico(): salva um grafico ggplot como .png dentro de
# output/figuras/, sempre com o mesmo tamanho e a mesma resolucao. Vira
# funcao porque e' chamada uma vez PARA CADA grafico do script -- assim nao
# repetimos os mesmos 4 argumentos do ggsave() em cada um deles.
salvar_grafico <- function(grafico, nome_arquivo, largura = 8, altura = 5) {
  ggsave(
    filename = file.path("output/figuras", nome_arquivo),
    plot     = grafico,
    width    = largura,
    height   = altura,
    dpi      = 300
  )
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

cat(strrep("=", 78), "\n")
cat("BANCO FINAL -- BUROCRACIA LOCAL (GRAFICOS PARA O PAPER)\n")
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

# Grafico de LINHA: e' uma serie temporal (um ano no eixo X), entao linha
# comunica evolucao melhor do que barras. Sem titulo interno -- a legenda
# de cada grafico fica no texto do artigo, nao dentro da imagem.
grafico_producao_ano <- ggplot(producao_ano, aes(x = year, y = n_artigos)) +
  geom_line(color = "#1B4F72", linewidth = 1.1) +
  geom_point(color = "#1B4F72", size = 2.2) +
  scale_x_continuous(breaks = scales::breaks_width(2)) +
  labs(x = "Ano", y = "Nº de artigos") +
  tema_grafico
print(grafico_producao_ano)
salvar_grafico(grafico_producao_ano, "01_producao_por_ano.png")

cat("\n-- Top 15 periodicos --\n")
top_periodicos <- base %>%
  count(journal, name = "n_artigos", sort = TRUE) %>%
  mutate(pct = percent(n_artigos / sum(n_artigos), accuracy = 0.1)) %>%
  slice_head(n = 15)
imprimir_tudo(top_periodicos)

# Grafico de barras horizontais (coord_flip): nomes de periodico ficam
# longos demais para caber no eixo X na horizontal.
grafico_periodicos <- top_periodicos %>%
  ggplot(aes(x = reorder(journal, n_artigos), y = n_artigos)) +
  geom_col(fill = "#1B4F72") +
  geom_text(aes(label = n_artigos), hjust = -0.3, size = 4.5) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = NULL, y = "Nº de artigos") +
  tema_grafico
print(grafico_periodicos)
salvar_grafico(grafico_periodicos, "02_top_periodicos.png", altura = 6)

# -----------------------------------------------------------------------------
# 2. Frequencias por variavel do codebook
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("2. FREQUENCIAS POR VARIAVEL DO CODEBOOK\n")
cat(strrep("-", 78), "\n")

# grafico_barras_variavel(): conta as categorias de UMA variavel e devolve
# um grafico de barras horizontais, ordenado da categoria mais para a
# menos frequente. Vira funcao porque e' chamada uma vez PARA CADA uma das
# 13 variaveis de rotulo unico, dentro do `for` logo abaixo.
grafico_barras_variavel <- function(base, variavel) {
  base %>%
    filter(!is.na(.data[[variavel]]), .data[[variavel]] != "") %>%
    count(.data[[variavel]], name = "n_artigos") %>%
    ggplot(aes(x = reorder(.data[[variavel]], n_artigos), y = n_artigos)) +
    geom_col(fill = "#1B4F72") +
    geom_text(aes(label = n_artigos), hjust = -0.3, size = 4.5) +
    coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(x = NULL, y = "Nº de artigos") +
    tema_grafico
}

for (v in variaveis_categoricas_single) {
  if (!v %in% names(base)) next
  cat("\n-- ", v, " --\n", sep = "")
  tab <- base %>%
    tabyl(!!rlang::sym(v)) %>%
    adorn_pct_formatting(digits = 1)
  print(tab)

  grafico_v <- grafico_barras_variavel(base, v)
  print(grafico_v)
  salvar_grafico(grafico_v, paste0("03_freq_", v, ".png"))
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

  grafico_multilabel <- freq_multilabel %>%
    ggplot(aes(x = reorder(rotulo, n_artigos), y = n_artigos)) +
    geom_col(fill = "#1B4F72") +
    geom_text(aes(label = n_artigos), hjust = -0.3, size = 4.5) +
    coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(x = NULL, y = "Nº de artigos") +
    tema_grafico
  print(grafico_multilabel)
  salvar_grafico(grafico_multilabel, "03_freq_dimensao_teorica_multilabel.png")
}

# -----------------------------------------------------------------------------
# 3. Tendencia temporal
# -----------------------------------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("3. TENDENCIA TEMPORAL\n")
cat(strrep("-", 78), "\n\n")

cat("-- Metodo por ano (contagem) --\n")
metodo_ano <- base %>%
  filter(!is.na(metodo)) %>%
  count(year, metodo) %>%
  pivot_wider(names_from = metodo, values_from = n, values_fill = 0) %>%
  arrange(year)
imprimir_tudo(metodo_ano)

# O grafico usa `count(year, metodo)` no formato LONGO (uma linha por
# combinacao ano/metodo) -- e' o formato que o ggplot2 espera. A tabela
# impressa acima (metodo_ano), no formato LARGO (uma coluna por metodo), e'
# melhor para leitura em tabela, mas nao e' o formato que o ggplot usa.
#
# Grafico de LINHA (uma linha por metodo) em vez de barras empilhadas: e'
# uma serie temporal, e barras empilhadas dificultam ver a tendencia de
# cada metodo isoladamente. scale_color_brewer(palette = "Blues") da' uma
# cor diferente para cada metodo, todas dentro da mesma gama de azul.
grafico_metodo_ano <- base %>%
  filter(!is.na(metodo)) %>%
  count(year, metodo) %>%
  ggplot(aes(x = year, y = n, color = metodo)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = scales::breaks_width(2)) +
  scale_color_brewer(palette = "Blues") +
  labs(x = "Ano", y = "Nº de artigos", color = "Método") +
  tema_grafico +
  theme(legend.position = "bottom")
print(grafico_metodo_ano)
salvar_grafico(grafico_metodo_ano, "04_metodo_por_ano.png", largura = 9)

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

  # Aqui um grafico de LINHAS (uma linha por dimensao teorica) faz mais
  # sentido do que barras empilhadas -- como e' multilabel, um mesmo artigo
  # conta para mais de uma linha ao mesmo tempo, e barras empilhadas dariam
  # a impressao errada de que as categorias sao mutuamente exclusivas.
  grafico_teoria_ano <- base %>%
    filter(!is.na(.data[[variavel_multilabel]]), .data[[variavel_multilabel]] != "") %>%
    mutate(rotulo = str_split(.data[[variavel_multilabel]], "\\s*\\|\\s*")) %>%
    tidyr::unnest(rotulo) %>%
    mutate(rotulo = str_squish(rotulo)) %>%
    count(year, rotulo) %>%
    ggplot(aes(x = year, y = n, color = rotulo)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = scales::breaks_width(2)) +
    scale_color_brewer(palette = "Blues") +
    labs(x = "Ano", y = "Nº de artigos", color = "Dimensão teórica") +
    tema_grafico +
    theme(legend.position = "bottom")
  print(grafico_teoria_ano)
  salvar_grafico(grafico_teoria_ano, "04_dimensao_teorica_por_ano.png", largura = 9)
}

cat("\n", strrep("=", 78), "\n", sep = "")
cat("FIM -- GRAFICOS PARA O PAPER\n")
cat("Graficos salvos em: output/figuras/\n")
cat(strrep("=", 78), "\n")
