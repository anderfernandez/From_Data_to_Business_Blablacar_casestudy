# Fijamos el entorno de trabajo -------------------------------------------
rm(list = ls())
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
getwd()
dir()


# Cargamos las librerías --------------------------------------------------
install.packages("devtools")
devtools::install_github("rOpenSpain/caRtociudad")

packages = c("caRtociudad","leaflet","sf","geojsonio","googleway",
             "foreach","doParallel","iterators","dplyr","rgdal")
new <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new)) install.packages(new)
suppressMessages(sapply(packages, require, character.only=TRUE))

# Limpiamos las variables para mantener el entorno limpio
rm(new, packages)

# Cargamos los datos ------------------------------------------------------
bla_gf_agreg = read.csv("bla_gf_agreg.csv", stringsAsFactors = FALSE)



# Extraemos la posición de las ciudades ------------------------------------
# Para extraer la información usaremos la función cartociudad_geocode
# Esta función devuelve la información geográfica de una cadena de texto. 
# PROS: podemos situar las ciudades en el mapa con una gran exactitud.  
# CONTRA: 
#   - Puede que falle en alguna que otra ciudad... y habrá que revisarlo a mano.
#   - Hay muchas ciudades, por lo que extraer toda la información va a llevar tiempo. Mucho tiempo...
#   - Está limitado a España, por lo que nos perdemos los datos que no son de España.

donostia = cartociudad_geocode("Donostia")

# Observamos qué nos devuelve esta función
colnames(donostia)
summary(donostia)

# Parece que todo lo que devuelve es caracter, menos la latitud y longitud, que son numéricos. 
# ¿Qué significa la variable geom? ¿Alguna idea?

donostia$geom


# Si queremos enriquecer el dataset con los datos geográficos, ¿qué deberíamos hacer?

# Extrayendo todos los datos ----------------------------------------------

# 1 - Sacar el listado de todos los municipios diferentes que hay
# OJO: un municipio puede estar como ORIGEN o DESTINO, pero no a la inversa.


pueblos = c(bla_gf_agreg$ORIGEN, bla_gf_agreg$DESTINO)

# Eliminamos los pueblos duplicados
paste("Hay un total de:", length(pueblos),"pueblos")
paste("Hay un total de:", length(unique(pueblos)),"pueblos diferentes")

pueblos = unique(pueblos)

pueblos_matrix = matrix(
  nrow = length(pueblos),
  ncol = ncol(donostia)
  )

pueblos_resultado = data.frame(pueblos_matrix)
colnames(pueblos_matrix) = colnames(donostia)


# Para cada pueblo, extraemos los datos
for(i in 1:length(pueblos)){
  
  pueblo = pueblos[i]
  pueblos_resultado[i,] = cartociudad_geocode(pueblo)
  print(i)
  
}

rm(i,x)

# El código rompe... ¿por qué?
# Comprobamos
cartociudad_geocode(pueblo)

pueblo
# Parece que Cartociudad no coge A Baña... 

##############################################################
# ¿Cómo podemos correr el código sin tener que estar encima? #
##############################################################

# Usaremos la función try, de tal manera que podamos pasar de aquellas ciudades que nos dan error.

# Vemos cómo funciona
rm(x)
x = cartociudad_geocode(pueblo)
class(x)

x = try(cartociudad_geocode(pueblo))
class(x)

rm(x)
# Si aplicas try en un bucle, no te parará el bucle en caso de error. En su lugar, el objeto se quedará con un class try-error. 
# Cada vez que hacemos una petición podemos comprobar que su clase no sea try-error y, si no lo es, ir adjuntando los datos.

pueblos_resultado = data.frame(pueblos_matrix)
colnames(pueblos_matrix) = colnames(donostia)


i = 1
for(i in 1:10){
  
  pueblo = pueblos[i]
  
  x = try(cartociudad_geocode(pueblo, type = "Municipio"))
  
  # Si es la primera vuelta, creamos el dataset
  if(class(x) == "try-error"){
    print(paste("Error extrayendo:", pueblo) )
  } else{
      pueblos_resultado[i,] = x  
    }
  # Si queremos ver la evolución, hacemos un print de i
  print(i)
}

# Comprobamos el resultado
View(pueblos_resultado) 

# Si te fijas hay pueblos que no están bien metidos porque no tienen las mismas columnas.
# Incluimos la condición de que las columnas deben ser las mismas

# Por tanto, habría que hacer un bucle y que no obtenga estos datos


cols_result = colnames(pueblos_resultado)
i = 1
for(i in 1:10){
  
  pueblo = pueblos[i]
  
  x = try(cartociudad_geocode(pueblo, type = "Municipio"))
  cols_x = colnames(x)
  
  # Si es la primera vuelta, creamos el dataset
  if(class(x) == "try-error"){
    print(paste("Error extrayendo:", pueblo) )
  } else{
    # Comprobamos que tengan los mismos nombres de columna
    if(identical(cols_x, cols_result)){
      pueblos_resultado[i,] = x
    } else{
      print(paste("Tipo de localización incorrecta:", pueblo) )
    }
  }
  # Si queremos ver la evolución, hacemos un print de i
  print(i)
}

View(pueblos_resultado)

# Con esto, ya habremos agilizado la extracción de los datos.
# En nuestro caso, el no hacer esto supuso 3 días de trabajo contínuo de extracción de datos.
# Como no vamos a descargar todos los datos,  simplemente cargaremos el resultado

pueblos_resultados = readRDS("dataset_ciudades.RData")

head(pueblos_resultados)

# Obteniendo las rutas ----------------------------------------------------

# Ahora que tenemos la latitud y longitud de todos los puntos, podemos obtener también la ruta entre esos dos puntos. 
# Para ello, usaremos la función cartociudad_get_route, que dadas una latitud y longitud nos devuelve una ruta.


# Veamos el ejemplo de la ruta entre los dos primeros pueblos
latlon_origen = c(pueblos_resultados$Latitud[1], pueblos_resultados$Longitud[1])
latlon_destino = c(pueblos_resultados$Latitud[2], pueblos_resultados$Longitud[2])

ruta = cartociudad_get_route(latlon_origen, latlon_destino)

glimpse(ruta)

# bbox: viene de bounding box y se refiere a un cuadrado que incluye todo el recorrido.
# distance: se refiere a la distancia en metros.
# found: si ha encontrado o no la ruta
# geom: información geográfica de la ruta.

#########################################################
# Duda: la información geográfica, ¿no es un poco rara? #
#########################################################

# La información geográfica puede guardarse en muchos formatos diferentes. 
# Uno de esos formatos, y el que usa el propio Google Maps, es guardar la info comprimida.
# En ese caso, todos estos caracteres se refieren, en realidad, a una ruta entre dos puntos.
# Para verlo y pintarlo, primero hay que descomprimir la ruta.

ruta_decoded = decode_pl(ruta$geom)
ruta_decoded


# Dibujando mapas ---------------------------------------------------------

# Para pintar los mapas usaremos el paquete Leaflet. 
# Este paquete funciona a capas, comom ggplot. 
# 1. Mapa de una zona. 

# Convertimos la geometría en multipolygon
poligono_donostia = st_as_sfc(donostia$geom)


# Plots simple
plot(poligono_donostia)

# Plot simple interactivo
leaflet(poligono_donostia) %>%
  addPolygons()

 
# Sin embargo, queda un poco feo. 
# Lo que podemos hacer es añadir varias capas de info para que quede más bonito
leaflet(poligono_donostia) %>%
  
  # 3 capas: base, poligonos y labels
  addMapPane("background_map", zIndex = 410) %>%  # Nivel 1: abajo
  addMapPane("polygons", zIndex = 420) %>%        # Nivel 2: medio
  addMapPane("labels", zIndex = 430) %>%          # Nivel 3: top
  
  # Capa 1: nombres
  addProviderTiles(providers$Stamen.TonerLabels,
                   options = pathOptions(pane = "labels")  ) %>% 
  # Capa 2: polígonos
  addProviderTiles(providers$Stamen.TonerLite) %>%
  
  # Capa 3: polígonos
  addPolygons(fillColor = "blue", 
              stroke=TRUE, 
              fillOpacity = 0.5) 


# 2. Por otro lado, vamos a pintar una ruta
# Como lo mejor es guardarlos en formato texto, usaremos una ruta en formato texto.
# Sacamos una ruta larga, como por ejemplo Donostia - Cádiz.

origen = "Bilbao"
destino = "Lepe"

area_origen = cartociudad_geocode(origen)
area_destino = cartociudad_geocode(destino)

latlon_origen = c(area_origen$lat, area_origen$lng)
latlon_destino = c(area_destino$lat, area_destino$lng)

ruta = cartociudad_get_route(latlon_origen, latlon_destino)

ruta_decoded = decode_pl(ruta$geom)

leaflet() %>%
  addPolylines(data = ruta_decoded, lat = ~lat, lng = ~lon, col = "blue")


# Como véis, sigue quedando simple, pero siempre le podemos añadir más capas

leaflet() %>%
  # 3 capas: base, poligonos y labels
  addMapPane("background_map", zIndex = 410) %>%  # Nivel 1: abajo
  addMapPane("polylines", zIndex = 420) %>%       # Nivel 2: medio
  addMapPane("labels", zIndex = 430) %>%          # Nivel 3: top
  
  # Capa 1: nombres
  addProviderTiles(providers$Stamen.TonerLabels,
                   options = pathOptions(pane = "labels")) %>% 
  # Capa 2: polígonos
  addProviderTiles(providers$Stamen.TonerLite) %>%
  
  # Capa 3: ruta
  addPolylines(data = ruta_decoded, lat = ~lat, lng = ~lon, col = "blue")
  



