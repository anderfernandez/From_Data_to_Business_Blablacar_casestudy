library(shiny)
library("devtools")
devtools::install_github("rOpenSpain/caRtociudad")

{
    library(caRtociudad)
    library(leaflet)
    library(sf)
    library(geojsonio)
    library(googleway)
    library(shiny)
}


# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Visualiza tu localidad"),

    # Sidebar with text input and action 
    sidebarLayout(
        sidebarPanel(
            textInput("localidad",
                        "Elige tu localidad:"
                        ),
            actionButton("boton",label = "Analizar")
        ),

        # Show a plot of the generated distribution
        mainPanel(
           leafletOutput("mapa")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {

    datos_mapa = eventReactive(input$boton ,{
        
        ciudad = input$localidad
        
        map_data = cartociudad_geocode(ciudad)
        
        plot_poligon = poligono_donostia = st_as_sfc(map_data$geom)
        
    })
    
    output$mapa = renderLeaflet({
        datos_mapa = datos_mapa()
        
        leaflet(datos_mapa) %>%
            addMapPane("background_map", zIndex = 410) %>%
            addMapPane("polygons", zIndex = 420) %>%
            addProviderTiles(providers$Stamen.TonerLite) %>%
            addPolygons(fillColor = "blue", 
                        stroke=TRUE, 
                        fillOpacity = 0.5) 
        
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
