library(data.table)

response_labelling_tool <- function(folder_path, export_path, rcp_id, not_applicable_column, unknown, response_window, duration_segment){
  
  # Get full paths to all files within the folder (recursively)
  files_list <- list.files(
    path      = folder_path,
    recursive = TRUE,
    full.names = TRUE
  )
  
  # Create export folder if it doesn't exist
  if (!dir.exists(export_path)) {
    dir.create(export_path, recursive = TRUE)
    message("Export folder not found. Creating new folder: ", export_path)
  }
  
  # Calculate how many rows ahead correspond to the response window
  segments_window <- as.integer(ceiling(response_window / duration_segment))
  
  
  # Process each file in the input folder
  for (file_path in files_list) {
    file_name <- tools::file_path_sans_ext(basename(file_path))
    print(file_name)
    
    # Read column names from first line
    first_line_columns <- strsplit(readLines(n = 1, file_path), "\t")[[1]]
    
    # Identify RCP columns (recipients)
    rcp_list <- first_line_columns[grepl(rcp_id, first_line_columns)]
    
    # Columns needed for overlap checking
    overlap_list <- c(rcp_list, "id_part", "Duration - msec")
    
    # List of potential speakers (excluding RCPs and control columns)
    if (!is.null(not_applicable_column)){
      recipient_list <- first_line_columns[!(first_line_columns %in% rcp_list) & !(first_line_columns %in% c("Duration - msec", "Begin Time - msec", "End Time - msec", "default", not_applicable_column))]
    }
    else {
      recipient_list <- first_line_columns[!(first_line_columns %in% rcp_list) & !(first_line_columns %in% c("Duration - msec", "Begin Time - msec", "End Time - msec", "default"))]
    }
    # Load the full dataset
    dt <- fread(file_path, sep = "\t")
    
    # Assign a unique ID to each row (segment)
    dt[, id_part := .I]
    
    # Remove unnecessary columns
    dt[, (intersect(c("Begin Time - msec", "End Time - msec", "default"), names(dt))) := NULL]
    
    # Convert duration to integer
    dt[, `Duration - msec` := as.integer(`Duration - msec`)]
    
    # Convert recipient indicators to integer (1/0)
    for (column in recipient_list) {
      tryCatch({
        dt[, (column) := as.integer(get(column))]
      }, error = function(e) {
        message(paste("Column not found or error in:", column, "->", e$message))
      })
    }
    
    # Remove rows marked as not applicable
    if (!is.null(not_applicable_column)){
      dt <- dt[is.na(get(not_applicable_column))]
      dt[, (not_applicable_column) := NULL]
    }
    
    # Identify segments to ignore due to unknown labels in RCP columns
    ignore_list <- data.table(id_part = integer(), `Duration - msec` = integer())
    for (rcp in rcp_list) {
      ignore_list <- rbind(ignore_list, dt[tolower(get(rcp)) == tolower(unknown), .(id_part, `Duration - msec`)])
    }
    
    # Replace remaining NA values with 0L (especially in recipient and RCP columns)
    dt[is.na(dt)] <- 0L
    
    dt_results_list <- list()
    
    # Loop through each speaker candidate
    for (id_code in recipient_list){
      
      # Get list of rows where speaker is active
      dt_analisis <- dt[get(id_code) == 1L, id_part]
      emission_durations <- dt[get(id_code) == 1L, .(id_part, `Duration - msec`)]
      
      # Split into continuous emission blocks (consecutive rows)
      emission_list <- if (length(dt_analisis) == 0L) {
        list()
      } else {
        split(dt_analisis, cumsum(c(TRUE, diff(dt_analisis) != 1)))
      }
      
      # Remove emission blocks that contain ignored segments
      emission_list <- Filter(
        function(subemission) {
          # Extend the block with the next consecutive values
          extended_block <- seq(from = min(subemission), to = max(subemission) + segments_window)
          
          # Reject the block if any value from the extended range is in ignore_list$id_part
          !any(extended_block %in% ignore_list$id_part)
        },
        emission_list
      )
      
      if (length(emission_list) == 0L) {
        next
      }
      
      emission_number <- 0L
      
      # Analyze each emission
      for (emission in emission_list) {
        if (length(emission) == 0L) next
        
        emission_number <- emission_number + 1L
        emission_id <- paste(emission_number, id_code, sep = "_")
        
        # Total duration of the emission
        total_duration <- sum(emission_durations[id_part %in% emission, `Duration - msec`])
        
        # Extract RCP responses and durations in the response window
        dt_rcp <- dt[id_part >= min(emission) & id_part <= (max(emission) + segments_window), ..rcp_list]
        dt_rcp_emi_dur <- dt[id_part >= min(emission) & id_part <= (max(emission) + segments_window), "Duration - msec"]
        
        duration_window <- sum(dt_rcp_emi_dur[[1]], na.rm = TRUE)
        
        # If duration is still too short, extend the window by one segment
        if (duration_window < response_window) {
          dt_rcp <- dt[id_part >= min(emission) & id_part <= (max(emission) + segments_window + 1L), ..rcp_list]
        }
        
        # Extract original emission segments for overlap checking
        dt_overlap <- dt[id_part >= min(emission) & id_part <= max(emission), ..overlap_list]
        
        # Determine response type based on who replied
        if (any(unlist(dt_rcp) == id_code, na.rm = TRUE)) {
          response_type <- "R"     # direct response
        } else if (any(unlist(dt_rcp) == "GROUP", na.rm = TRUE)) {
          response_type <- "RG"    # group response
        } else if (any(unlist(dt_rcp) %in% setdiff(recipient_list, id_code), na.rm = TRUE)) {
          response_type <- "ROC"   # response from other candidate
        } else {
          response_type <- "NR"    # no response
        }
        
        # Calculate amount of overlap during the emission
        overlap_amount <- 0L
        for (i in emission) {
          # If any RCP column in that row is not empty, count as overlap
          if (any(dt_overlap[id_part == i, ..rcp_list] != "")) {
            overlap_amount <- overlap_amount + sum(dt_overlap[id_part == i, `Duration - msec`])
          }
        }
        
        # Proportion of the emission that is overlapped
        overlap_prop <- if (total_duration > 0L) {
          round(overlap_amount / total_duration, 4)
        } else {
          0
        }
        
        # Save result for this emission
        dt_resultados_aux <- data.table(
          emission = emission_id,
          duration = total_duration,
          response = response_type,
          overlap = overlap_prop
        )
        
        dt_results_list[[length(dt_results_list) + 1L]] <- dt_resultados_aux
      }
    }
    
    # Combine all emission results into one table
    dt_results <- rbindlist(dt_results_list)
    
    # Export results to file
    export <- paste0(export_path, "/", file_name, "_results.txt")
    fwrite(dt_results, export, sep = "\t", na = "NA", col.names = TRUE)
    
    dt_results_list <- NULL
  }
}