# Run scoring in Shiny -- server
#
# written by Martin Monkman
# last update: 2015-01-04
#
#
# ####################
#
# package load 
library(shiny)
library(dplyr)
library(reshape)
library(ggplot2)
#
library(Lahman)
#

# CREATE LEAGUE SUMMARY TABLES
# ============================
#
# load the Lahman data table "Teams", filter
data(Teams)

# select a sub-set of teams from 1901 [the establishment of the American League] forward to most recent year
LG_RPG <- Teams %>%
  filter(yearID > 1900, lgID != "FL") %>%
  group_by(yearID, lgID) %>%
  summarise(R=sum(R), RA=sum(RA), G=sum(G)) %>%
  mutate(leagueRPG=R/G, leagueRAPG=RA/G)
# and a version with just the MLB totals
MLB_RPG <- Teams %>%
  filter(yearID > 1900, lgID != "FL") %>%
  group_by(yearID) %>%
  summarise(R=sum(R), RA=sum(RA), G=sum(G)) %>%
  mutate(leagueRPG=R/G, leagueRAPG=RA/G)
#
# define the year limits of the data set
firstyear <- MLB_RPG$yearID[1]
mostrecentyear <- tail(MLB_RPG$yearID, 1)
#
# create data frame Teams.merge with league averages
Teams.merge <-  Teams %>%
  mutate(teamRPG=(R/G), teamRAPG=(RA/G)) 
Teams.merge <- 
  merge(Teams.merge, LG_RPG, by = c("yearID", "lgID"))
#
# create new values to compare the individual team's runs/game compares to the league average that season
Teams.merge <- Teams.merge %>%
  # runs scored index where 100=the league average for that season
  mutate(R_index = (teamRPG/leagueRPG)*100) %>%
  mutate(R_index.sd = sd(R_index)) %>%
  mutate(R_z = (R_index - 100)/R_index.sd) %>%
  # runs allowed
  mutate(RA_index = (teamRAPG/leagueRAPG)*100) %>%
  mutate(RA_index.sd = sd(RA_index)) %>%
  mutate(RA_z = (RA_index - 100)/RA_index.sd)
#
#
# create a list of the team names
TeamNames <- Teams %>%
  filter(yearID > 1900, lgID != "FL") %>%
  distinct(franchID) %>%
  select(franchID) %>%
  arrange(franchID) 
TeamNameList <- TeamNames$franchID
#


# ####################################################
# 
# Define server logic
shinyServer(function(input, output) {
  
  
# LEAGUE PAGE
# -----------
  
  # UI reactive elements for league ui page
  # trendline select (TRUE / FALSE)
  output$trendlineselectvalue <- renderPrint({ input$trendlineselect })
  
  # trendline sensitivity (slider)
  output$trendline_sen <- renderPrint({ input$trendline_sen_sel })
  
  # trendline confidence interval (slider)
  output$trendline_conf <- renderPrint({ input$trendline_conf_sel })
  
  # define yearrange for UI 
  output$lg_yearrange <- renderUI({
    sliderInput("lg_yearrange_input", label = h4("Select year range to plot"), 
                min = firstyear, max = mostrecentyear, value = c(firstyear, mostrecentyear), 
                step = 1, round = TRUE, format = "####",
                animate = TRUE)
  })
  #
  #
#
# +++++ plot: runs scored per game by league

output$plot_MLBtrend <- renderPlot({
    # plot the data
    MLBRPG <- ggplot(MLB_RPG, aes(x=yearID, y=leagueRPG)) +
             geom_point() +
             xlim(input$lg_yearrange_input[1], input$lg_yearrange_input[2]) +
             ylim(3, 6) +
             ggtitle(paste("Major League Baseball: runs per team per game", 
                           input$lg_yearrange_input[1], "-", input$lg_yearrange_input[2])) +
             xlab("year") + ylab("runs per game")  

    # plot each league separately?
    if (input$leaguesplitselect == TRUE) {
      MLBRPG <- ggplot(LG_RPG, aes(x=yearID, y=leagueRPG)) +
        geom_point() +
        xlim(input$lg_yearrange_input[1], input$lg_yearrange_input[2]) +
        ylim(3, 6) +
        ggtitle(paste("Major League Baseball: runs per team per game", 
                      input$lg_yearrange_input[1], "-", input$lg_yearrange_input[2])) +
        xlab("year") + ylab("runs per game") +
        facet_grid(lgID ~ .)
    }
    # add trend line to plot?
      if (input$trendlineselect == TRUE) {
          MLBRPG <- MLBRPG + 
            stat_smooth(method=loess, 
                        span=input$trendline_sen_sel,
                        level=as.numeric(input$trendline_conf_sel))
         }
    # final plot
    MLBRPG

  })
  # ----------- end MLBtrend plot
#
# MLB table output
# (if leagues are plotted separately, then show the data split by league)

output$MLBtable <- renderDataTable({
  
  if (input$leaguesplitselect == TRUE) {
    RPG_data <- as.data.frame(LG_RPG)
  } else {
    RPG_data <- as.data.frame(MLB_RPG)
    }
})

#
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# TEAM PAGE
#
# UI reactive elements for team ui page
#
# list of team names for drop down box
output$TeamNameListUI <- renderUI ({
  selectInput("TeamName", label=h4("Choose team to plot:"),
              choices=as.character(TeamNameList),
              selected=TeamNameList[1])
})

# trendline select (TRUE / FALSE)
output$team_trendlineselectvalue <- renderPrint({ input$team_trendlineselect })

# trendline sensitivity (slider)
output$team_trendline_sen <- renderPrint({ input$team_trendline_sen_sel })

# trendline confidence interval (slider)
output$team_trendline_conf <- renderPrint({ input$team_trendline_conf_sel })

# filter by team using franchID variable in the Teams.merge data frame
# note the use of double "=" i.e. ==
  
#output$team_yearrange <- renderUI({
#  sliderInput("team_yearrange_input", label = h4("Select year range to plot"), 
#              min = firstteamyear, max = lastteamyear, value = c(firstteamyear, lastteamyear), 
#              step = 1, round = TRUE, format = "####",
#              animate = TRUE)
#})
#


# +++++ PLOTS: TEAM RUNS SCORED / ALLOWED PER GAME

output$plot_teamTrend <- renderPlot({
  #
  Team1 <- filter(Teams.merge, franchID == input$TeamName)
  #
  # then pull first and last years of the analysis and team name fields
  firstteamyear <- Team1$yearID[1]
  lastteamyear <- tail(Team1$yearID, 1)
  #
  Team2 <- Team1 %>%
    select(yearID, teamID, R_index, RA_index) %>%
    melt(id=c("yearID", "teamID"))
  #
  output$team_yearrange <- renderUI({
    sliderInput("team_yearrange_input", label = h4("Select year range to plot"), 
                min = firstteamyear, max = lastteamyear, value = c(firstteamyear, lastteamyear), 
                step = 1, round = TRUE, format = "####",
                animate = TRUE)
  })
  # pull the team name
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ## NOTE: THIS IS THE ULTIMATE CODE BUT DUE TO AN ERROR IN THE SOURCE LAHMAN DATABASE
  ##       (THAT GOT TRANSFERED INTO THE LAHMAN PACKAGE)
  ##       THE ALTERNATE CODE TO DEFINE THE TEAM NAME IS USED TEMPORARILY
  ##       AND SHOULD BE CORRECT WITH LAHMAN 4.0
  #team.name <- tail(Team1$name, 1)
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  team.name <- tail(Team1$name, 2)
  # now put the team name, years, and the rest of the title text into a single string
  titletext <- paste(team.name, firstteamyear, "-", lastteamyear, 
                      "\nRuns scored relative to the league average")
  #
  # plot the data
  teamTrend <- ggplot(Team2, aes(x=yearID, y=value, colour=variable)) +
    geom_point() +
#    xlim(input$team_yearrange_input[1], input$team_yearrange_input[2]) +
#    ylim(50, 150) +
    ggtitle(titletext) +
    xlab("year") + ylab("Index (league average = 100)")  +
    annotate("segment", x=firstteamyear, xend=lastteamyear, y=100, yend=100, colour="black", size=1)
  
  
# add trend line to plot?
if (input$team_trendlineselect == TRUE) {
  teamTrend <- teamTrend + 
    stat_smooth(method=loess,
                size=1.5,
                span=input$team_trendline_sen_sel,
                se=FALSE)
}

# final plot
  teamTrend
  
})
# ----------- end team trend plot

output$Team1_data_table <- renderDataTable({
  #
  #
  Team1 <- filter(Teams.merge, franchID == input$TeamName)

  # the raw data table
#  Team1_data_table <- as.data.frame(Team1)
  #
  # the data table, with only the interesting fields (columns)
  #
  Team1_data_table <- Team1 %>%
    select(yearID, lgID, franchID, name, W, L, R.x, RA.x, teamRPG, leagueRPG, R_index, 
           teamRAPG, leagueRAPG, RA_index)

})


# -- TEAM DATA TABLE

output$team_data_table <- renderDataTable({
#
  # the raw data table
  #   team_data_table <- as.data.frame(Teams.merge)
  #
  # the data table, with only the interesting fields (columns)
  team_data_table <- Teams.merge %>%
    select(yearID, lgID, franchID, name, W, L, R.x, RA.x, teamRPG, leagueRPG, R_index, 
           teamRAPG, leagueRAPG, RA_index)
     })

# ----------- end team data table 
#
})
# ----------- end shinyServer function 