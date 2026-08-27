# This script analysis the production on Bureaucracy in Brasil and LATAM
# This is part of the Chapter on XXXXXXX
# Last time run top to bottom: 21st jul 2026


# Loading packages ----
library(dplyr)
library(easyScieloPack)
library(purrr)
library(tidyr)
library(readr)

# Selecting keywords for search -----
terms <- c(
  
  # Bureaucracy
  "burocracia",
  "burocrático",
  "burocrática",
  "burocrata",
  "burocratas",
  "bureaucracy",
  "bureaucratic",
  
  # Civil service and public servants
  "servidor público",
  "servidores públicos",
  "servidor municipal",
  "funcionalismo público",
  "serviço público",
  "civil service",
  "public servant",
  "public servants",
  "public service",
  
  # Street-level bureaucracy
  "burocrata de nível de rua",
  "burocracia de nível de rua",
  "nível de rua",
  "street-level bureaucracy",
  "street-level bureaucrat",
  
  # Administrative elites
  "alto escalão",
  "médio escalão",
  "alta burocracia",
  "middle management",
  "senior civil servants",
  
  # State capacity
  "capacidade estatal",
  "capacidade administrativa",
  "capacidade burocrática",
  "capacidade institucional",
  "capacidade governamental",
  "state capacity",
  "administrative capacity",
  "bureaucratic capacity",
  "institutional capacity",
  "government capacity",
  
  # Local government
  "governo local",
  "governo municipal",
  "administração municipal",
  "gestão municipal",
  "prefeitura",
  "prefeituras",
  "município",
  "municípios",
  "municipal",
  "local government",
  "municipality",
  "municipal government",
  "city government",
  
  # Public administration
  "administração pública",
  "gestão pública",
  "public administration",
  "public management",
  
  # Policy implementation
  "implementação",
  "implementação de políticas",
  "policy implementation",
  "implementation",
  
  # Organizations
  "órgão público",
  "agência pública",
  "secretaria municipal",
  "public agency",
  "government agency",
  
  # Human resources
  "carreira pública",
  "carreira estatal",
  "recrutamento",
  "seleção",
  "concursos públicos",
  "public employment",
  "civil service reform",
  
  #teories
  "weber",
  "weberian",
  "meritocracia",
  "merit system",
  "profissionalização",
  "professionalization",
  "insulamento burocrático",
  "bureaucratic insulation",
  "autonomia burocrática",
  "bureaucratic autonomy",
  "politização",
  "politicização",
  "politicization"
)

# Downloading information using `EasyScieloPack` -----
  # Note: we took the most important political science and public administration journals indexed in Scielo
RAP <- purrr::map_dfr(terms, ~
                         search_scielo(.x, journals = "Revista de Administração Pública")) %>%
          mutate(journal = 'Revista de Administração Pública')


RBCP <- purrr::map_dfr(terms, ~
                          search_scielo(.x, journals = "Revista Brasileira de Ciência Política")) %>% 
    mutate(journal = 'Revista Brasileira de Ciência Política')


OP <- purrr::map_dfr(terms, ~
                         search_scielo(.x, journals = "Opinião Pública")) %>% 
            mutate(journal = 'Opinião Pública')

RSP <- purrr::map_dfr(terms, ~
                       search_scielo(.x, journals = "Revista de Sociologia e Política")) %>% 
  mutate(journal = 'Revista de Sociologia e Política')

BPSR <- purrr::map_dfr(terms, ~
                        search_scielo(.x, journals = "Brazilian Political Science Review")) %>% 
                         mutate(journal = 'Brazilian Political Science Review')

LN <- purrr::map_dfr(terms, ~ search_scielo(.x, journals = "Lua Nova: Revista de Cultura e Política")) %>% 
  mutate(journal = 'Brazilian Political Science Review')

CRH <- purrr::map_dfr(terms, ~
                       search_scielo(.x, journals = "Caderno CRH")) %>% 
  mutate(journal = 'Caderno CRH')

CEBAPE <- purrr::map_dfr(terms, ~
                        search_scielo(.x, journals = "Cadernos EBAPE.BR")) %>% 
  mutate(journal = 'Cadernos EBAPE.BR')

CGPC <- purrr::map_dfr(terms, ~
                        search_scielo(.x, journals = "Cadernos Gestão Pública e Cidadania")) %>% 
  mutate(journal = 'Cadernos Gestão Pública e Cidadania')


DADOS <- purrr::map_dfr(terms, ~
                         search_scielo(.x, journals = "Dados"))%>% 
  mutate(journal = 'Dados')


RBCS <- purrr::map_dfr(terms, ~
                           search_scielo(.x, journals = "Revista Brasileira de Ciências Sociais")) %>% 
  mutate(journal = 'Revista Brasileira de Ciências Sociais')


# Binding datasets ----
all_papers <- bind_rows(RAP,RBCP,RBCS, OP, BPSR, LN, CRH, CEBAPE, CGPC,
  DADOS,RSP)


# Saving daset -----
write_rds(all_papers, "Data/rawData/scielo_papers.RDS")
write.csv(all_papers, "Data/rawData/scielo_papers.csv")

####### end of script ######




