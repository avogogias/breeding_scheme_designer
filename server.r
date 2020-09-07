server <- function(input, output, clientData, session) {
  
  # TV to use complementary to generated divID for identifying Scenarios ID
  Scenarios <<- c() #simple list of scenario ids, so will be [1,2,3] if three scenarios
  
  # Default matrix values
  stage = c(1,2,3)
  entries = c(1000,100,10)
  years = c(1,1,2)
  locs = c(1,4,8)
  reps = c(1,2,3)
  error = c(1,1,1)
  h2 = c(0.5,0.5,0.5) # this is a calculated value
  
  # per-session reactive values object to store all results of this user session
  rv <- reactiveValues(results_all = NULL)
  
  # defines a common reactive list to store all scenario input info (stages DT + other) to replace reactDT
  scenariosInput <- reactiveValues(stagesDT = list(), varG = list(), varGxL = list(), varGxY = list(), varieties = list()) # initially will store stages_current and updated accordingly
  
  # updateH2 <- function(){
  #   for (i in stage)
  #   {
  #     print(paste("The index is",i))
  #     h2[i] = input$varG #/ ( input$varG + input$varGxY/years[i] + input$varGxL/years[i]*locs[i] + error[i]/years[i]*locs[i]*reps[i])
  #   }
  #   print(h2)
  # }
  
  yt = cbind(stage,entries,years,locs,reps,error,h2)
  # Using reactiveVales to add a server side set of variable observable and mutable at the same time
  yti <- reactiveValues(data = yt)
  
  # Update H2 for every stage as soon as input data that affect H2 change
  observe({
    for (i in 1:nrow(yti$data))
    {
      yti$data[i,7] = round(input$varG/(input$varG + input$varGxY/yti$data[i,3] + input$varGxL/(yti$data[i,3]*yti$data[i,4]) + yti$data[i,6]/(yti$data[i,3]*yti$data[i,4]*yti$data[i,5])), 3)
      # print(paste("H2 for stage", i, "is", yti$data[i,7]))
    }
  })
  
  # Render static table with total years, locs and plots
  # output$tYears = renderText({ sum(yti$data[,3]) })  # years
  # output$tLocs = renderText({ sum(yti$data[,4]) })  # locs
  # output$tPlots = renderText({ yti$data[1,2] })  # plots
  # cost_df = cbind(tYears, tLocs, tPlots)
  
  # function calculates Total Plots given a stages matrix as input
  totalPlots <- function(mtx = yt) {
    # print(nrow(mtx))
    # print(prod(mtx[1,1:4]))
    tp = 0
    for (i in 1:nrow(mtx))
      tp = tp + prod(mtx[i,1:4])
    print(tp)
  }
  # Display a DT table with costs calculated based on user input (stages etc.)
  output$cost_table = DT::renderDT(cbind(sum(yti$data[,3])+input$negen,sum(yti$data[,3]*yti$data[,4]), totalPlots(yti$data)), 
                                   options = list(
                                     searching = F, # no search box
                                     paginate = F,  # no num of pages
                                     lengthChange = F, # no show entries
                                     scrollX = T # horizontal slider
                                   ),
                                   rownames = F,
                                   colnames = c('Total Years', 'Total Locs', 'Total Plots'),
                                   server = F )
  
  # Render stages DT with default data entries
  output$stages_table = DT::renderDT(yti$data, 
                                     options = list(
                                       searching = F, # no search box
                                       paginate = F,  # no num of pages
                                       lengthChange = F, # no show entries
                                       scrollX = T # horizontal slider
                                     ),
                                     class = "cell-border, compact, hover", 
                                     rownames = F, #TRUE,
                                     colnames = c('Stage', 'Entries', 'Years', 'Locs', 'Reps', 'Plot Error', toString(withMathJax('$$h_2$$'))), # '$$h_2$$'),  # 'h2'),
                                     filter = "none",
                                     escape = FALSE,
                                     autoHideNavigation = TRUE,
                                     selection = "none",
                                     editable = list(target = "cell", disable = list(columns = c(0, 6))),
                                     server = TRUE) # server = F doesn't work with replaceData() cell editing
  
  # Update editable DT through a proxy DT on cell edit event
  proxy = dataTableProxy('stages_table')
  #
  observeEvent(input$stages_table_cell_edit, {
    info = input$stages_table_cell_edit
    i = info$row
    j = info$col + 1 # +1 required when rownames = F in DT
    v = info$value
    str(info)
    # Character string needs to be coerced to same type as target value. Here as.integer()
    yti$data[i, j] = DT::coerceValue(v, yti$data[i, j])
    # Produces invalid JSON response when renderDT (server = F), because replaceData() calls reloadData()
    replaceData(proxy, yti$data, resetPaging = FALSE)  # important 
  })
  
  ### Reset table
  #TV  observeEvent(reset(), {
  #TV  yti$data <- yt # your default data
  #TV})
  
  
  
  # Observe Button Clicks for adding or removing rows (stages) from the DT
  observeEvent(input$add_btn, {
    print(yti$data[1,3:6])
    # calc h2 for this stage
    new_h2 = input$varG / (input$varG + input$varGxY + input$varGxL + 1)
    yti$data = rbind(yti$data, c(length(yti$data[,1])+1,2,1,1,1,1,round(new_h2, 3)))
  })
  
  observeEvent(input$delete_btn, {
    if (length(yti$data[,1])>2) # TV for >1 it crushes!
      yti$data = yti$data[1:length(yti$data[,1])-1,]
  })
  
  
  
  #***********************************************
  #-----------------------------------------------  
  # ************* RUN BUTTON OBSERVER ************
  # *************---------------------************
  #***********************************************
  #-----------------------------------------------
  # Execute runScenario() for the current settings
  observeEvent(input$run_btn, {
    
    print(length(Scenarios))
    # Increment Scenarios counter list e.g. [1, 2, 3] for 3 scenarios, used in place of input$run_btn
    if (length(Scenarios) == 0){
      Scenarios <<- c(1)                # if no Scenario defines so far, make the first one "1"
    }
    else{
      Scenarios <<- c(Scenarios,  tail(Scenarios,1)+1)   # if a Scenario is added, just add a number to the last number in the "Scenarios" vector
    }
    
    # Handle auto/user-defined IDs for scenarios
    # divID <- if (input$divID == "") gsub("\\.", "", format(Sys.time(), "%H%M%OS3")) 
    # else input$divID
    divID <- gsub("\\.", "", format(Sys.time(), "%H%M%OS3")) # always auto-generated ID for each scenario
    dtID <- paste0(divID, "DT")
    rm_btnID <- paste0(divID, "rmv")
    up_btnID <- paste0(divID, "upd")
    boxID <- paste0(divID, "box")
    stagesID <- paste0(divID, "stg")
    # scenarioID <- paste0(divID, "scn") # Alternative to Scenarios ID vector
    
    
    varG = isolate(input$varG)
    varGxL = isolate(input$varGxL)
    varGxY = isolate(input$varGxY)
    
    stages = isolate(yti$data[,1]) # 
    entries = isolate(yti$data[,2]) # c(1000,100,10) 
    years = isolate(yti$data[,3]) # c(1,1,1)
    locs = isolate(yti$data[,4]) # c(1,4,8)
    reps = isolate(yti$data[,5]) # c(1,2,3)
    error = isolate(yti$data[,6]) # c(1,1,1)
    h2 = isolate(yti$data[,7])
    varieties = isolate(input$varieties)
    
    # store settings for summary plot TODO
    stages_current = data.frame(stages, entries, years, locs, reps, error, h2)
    
    # Create a new tab in the UI every time Run is pressed
    # UI input elements of all Scenario tabs are rendered
    output$mytabs = renderUI({
      myTabs = lapply(1: tail(Scenarios,1), function(i){
        tabPanel(paste0('Scenario', i),
                 plotOutput(paste0('cyPlot', i)),
                 # input settings used for this scenario
                 DT::DTOutput(paste0('stages_summary', i)),
                 # update scenario button
                 actionButton(paste0("update_btn", i), "Update")
        )
      }) 
      do.call(tabsetPanel, myTabs)
    })
    
    print(paste("Start Run", tail(Scenarios,1))) # input$run_btn))
    
    result = runScenario(varG,varGxL,varGxY,entries,years,locs,reps,error,varieties)
    
    # New Plot of ran result appearing in new tab
    # First save new plot in a variable before passing it to output
    nplot <- renderPlot({
      boxplot(t(result),
              xlab="Stage",
              ylab="Mean Genetic Value")
    })   # end of renderPlot
    
    # Store results from all runs in a reactive matrix
    for(i in 1:nrow(result)) 
    {
      rv$results_all = cbind(rv$results_all, rbind(Stage = i, Value = result[i,], Scenario = tail(Scenarios,1))) # Scenario = scenarioID)) FAILS
    }
    #print(head(t(rv$results_all)))
    #print(tail(t(rv$results_all)))
    
    # Global settings for all DTs in senario tabs
    sumset_DT = list( options = list(
      searching = F, # no search box
      paginate = F,  # no num of pages
      lengthChange = F, # no show entries
      scrollX = T # horizontal slider
    ),
    class = "cell-border, compact, hover", 
    rownames = F, #TRUE,
    # colnames = c('Stage', 'Entries', 'Years', 'Locs', 'Reps', 'Plot Error', toString(withMathJax('$$h_2$$'))), # inserted manually
    filter = "none",
    escape = FALSE,
    autoHideNavigation = TRUE,
    selection = "none",
    editable = list(target = "cell", disable = list(columns = c(0, 6))),
    server = TRUE) # server = F doesn't work with replaceData() cell editing
    
    # Include content from R file locally as if it was pasted here to manage if-else
    # source('if_run_btn.r', local=TRUE) # OLD METHOD with if-else loop handling but with duplicated code for up to 5 scenarios WORKS!
    source('update_scenarios.r', local = TRUE) # alternative recursive method IN PROGRESS
    
    
    # # Attempt to enrich v object with I/O data for every scenario - NOT USED
    # v$data = list(v$data, list("id" = tail(Scenarios,1), 
    #                            "in" = list("varG" = varG,
    #                                        "varGxY" = varGxY,
    #                                        "varGxL" = varGxL,
    #                                        "stages_current" = stages_current,
    #                                        "varieties" = varieties), 
    #                            "out" = result)
    #               )
    
    
    ## Try to load input data using a for loop instead of if-else
    # for (i in 1:tail(Scenarios,1))
    # TODO
    
    output$overviewTab <- renderPlot({
      ggplot(as.data.frame(t(rv$results_all)),aes(x=factor(Stage),y=Value,fill=factor(Scenario)))+
        geom_boxplot()+
        xlab("Stage")+
        ylab("Gain")+
        scale_fill_discrete(name="Scenario")+
        ggtitle("Comparison between stages across all scenarios")
    })   # end of renderPlot for Overview tab
    
    source('all_in_one.r', local = TRUE) # alternative recursive method that uses divID -- IN PROGRESS    
    
  }) # end of run button
  
  # TV hide ALL tab 
  # shiny::hideTab(inputId = "my_tabs", target = "ALL")
  
} # endof server