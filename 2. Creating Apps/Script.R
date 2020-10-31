# Cargamos las librerías
install.packages("devtools")
devtools::install_github("rOpenSpain/caRtociudad")

{
  library(caRtociudad)
  library(leaflet)
  library(sf)
  library(geojsonio)
  library(googleway)
}


ciudad = "Getxo" #Input

map_data = cartociudad_geocode(ciudad)

plot_poligon = st_as_sfc(map_data$geom)

leaflet(plot_poligon) %>%
  addMapPane("background_map", zIndex = 410) %>%
  addMapPane("polygons", zIndex = 420) %>%
  addProviderTiles(providers$Stamen.TonerLite) %>%
  addPolygons(fillColor = "blue", 
              stroke=TRUE, 
              fillOpacity = 0.5) 
