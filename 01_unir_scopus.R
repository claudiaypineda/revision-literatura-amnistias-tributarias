# ============================================================
# 01_unir_scopus.R
# Script portable (funciona en cualquier computador)
# ============================================================


# ============================================================
# PASO 0. Cargar librerías
# ============================================================

# install.packages("readr")
# install.packages("dplyr")
# install.packages("openxlsx")
# install.packages("stringr")
# install.packages("rstudioapi")

library(readr)
library(dplyr)
library(openxlsx)
library(stringr)
library(rstudioapi)


# ============================================================
# PASO 0.1. Fijar directorio automáticamente (CLAVE)
# ============================================================

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

cat("Directorio de trabajo:\n")
print(getwd())


# ============================================================
# PASO 0.2. Crear carpeta resultados si no existe
# ============================================================

if (!dir.exists("resultados")) {
  dir.create("resultados")
}


# ============================================================
# PASO 1. Leer archivos CSV
# ============================================================

archivos <- list.files(
  path = "datos_crudos",
  pattern = "\\.csv$",
  full.names = TRUE
)

print(archivos)

# Validación
if (length(archivos) == 0) {
  stop("No se encontraron archivos CSV en datos_crudos")
}


# ============================================================
# PASO 2. Revisar columnas
# ============================================================

columnas_por_archivo <- lapply(archivos, function(archivo) {
  nombres <- names(read_csv(archivo, n_max = 0, show_col_types = FALSE))
  data.frame(
    archivo = basename(archivo),
    columna = nombres
  )
})

columnas_por_archivo <- bind_rows(columnas_por_archivo)

write.xlsx(
  columnas_por_archivo,
  "resultados/Revision_Columnas.xlsx",
  overwrite = TRUE
)


# ============================================================
# PASO 3. Comparar columnas
# ============================================================

lista_columnas <- lapply(archivos, function(archivo) {
  names(read_csv(archivo, n_max = 0, show_col_types = FALSE))
})

names(lista_columnas) <- basename(archivos)

col_ref <- lista_columnas[[1]]

comparacion <- lapply(names(lista_columnas), function(nombre) {
  
  col_actual <- lista_columnas[[nombre]]
  
  data.frame(
    archivo = nombre,
    faltantes = paste(setdiff(col_ref, col_actual), collapse = "; "),
    adicionales = paste(setdiff(col_actual, col_ref), collapse = "; "),
    mismo_orden = identical(col_ref, col_actual)
  )
})

comparacion <- bind_rows(comparacion)

write.xlsx(
  comparacion,
  "resultados/Comparacion_Columnas.xlsx",
  overwrite = TRUE
)

print(comparacion)


# ============================================================
# PASO 4. Detener si hay problemas
# ============================================================

if (any(comparacion$faltantes != "" |
        comparacion$adicionales != "" |
        comparacion$mismo_orden == FALSE)) {
  
  stop("Columnas inconsistentes. Revisar resultados/Comparacion_Columnas.xlsx")
}


# ============================================================
# PASO 5. Leer datos completos
# ============================================================

bases <- lapply(archivos, function(archivo) {
  
  base <- read_csv(
    archivo,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
  
  base <- base %>%
    mutate(
      archivo_origen = str_remove(basename(archivo), "\\.csv$")
    )
  
  return(base)
})


# ============================================================
# PASO 6. Unir bases
# ============================================================

base_total <- bind_rows(bases)

cat("Registros antes:", nrow(base_total), "\n")


# ============================================================
# PASO 7. Eliminar duplicados
# ============================================================

base_final <- base_total %>%
  distinct(DOI, .keep_all = TRUE) %>%
  distinct(EID, .keep_all = TRUE)

cat("Registros después:", nrow(base_final), "\n")


# ============================================================
# PASO 8. Guardar base completa
# ============================================================

write_csv(
  base_final,
  "resultados/Base_Final_Bibliometrix.csv"
)


# ============================================================
# PASO 9. Crear base de lectura
# ============================================================

base_lectura <- base_final %>%
  select(
    archivo_origen,
    Title,
    Abstract,
    `Author Keywords`,
    `Index Keywords`,
    Year,
    DOI,
    `Source title`,
    `Cited by`,
    Link
  )


# ============================================================
# PASO 10. Guardar Excel
# ============================================================

write.xlsx(
  base_lectura,
  "resultados/Base_Lectura.xlsx",
  overwrite = TRUE
)


# ============================================================
# FIN
# ============================================================

cat("Proceso terminado correctamente.\n")