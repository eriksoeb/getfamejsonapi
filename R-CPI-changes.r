
# Load required libraries
library(jsonlite)
library(dplyr)
library(ggplot2)
library(scales)
library(lubridate)


famebase <- "$REFERTID/data/kpi_publ.db"
famedato <- "freq m; date 2005 to *"
series_list <- c("pct(convert(total.ipr,ann,con,end))", 
                 "pct(convert(total.ipr,ann,linear,ave))",
                 "ytypct(total.ipr)", 
                 "mave(pct(K01.IPR),3" )

# Initialize an empty data frame to store all data
df_all <- data.frame()

# Process each series
for (famesoek in series_list) {
    # Construct the command for the current series
    command <- paste("ssh sl-fame-1.ssb.no '",              
                     "$REFERTID/system/myfame/api/getfame -e \"", famebase, 
                     "\" \"", famesoek, "\" \"", famedato, "\"'", sep="")
    
    # Execute the command and capture the output
    output <- system(command, intern = TRUE, ignore.stderr = FALSE)
    
    
    # Get the HOME environment variable
    home_dir <- Sys.getenv("HOME")

    # Construct the full path using the home directory
    json_file_path <- file.path(home_dir, ".GetFAME/getfameexpr.json")
    
   
    # Read the JSON file
    json_data <- fromJSON(json_file_path)
     
    # Check if any series was returned
    if (length(json_data$Series) == 0) {
        cat("No series found for:", famesoek, "\n")
        next
    }
    
    # Get the specific series data
    series <- json_data$Series[[1]]
    series_name <- series$Name  # Get the series name
 

    # Check if Observations are present
    if (is.null(series$Observations) || length(series$Observations) == 0) {
        cat("No observations found for series:", series_name, "\n")
        next
    }

    # Convert observations to a data frame
    df <- as.data.frame(series$Observations)

    # Ensure required columns exist
    if (!("Date" %in% colnames(df) && "Value" %in% colnames(df))) {
        cat("Expected columns 'Date' and 'Value' not found for series:", series_name, "\n")
        next
    }

    # Remove any columns with NA or empty string names
    df <- df %>% select(where(~ !any(is.na(.)) & !all(. == "")))

    # Convert the Date column to datetime, ensuring valid conversion
    df$Date <- as_datetime(df$Date)

    # Add the series name to the data frame
    df <- df %>% mutate(Series = series_name)

    # Combine the data from this series with the overall data frame
    df_all <- bind_rows(df_all, df)
}

# Ensure the final data frame handles NA values correctly
if (nrow(df_all) > 0) {
    # Plot the data using ggplot2
    options(repr.plot.width = 16, repr.plot.height = 6)  # Adjust the width and height as needed


    ggplot(df_all, aes(x = Date, y = Value, color = Series)) +
  geom_line() +
  scale_x_datetime(labels = date_format("%b%y"), date_breaks = "1 year") +
  labs(title = paste("Chart: ", "CPI % Changes"),
       x = "month/year", y = "% Changes of CPI") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  guides(color = guide_legend(title = "")) +
  scale_y_continuous(labels = scales::comma)
      
} else {
    cat("\nNo data to plot.\n")
}

