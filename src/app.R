# DC Energy Benchmarking Dashboard
# Shiny application for interactive analysis of DC building energy performance data

# ==== PACKAGES ====
library(shiny)
library(ggplot2)
library(dplyr)
library(tidyverse)
library(broom)
library(bslib)
library(thematic)
library(DT)

# Configure thematic for auto-themed plots
thematic::thematic_shiny(font = "auto")
theme_set(theme_minimal(base_size = 14))

# ==== DATA LOADING & TRANSFORMATION ====
energy_df <- read_rds("data/dc_energy_benchmark_2025.rds")

# Transform columns to factors and create derived variables
energy_df <- energy_df %>%
  mutate(
    Ward = as.factor(Ward),
    Report_Year = as.factor(Report_Year),
    Type_SS = as.factor(Type_SS),
    Type_EPA = as.factor(Type_EPA),
    Metered_Energy = as.factor(Metered_Energy),
    Metered_Water = as.factor(Metered_Water),
    Era = case_when(
      Built < 1900 ~ "Pre-1900",
      Built < 1951 ~ "Early-Mid 20th",
      Built < 2000 ~ "Late 20th",
      Built >= 2000 ~ "Modern (2000+)",
      TRUE ~ NA_character_
    ),
    Era = factor(Era, levels = c("Pre-1900", "Early-Mid 20th", "Late 20th", "Modern (2000+)"))
  ) %>%
  relocate(Era, .after = Built)

# ==== HELPER FUNCTIONS ====

# One-sample t-test with broom::tidy output
ttest_mu <- function(data_vector, mu = 0) {
  t_result <- t.test(data_vector, mu = mu)
  tidy_result <- broom::tidy(t_result)

  tibble(
    Null_value = mu,
    Estimate = tidy_result$estimate,
    Conf_Low = tidy_result$conf.low,
    Conf_High = tidy_result$conf.high,
    P_Value = tidy_result$p.value
  )
}

# ==== UI ====
ui <- fluidPage(
  theme = bs_theme(bootswatch = "flatly"),
  h2("DC Energy Benchmarking Dashboard", align = "center"),
  br(),

  navbarPage(
    title = NULL,

    # ---- INTRODUCTION TAB ----
    tabPanel(
      "Introduction",
      div(
        style = "max-width: 900px; margin: 0 auto; padding: 20px;",
        h3("Building Energy Performance in Washington, DC"),
        p(
          "This dashboard enables exploratory analysis of building energy performance data ",
          "from Washington, DC's Building Energy Performance Standards (BEPS) program. ",
          "The BEPS program requires large buildings to disclose annual energy and water consumption data."
        ),

        h4("Dataset Overview"),
        p(
          "The data come from the DC Department of Energy & Environment (DOEE) and are published ",
          "through DC's Open Data portal. The dataset includes buildings of various types, sizes, and construction eras, ",
          "with measurements of energy consumption, water usage, and performance metrics such as Energy Star scores."
        ),

        h4("Key Variables"),
        tags$ul(
          tags$li(strong("Energy Star Score: "), "1-100 rating of building efficiency relative to similar properties"),
          tags$li(strong("Site Energy Intensity (SQFT_Site): "), "Annual energy use per square foot"),
          tags$li(strong("GHG Emissions Intensity (GHG_Intensity): "), "Greenhouse gas emissions per square foot"),
          tags$li(strong("Water Use Intensity (Water_Intensity): "), "Annual water consumption per square foot"),
          tags$li(strong("Built: "), "Year of construction (used to define building era)"),
          tags$li(strong("Ward: "), "DC Ward designation (1-8)")
        ),

        h4("Navigation"),
        tags$ul(
          tags$li(strong("Univariate: "), "Explore distributions of single variables with histograms and boxplots"),
          tags$li(strong("Bivariate: "), "Examine relationships between two variables with scatter and box plots"),
          tags$li(strong("Data Table: "), "Browse and filter the full dataset")
        ),

        h4("Data Source"),
        p(
          "DC Energy Benchmarking Open Data | ",
          tags$a(
            "DCGIS Building Energy Benchmarking Dataset",
            href = "https://opendata.dc.gov/datasets/DCGIS::building-energy-benchmarking/about",
            target = "_blank"
          ),
          " | Downloaded October 2025"
        ),
        p(
          "Program Information: ",
          tags$a(
            "DOEE Building Energy Performance Standards",
            href = "https://doee.dc.gov/service/building-energy-performance-standards",
            target = "_blank"
          )
        ),

        br(),
        div(
          style = "text-align: center;",
          img(src = "dc_energy_logo.webp", width = "200px", alt = "DC Energy Logo")
        )
      )
    ),

    # ---- UNIVARIATE TAB ----
    tabPanel(
      "Univariate",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          h4(strong("Variable Selection")),
          selectInput(
            "var_single",
            label = "Variable:",
            choices = names(energy_df),
            selected = "Energy_Star_Score"
          ),

          h4(strong("Display Options")),
          checkboxInput("log_single", "Log Transform?", FALSE),
          checkboxInput("flip_single", "Flip Coordinates on Factors?", FALSE),
          sliderInput(
            "bins_single",
            label = "Number of Bins:",
            min = 5,
            max = 100,
            value = 40
          ),

          h4(strong("Statistical Test")),
          numericInput("mu_value", "Null Value (t-test):", value = 0, min = -1000, max = 1000),

          h4(strong("Filter")),
          checkboxGroupInput(
            "report_years_single",
            "Report Years:",
            choices = sort(unique(energy_df$Report_Year)),
            selected = as.character(max(as.numeric(as.character(energy_df$Report_Year))))
          )
        ),

        mainPanel(
          width = 9,
          h3("Distribution Analysis"),
          plotOutput("plot_single", height = "450px"),
          br(),
          h4("T-Test Results (One Sample)"),
          dataTableOutput("table_ttest"),
          br()
        )
      )
    ),

    # ---- BIVARIATE TAB ----
    tabPanel(
      "Bivariate",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          h4(strong("Variables")),
          selectInput(
            "var_x",
            label = "X Variable:",
            choices = names(energy_df),
            selected = "SQFT_Tax"
          ),
          checkboxInput("log_x", "Log Transform X?", FALSE),

          selectInput(
            "var_y",
            label = "Y Variable:",
            choices = names(energy_df),
            selected = "SQFT_Gross"
          ),
          checkboxInput("log_y", "Log Transform Y?", FALSE),

          h4(strong("Fit Options")),
          checkboxInput("show_lm", "Fit Linear Model?", TRUE),
          checkboxInput("show_smooth", "Fit Smoother?", FALSE),

          h4(strong("Filter")),
          checkboxGroupInput(
            "report_years_bivariate",
            "Report Years:",
            choices = sort(unique(energy_df$Report_Year)),
            selected = as.character(max(as.numeric(as.character(energy_df$Report_Year))))
          )
        ),

        mainPanel(
          width = 9,
          h3("Relationship Analysis"),
          plotOutput("plot_bivariate", height = "500px"),
          br(),
          h4("Linear Model Summary"),
          verbatimTextOutput("lm_summary"),
          br()
        )
      )
    ),

    # ---- DATA TABLE TAB ----
    tabPanel(
      "Data Table",
      checkboxInput("numeric_only", "Numeric Columns Only?", FALSE),
      br(),
      dataTableOutput("table_full_data")
    )
  )
)

# ==== SERVER ====
server <- function(input, output, session) {

  # ---- UNIVARIATE: Single Variable Plot ----
  output$plot_single <- renderPlot({
    req(input$var_single, input$report_years_single)

    df <- energy_df %>%
      filter(
        Report_Year %in% input$report_years_single,
        !is.na(.data[[input$var_single]]),
        .data[[input$var_single]] != 0
      )

    is_numeric <- is.numeric(df[[input$var_single]])

    base_plot <- ggplot(df, aes(x = .data[[input$var_single]])) +
      facet_wrap(~Report_Year, scales = "free") +
      labs(
        title = paste("Distribution of", input$var_single),
        x = input$var_single,
        y = ifelse(is_numeric, "Count", "Frequency")
      ) +
      theme_minimal(base_size = 14) +
      theme(
        plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
        axis.title = element_text(size = 14, face = "bold"),
        strip.background = element_rect(fill = "#2C3E50", color = NA),
        strip.text = element_text(color = "white", face = "bold")
      )

    if (is_numeric) {
      if (input$log_single) {
        base_plot <- base_plot +
          geom_histogram(bins = input$bins_single, fill = "steelblue", color = "white", alpha = 0.8) +
          scale_x_log10()
      } else {
        base_plot <- base_plot +
          geom_histogram(bins = input$bins_single, fill = "steelblue", color = "white", alpha = 0.8)
      }
    } else {
      base_plot <- base_plot +
        geom_bar(fill = "darkorange", alpha = 0.8)
      if (input$flip_single) {
        base_plot <- base_plot + coord_flip()
      }
    }

    base_plot
  })

  # ---- UNIVARIATE: T-Test Results Table ----
  output$table_ttest <- renderDataTable({
    req(input$var_single, input$report_years_single)

    df <- energy_df %>%
      filter(
        Report_Year %in% input$report_years_single,
        !is.na(.data[[input$var_single]]),
        .data[[input$var_single]] != 0
      )

    var_data <- df[[input$var_single]]
    if (!is.numeric(var_data)) return(NULL)

    if (input$log_single) var_data <- log1p(var_data)

    ttest_result <- ttest_mu(var_data, mu = input$mu_value) %>%
      mutate(across(where(is.numeric), round, 3))

    datatable(
      ttest_result,
      options = list(dom = "t", paging = FALSE, ordering = FALSE),
      rownames = FALSE
    )
  })

  # ---- BIVARIATE: Scatter/Box Plot ----
  output$plot_bivariate <- renderPlot({
    req(input$var_x, input$var_y, input$report_years_bivariate)

    df <- energy_df %>%
      filter(
        Report_Year %in% input$report_years_bivariate,
        !is.na(.data[[input$var_x]]),
        !is.na(.data[[input$var_y]]),
        .data[[input$var_x]] != 0,
        .data[[input$var_y]] != 0
      )

    x_num <- is.numeric(df[[input$var_x]])
    y_num <- is.numeric(df[[input$var_y]])

    if (input$log_x && x_num) df[[input$var_x]] <- log1p(df[[input$var_x]])
    if (input$log_y && y_num) df[[input$var_y]] <- log1p(df[[input$var_y]])

    base_plot <- ggplot(df, aes(x = .data[[input$var_x]], y = .data[[input$var_y]])) +
      facet_wrap(~Report_Year, scales = "free") +
      labs(
        title = paste("Relationship:", input$var_y, "vs", input$var_x),
        x = input$var_x,
        y = input$var_y
      ) +
      theme_minimal(base_size = 14) +
      theme(
        plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
        axis.title = element_text(size = 14, face = "bold"),
        strip.background = element_rect(fill = "#2C3E50", color = NA),
        strip.text = element_text(color = "white", face = "bold")
      )

    if (x_num && y_num) {
      base_plot <- base_plot +
        geom_point(aes(color = Report_Year), alpha = 0.6) +
        scale_color_brewer(palette = "Set1")
      if (input$show_lm) {
        base_plot <- base_plot + geom_smooth(method = "lm", se = FALSE, color = "black", linewidth = 0.8)
      }
      if (input$show_smooth) {
        base_plot <- base_plot + geom_smooth(method = "loess", se = FALSE, color = "red", linewidth = 0.8, formula = y ~ x)
      }
    } else if (!x_num && y_num) {
      base_plot <- base_plot + geom_boxplot(aes(fill = Report_Year), alpha = 0.6)
    } else if (x_num && !y_num) {
      base_plot <- base_plot + geom_boxplot(aes(fill = Report_Year), alpha = 0.6)
    } else {
      base_plot <- base_plot + geom_jitter(aes(color = Report_Year), width = 0.2, height = 0.2, alpha = 0.6)
    }

    base_plot
  })

  # ---- BIVARIATE: Linear Model Summary ----
  output$lm_summary <- renderPrint({
    req(input$var_x, input$var_y, input$report_years_bivariate)

    if (!input$show_lm) {
      cat("Linear model fitting is disabled. Check 'Fit Linear Model?' to view results.\n")
      return(NULL)
    }

    df <- energy_df %>%
      filter(
        Report_Year %in% input$report_years_bivariate,
        !is.na(.data[[input$var_x]]),
        !is.na(.data[[input$var_y]]),
        .data[[input$var_x]] != 0,
        .data[[input$var_y]] != 0
      )

    x_num <- is.numeric(df[[input$var_x]])
    y_num <- is.numeric(df[[input$var_y]])

    if (!(x_num && y_num)) {
      cat("Linear model requires both variables to be numeric.\n")
      return(NULL)
    }

    if (input$log_x) df[[input$var_x]] <- log1p(df[[input$var_x]])
    if (input$log_y) df[[input$var_y]] <- log1p(df[[input$var_y]])

    model <- lm(as.formula(paste(input$var_y, "~", input$var_x)), data = df)
    summary(model)
  })

  # ---- DATA TABLE: Full Dataset ----
  output$table_full_data <- renderDT({
    df <- if (input$numeric_only) {
      energy_df %>% select(where(is.numeric))
    } else {
      energy_df
    }

    datatable(
      df,
      options = list(pageLength = 20, scrollX = TRUE),
      filter = "top"
    )
  })
}

# ==== RUN APP ====
shinyApp(ui = ui, server = server)
