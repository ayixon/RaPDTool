#!/usr/bin/env Rscript

# Copyright (C) 2017, Weizhi Song, Torsten Thomas.
# songwz03@gmail.com or t.thomas@unsw.edu.au

# Binning_refiner is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Binning_refiner is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# check.packages function: install and load multiple R packages.
# Check to see if packages are installed. Install them if they are not, then load them into the R session.
check.packages <- function(pkg){
    new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new.pkg))
        install.packages(new.pkg, dependencies = TRUE)
    sapply(pkg, require, character.only = 1)
}


# install packages if not
packages<-c("tools", "optparse", "googleVis")
invisible(suppressMessages(check.packages(packages)))


option_list = list(
  
  make_option(c("-f", "--file"), 
              type="character", 
              default=NULL, 
              help="input file name", 
              metavar="character"),
  
  make_option(c("-x", "--width"), 
              type="double", 
              default=600, 
              help="the width of plot [default= %default]", 
              metavar="double"),
  
  make_option(c("-y", "--height"), 
              type="double", 
              default=1000, 
              help="the height of plot [default= %default]", 
              metavar="double")); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);


if (is.null(opt$file)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)}


my_data = read.csv(opt$file, header = TRUE)
Sankey_plot_my_data <- gvisSankey(my_data, options = list(sankey = "{node:{colorMode:'unique', labelPadding: 20, nodePadding: 8},link:{colorMode:'source'}}",
                                                       height = opt$height, 
                                                       width = opt$width))

output_file = paste(file_path_sans_ext(opt$file), "html", sep=".")
sink(file = output_file, append = FALSE, type = c("output", "message"), split = FALSE)
print(Sankey_plot_my_data)
sink()

