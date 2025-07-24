# ELAN Response Labelling Tool

This R script provides a tool for processing TSV files exported from **ELAN** (EUDICO Linguistic Annotator). It is designed for researchers analyzing spoken interactions, particularly in environments where identifying the **response types** based on speech direction to speaker emissions is critical.

The tool extracts a list of **numbered speaker emissions** and analyzes:

* The **duration** (in milliseconds) of each emission.
* The **proportion of overlap** between speaker and recipient(s) (i.e., speaking simultaneously), **excluding overlaps with other speakers**.
* The **response type** given by the recipient(s) (as RCP), categorized as:

  * `R` – Direct response to the speaker.
  * `NR` – No response from RCP.
  * `RG` – Response to the group as a whole.
  * `ROC` – Response to another speaker, ignoring the first speaker.
  
---

## Features

* Handles multiple `.tsv` files recursively from a folder.
* Automatically excludes segments marked as "not applicable" or "unknown".
* Groups consecutive speaker segments into a single emission.
* Calculates overlap and response type within a defined time window.
* Exports clean results in a TSV format.
* Includes an example test file with expected output for validation.

---

## Requirements

* R
* `data.table` package

---

## Usage

```r
response_labelling_tool(
  folder_path = "path/to/input/folder",         # Folder containing .tsv ELAN files
  export_path = "path/to/output/folder",        # Folder to save results
  rcp_id = "RCP_",                              # Identifier for recipient columns
  not_applicable_column = "NotApplicable",      # Column marking segments to exclude
  unknown = "unknown",                          # Label indicating unknown response direction
  response_window = 3000,                       # Response window in milliseconds
  duration_segment = 100                        # Segmentation used on ELAN
)
```

---

## Parameters

| Parameter               | Description                                                                                                                                                                                                                                                                                                      |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `folder_path`           | Path to the folder containing ELAN `.tsv` files.                                                                                                                                                                                                                                                                 |
| `export_path`           | Path to export processed result files.                                                                                                                                                                                                                                                                           |
| `rcp_id`                | Prefix used to identify recipient (RCP) columns in the dataset. It must match the naming convention used in the ELAN file, such as `"RCP_"` if the columns are named `RCP_1`, `RCP_2`, etc. The prefix must be clearly distinguishable from speaker IDs and from other columns like the "not applicable" marker. |
| `not_applicable_column` | Name of the column used to exclude non-relevant segments.                                                                                                                                                                                                                                                        |
| `unknown`               | Value used to indicate unknown or invalid recipient labels.                                                                                                                                                                                                                                                      |
| `response_window`       | Duration in milliseconds to look for responses after each emission.                                                                                                                                                                                                                                              |
| `duration_segment`      | Duration in milliseconds used to segment ELAN tiers.                                                                                                                                                                                                                                                             |

---

## Criteria

- Perfectly contiguous annotations are considered a single emission.
- The response type is determined based on the speech direction indicated on the RCP line, considering what can be found within a time window that extends ***from the emission start to emission end plus the `response_window`***.
- Labels are assigned according to the following hierarchy:
  - If any `Speaker id` is found within the response window, the emission is labeled as `R`.
  - If no `R` is found, but a `GROUP` is present, the emission is labeled as `RG`.
  - If neither of the above applies, but the emission corresponds to a response from the RCP to a different `Speaker id`, it is labeled as `ROC`.
  - If none of the above criteria are met, the emission is labeled as `NR`.
- Any `unknown` annotation found within the response window will exclude the emission from the analysis, overriding any label that would otherwise apply.
- Any row with an annotation on the `not_applicable` line will be automatically excluded from the analysis.


---

## Input Format Requirements

The input TSV files must contain only the following columns:

* The original ELAN `"Duration - msec"` column.
* The columns for recipients (RCP), using a uniform and distinguishable naming convention (e.g., `RCP_1`, `RCP_2`, ...).
* The columns for speakers.

**Do not include** the segmentation tier used in ELAN for analysis purposes.

---

## Output

For each input file, a result file will be generated in the specified `export_path` with the following columns:

* `emission`: Unique emission identifier (e.g., `1_SPK1`)
* `duration`: Total duration of the emission in milliseconds
* `response`: Type of response (`R`, `NR`, `RG`, or `ROC`)
* `overlap`: Proportion of overlap between speaker and recipient(s)

---

## Example Output

```
emission     duration   response   overlap
1_SPK1      3200       R          0.0625
2_SPK1      1200       NR         0.0000
1_SPK2      2300       RG         0.1304
...
```

---

## Testing

The `tests` directory includes an example input file (`example.txt`) along with its corresponding expected output. This allows users to validate that the tool is functioning correctly on their system before applying it to new data.

---

## License

This project is licensed under the **GNU General Public License v3.0**.
You may redistribute and/or modify it under the terms of the license.
See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) for details.

